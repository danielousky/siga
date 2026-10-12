require "test_helper"

# Los ajustes de `/siga`: el WhatsApp de SIGA y los datos para pagarle (spec
# `docs/specs/del-registro-al-cobro.md`, decisiones 20 a 22).
#
#     /siga/ajustes  ──►  el fundador los cambia
#                    ──►  los colegios los ven en la petición siguiente
#
# Cambiar de número o de cuenta era entrar al servidor: el WhatsApp vivía en una
# variable de entorno, leída una vez al arrancar.
class AjustesDeSigaTest < ActionDispatch::IntegrationTest
  include CobroDeLaSuscripcion

  setup do
    @a, _b = dos_colegios_completos(suscripcion: :gratis)
    @fundador    = equipo_de_siga(:fundador)
    @operaciones = equipo_de_siga(:operaciones)
  end

  # ── Quién los cambia ──────────────────────────────────────────────────────

  test "el fundador los ve, con su enlace en el menú de la plataforma" do
    sign_in @fundador
    get siga_ajustes_path

    assert_response :success
    assert_select "nav a[href=?]", siga_ajustes_path, text: "Ajustes"
    assert_select "form[action=?] input[type=submit]", siga_ajustes_path
  end

  test "el fundador guarda el WhatsApp y los datos para pagar" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos }

    assert_redirected_to siga_ajustes_path
    ajustes = SigaSetting.actuales
    assert ajustes.persisted?
    assert_equal "0414-1234567", ajustes.whatsapp
    assert_equal "V-12345678", ajustes.documento
    assert_equal "01340000000000009999", ajustes.cuenta
    assert_equal %w[pago_movil binance efectivo], ajustes.medios
    assert_equal @fundador, ajustes.actualizado_por
  end

  # La tabla admite una sola fila: guardar dos veces cambia la misma.
  test "guardar otra vez cambia los mismos ajustes, no crea otros" do
    sign_in @fundador
    patch siga_ajustes_path, params: { siga_setting: datos }

    patch siga_ajustes_path, params: { siga_setting: datos.merge(whatsapp: "0416-7778899") }

    assert_equal 1, SigaSetting.count
    assert_equal "0416-7778899", SigaSetting.actuales.whatsapp
  end

  test "un dato mal escrito no se guarda, y dice cuál" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos.merge(cuenta: "0134-123") }

    assert_response :unprocessable_entity
    assert_match(/Número de cuenta son veinte dígitos/, response.body)
    assert_equal 0, SigaSetting.count
  end

  # ⚠️ Operaciones ve el formulario, apagado: saber a qué cuenta pagan los
  # colegios es parte de atenderlos; cambiarla, no (decisión 22).
  test "operaciones los ve y no los cambia" do
    cargar_los_ajustes_de_siga
    sign_in @operaciones

    get siga_ajustes_path
    assert_response :success
    assert_select "fieldset[disabled]", minimum: 4
    assert_select "input[type=submit]", 0
    assert_select "input[name='siga_setting[binance]'][value='987654321']"

    patch siga_ajustes_path, params: { siga_setting: datos }
    assert_match(/lo hace el fundador/, flash[:alert])
    assert_equal "987654321", SigaSetting.actuales.binance
  end

  # Son de la plataforma: un colegio no llega ni a verlos.
  test "un director no ve ni cambia los ajustes de SIGA" do
    sign_in @a.director

    get siga_ajustes_path
    assert_redirected_to root_path

    patch siga_ajustes_path, params: { siga_setting: datos }
    assert_redirected_to root_path
    assert_equal 0, SigaSetting.count
  end

  # ── Los colegios lo ven en el momento ─────────────────────────────────────

  # El criterio del spec: «la portada, el registro y "Suscripción" los usan en
  # el momento, sin reiniciar nada».
  test "lo que se guarda aparece en «Suscripción» en la petición siguiente" do
    sign_in @fundador
    patch siga_ajustes_path, params: { siga_setting: datos }
    sign_out @fundador

    sign_in @a.director
    get suscripcion_path

    assert_select ".suscripcion-medios", text: /Banesco \(0134\)/
    assert_select ".suscripcion-medios", text: /0426-5554433/
    assert_select "a[href^='https://wa.me/584141234567']"
  end

  test "y vaciar un dato apaga su medio" do
    cargar_los_ajustes_de_siga
    sign_in @fundador
    patch siga_ajustes_path, params: { siga_setting: { binance: "" } }
    sign_out @fundador

    sign_in @a.director
    get suscripcion_path

    assert_select ".suscripcion-medios", text: /Binance/, count: 0
    assert_select ".suscripcion-medio", 2
  end

  # ── El botón de WhatsApp sale de aquí ─────────────────────────────────────

  # ⚠️ El número es un ajuste, y ya no una variable leída al arrancar.
  test "el WhatsApp de las pantallas públicas es el de los ajustes" do
    cargar_los_ajustes_de_siga(whatsapp: "0416-1112233")

    get new_demo_request_path

    assert_select "a[href^='https://wa.me/584161112233']"
  end

  # Un botón que abre un chat con nadie es peor que no tener botón.
  test "sin número, el botón no aparece" do
    con_la_variable("SIGA_WHATSAPP", nil) do
      get new_demo_request_path

      assert_response :success
      assert_select "a[href*='wa.me']", 0
    end
  end

  # La variable sirve de valor inicial: el botón no desaparece el día del cambio.
  test "mientras nadie guarde los ajustes, vale la variable de entorno" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      get new_demo_request_path

      assert_select "a[href^='https://wa.me/584241234567']"
    end
  end

  private

  def datos
    { whatsapp: "04141234567", titular: "Empresa Nueva, C.A.", documento: "v-12.345.678",
      pago_movil_banco: "0134", pago_movil_telefono: "0426-5554433",
      cuenta: "0134-0000-00-0000009999", binance: "112233445" }
  end
end
