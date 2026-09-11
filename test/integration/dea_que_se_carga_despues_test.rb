require "test_helper"

# El código DEA salió de la puerta (`MOR-208`, segunda mitad).
#
#     ANTES                         AHORA
#     Nombre      [          ]      Nombre y apellido [          ]
#     Apellido    [          ]      Correo            [          ]
#     Correo      [          ]      Nombre del colegio[          ]
#     Colegio     [          ]      Qué dicta         (…)
#     Código DEA  [          ]
#                 ↑ hay que ir      ▸ el DEA se carga en «La identidad
#                   a buscarlo        del colegio», cuando lo tenga
#
# ## ⚠️ Por qué, y por qué no era suficiente lo que había
#
# El formulario ya sabía que el código era un problema: decía *«si no lo tiene a
# mano, escriba algo provisional y corríjalo después»*. Un DEA provisional es
# PEOR que ninguno — es un identificador nacional con un valor inventado
# adentro, que sale impreso en cada boletín y que nadie vuelve a corregir.
class DeaQueSeCargaDespuesTest < ActionDispatch::IntegrationTest
  # ── Registrarse ───────────────────────────────────────────────────────────

  test "el registro ya no pide el código DEA" do
    get registrarse_path

    assert_response :success
    assert_select "input[name='school[dea_code]']", count: 0
  end

  test "un colegio se registra sin código y queda en nil, no en blanco" do
    colegio = School.new(name: "U.E. SIN CÓDIGO", dea_code: "")

    assert colegio.valid?, colegio.errors.full_messages.to_sentence
    # ⚠️ `nil` y no `""`: el índice único es PARCIAL —`WHERE dea_code IS NOT
    # NULL`— así que dos colegios con la cadena vacía chocarían entre ellos.
    assert_nil colegio.tap(&:valid?).dea_code
  end

  test "dos colegios sin código pueden convivir" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. PRIMERA SIN CÓDIGO")

      assert_nothing_raised { School.create!(name: "U.E. SEGUNDA SIN CÓDIGO") }
    end
  end

  # ⚠️ Y el único sigue valiendo para los que SÍ lo tienen: es el código que
  # identifica al plantel ante el ministerio.
  test "dos colegios no pueden compartir el mismo código" do
    Current.sin_aislamiento do
      School.create!(name: "U.E. CON CÓDIGO", dea_code: "PD11112222")
      repetido = School.new(name: "U.E. OTRA", dea_code: "PD11112222")

      assert_not repetido.valid?
    end
  end

  # ── Cargarlo después ──────────────────────────────────────────────────────

  # ⚠️ El campo estaba deshabilitado SIEMPRE, y con el registro pidiéndolo eso
  # estaba bien: llegaba lleno. Ahora hay colegios que entran sin él, y con el
  # campo bloqueado el paso de arranque los mandaría a una pantalla que no los
  # deja hacer lo que les pide.
  test "sin código cargado, la ficha del colegio deja escribirlo" do
    a, = dos_colegios_completos
    con_el_colegio(a.colegio) { a.colegio.update_columns(dea_code: nil) }
    sign_in a.director

    get colegio_path

    assert_select "input[name='school[dea_code]']:not([disabled])"
  end

  test "una vez cargado, ya no se edita" do
    a, = dos_colegios_completos
    sign_in a.director

    get colegio_path

    assert_select "input[name='school[dea_code]'][disabled]"
  end

  # ⚠️ Y la guarda va en el SERVIDOR, no solo en el formulario: un `disabled` no
  # es un permiso, y ese código sale impreso en cada boletín y cada constancia.
  test "un POST no puede cambiar un código ya cargado" do
    a, = dos_colegios_completos
    anterior = con_el_colegio(a.colegio) { a.colegio.dea_code }
    sign_in a.director

    patch colegio_path, params: { school: { dea_code: "PD99999999" } }

    assert_equal anterior, con_el_colegio(a.colegio) { a.colegio.reload.dea_code }
  end

  test "pero sí cargarlo cuando está vacío" do
    a, = dos_colegios_completos
    con_el_colegio(a.colegio) { a.colegio.update_columns(dea_code: nil) }
    sign_in a.director

    patch colegio_path, params: { school: { dea_code: "pd-1234-5678" } }

    # Normalizado: sin separadores y en mayúscula.
    assert_equal "PD12345678", con_el_colegio(a.colegio) { a.colegio.reload.dea_code }
  end
end
