require "test_helper"

# El catálogo vivo del sistema de diseño, en `/siga/estilo`.
#
# ⚠️ Lo que se prueba acá NO es cómo se ve —eso se mira— sino dos cosas que sí
# se pueden afirmar: que la puerta está puesta, y que la página se dibuja con
# los HELPERS DE VERDAD.
#
# Lo segundo es lo que hace que el catálogo sirva. Un catálogo con HTML copiado
# es una octava forma de hacer las cosas, y la peor: dice ser la buena mientras
# se queda viejo en silencio. Si `boton` cambia y el catálogo no, este test lo
# destapa.
class CatalogoDeEstiloTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
    @del_equipo = Current.sin_aislamiento do
      persona = User.create!(first_name: "Equipo", last_name: "Siga",
                             email: "catalogo@siga.test", password: "123123",
                             document: "V-20202020", document_type: :cedula_v)
      SigaStaff.create!(user: persona, role: :fundador)
      persona
    end
  end

  # ── La puerta ─────────────────────────────────────────────────────────────

  # Decisión de Daniel: *«solo el equipo de SIGA»*. Colgando de
  # `Siga::BaseController` no hay autorización nueva que escribir.
  test "un director del colegio no entra" do
    sign_in @a.director

    get siga_estilo_path

    assert_redirected_to root_path
    assert_equal "No tienes acceso a esta sección.", flash[:alert]
  end

  test "un profesor tampoco" do
    sign_in @a.profesor

    get siga_estilo_path

    assert_redirected_to root_path
  end

  # ── El catálogo se dibuja solo ────────────────────────────────────────────

  test "muestra los seis tonos, dibujados por el helper de verdad" do
    sign_in @del_equipo

    get siga_estilo_path

    assert_response :success
    # ⚠️ El mensaje va en comentario y no como tercer argumento: con un hash
    # de `equality` sin llaves, Ruby no puede parsear lo que sigue. Está
    # anotado en `test_helper.rb`, y es la sexta vez que aparece.
    #
    # Si esto falla: al catálogo le falta un tono de los seis.
    Siga::EstiloController::TONOS.each do |t|
      assert_select "a.btn.btn-#{t[:tono]}", minimum: 1
    end
  end

  # ⚠️ El botón del catálogo tiene que traer su `%span` y su icono, porque eso
  # es lo que prueba que salió de `boton` y no de un `link_to` escrito a mano.
  test "los botones del catálogo traen icono y texto, como los de verdad" do
    sign_in @del_equipo

    get siga_estilo_path

    assert_select "a.btn.btn-guardar svg", minimum: 1
    assert_select "a.btn.btn-guardar span", minimum: 1
  end

  # El alta se muestra con su tooltip y su aria-label, que es la parte que más
  # se olvida al escribirla a mano.
  test "el ejemplo del alta trae tooltip y aria-label" do
    sign_in @del_equipo

    get siga_estilo_path

    assert_select "a.btn-agregar[data-tooltip=?][aria-label=?]",
                  "Registrar alumno", "Registrar alumno"
  end

  # ⚠️ Hasta la etapa ② esta sección era un INVENTARIO DE DEUDA —las siete
  # formas de título—. Ahora muestra los niveles de la única pieza que queda.
  test "muestra los niveles de título, no el inventario viejo" do
    sign_in @del_equipo

    get siga_estilo_path

    Siga::EstiloController::TITULOS.each do |t|
      assert_select "td strong", text: t[:nivel]
    end
    # Y ya no puede quedar rastro del inventario: si vuelve, es que volvió la
    # deuda.
    assert_select "code", text: "card-academic-header > h1", count: 0
  end
end
