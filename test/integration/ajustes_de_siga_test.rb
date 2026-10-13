require "test_helper"

# Los ajustes de `/siga`: el WhatsApp de SIGA, la dirección de la muestra y
# los datos para pagarle (spec `docs/specs/del-registro-al-cobro.md`,
# decisiones 20 a 22 y 35).
#
#     /siga/ajustes  ──►  el fundador los cambia
#                    ──►  los colegios los ven en la petición siguiente
#
#     setup          whatsapp · url_de_la_muestra · binance · paypal    una fila por dato
#     siga_settings  Pago Móvil y transferencia                         van juntos
#
# Cambiar de número, de cuenta o de dirección era entrar al servidor: el
# WhatsApp y la muestra vivían en variables de entorno, leídas al arrancar.
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
    assert_select "input[name='setup[whatsapp]']"
    assert_select "input[name='setup[url_de_la_muestra]']"
    assert_select "input[name='setup[binance]']"
    assert_select "input[type=email][name='setup[paypal]']"
  end

  test "el fundador guarda el WhatsApp, la dirección de la muestra y los datos para pagar" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos }

    assert_redirected_to siga_ajustes_path
    assert_equal "0414-1234567", Setup.whatsapp
    assert_equal "https://demo.sigaeducando.com", Setup.url_de_la_muestra
    assert_equal "112233445", Setup.binance
    assert_equal "pagos@empresa-nueva.test", Setup.paypal, "el correo, en minúscula"
    assert_equal @fundador, Setup.fila("whatsapp").actualizado_por

    ajustes = SigaSetting.actuales
    assert ajustes.persisted?
    assert_equal "V-12345678", ajustes.documento
    assert_equal "01340000000000009999", ajustes.cuenta
    assert_equal %w[pago_movil binance paypal efectivo], ajustes.medios
    assert_equal @fundador, ajustes.actualizado_por
  end

  # Una fila por dato, y una sola de pagos: guardar dos veces cambia las mismas.
  test "guardar otra vez cambia los mismos ajustes, no crea otros" do
    sign_in @fundador
    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos }

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos.merge(whatsapp: "0416-7778899") }

    assert_equal 1, SigaSetting.count
    assert_equal Setup::CAMPOS.size, Setup.count
    assert_equal "0416-7778899", Setup.whatsapp
  end

  test "un dato mal escrito no se guarda, y dice cuál" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos.merge(cuenta: "0134-123"), setup: datos_sueltos }

    assert_response :unprocessable_entity
    assert_match(/Número de cuenta son veinte dígitos/, response.body)
    assert_equal 0, SigaSetting.count
  end

  # ⚠️ O todo o nada, en las DOS direcciones. Son dos tablas en un formulario:
  # guardar una y rechazar la otra es una pantalla que dice «error» y que a
  # medias sí cambió.
  test "con la dirección mal escrita no se guardan tampoco los datos para pagar" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos.merge(url_de_la_muestra: "demo.sigaeducando.com") }

    assert_response :unprocessable_entity
    assert_match(/tiene que ser completa/, response.body)
    assert_select "input.campo-con-error[name='setup[url_de_la_muestra]'][value='demo.sigaeducando.com']"
    assert_equal 0, SigaSetting.count
    assert_equal 0, Setup.count, "ni el WhatsApp, que venía bien escrito"
  end

  # PayPal se cobra a un correo: sin el dominio completo, el dinero no llega.
  test "un PayPal que no es un correo no se guarda, y marca su campo" do
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos.merge(paypal: "pagos@empresa") }

    assert_response :unprocessable_entity
    assert_match(/El PayPal se cobra a un correo/, response.body)
    assert_select "input.campo-con-error[name='setup[paypal]']"
    assert_equal 0, Setup.count
  end

  test "con la cuenta mal escrita no cambia tampoco el WhatsApp" do
    poner_el_whatsapp("0414-1234567")
    sign_in @fundador

    patch siga_ajustes_path, params: { siga_setting: datos.merge(cuenta: "0134-123"),
                                       setup: datos_sueltos.merge(whatsapp: "0416-7778899") }

    assert_response :unprocessable_entity
    assert_equal "0414-1234567", Setup.whatsapp
  end

  # «Lo cambió por última vez» mira las dos tablas: cambiar solo el WhatsApp
  # también es cambiar los ajustes.
  test "dice quién cambió algo por última vez, en cualquiera de las dos tablas" do
    cargar_los_ajustes_de_siga
    SigaSetting.update_all(updated_at: 2.days.ago)
    sign_in @fundador

    patch siga_ajustes_path, params: { setup: { whatsapp: "0416-7778899" } }
    follow_redirect!

    assert_select ".siga-nota", text: /Lo cambió por última vez #{Regexp.escape(@fundador.nombre_completo)}/
  end

  # ⚠️ Operaciones ve el formulario, apagado: saber a qué cuenta pagan los
  # colegios es parte de atenderlos; cambiarla, no (decisión 22).
  test "operaciones los ve y no los cambia" do
    cargar_los_ajustes_de_siga
    sign_in @operaciones

    get siga_ajustes_path
    assert_response :success
    assert_select "fieldset[disabled]", 7
    assert_select "input[type=submit]", 0
    assert_select "input[name='setup[binance]'][value='987654321']"
    assert_select "input[name='setup[whatsapp]'][value='0414-1234567']"

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos.merge(whatsapp: "0416-7778899") }
    assert_match(/lo hace el fundador/, flash[:alert])
    assert_equal "987654321", Setup.binance
    assert_equal "0414-1234567", Setup.whatsapp
  end

  # Son de la plataforma: un colegio no llega ni a verlos.
  test "un director no ve ni cambia los ajustes de SIGA" do
    sign_in @a.director

    get siga_ajustes_path
    assert_redirected_to root_path

    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos }
    assert_redirected_to root_path
    assert_equal 0, SigaSetting.count
    assert_equal 0, Setup.count
  end

  # ── Los colegios lo ven en el momento ─────────────────────────────────────

  # El criterio del spec: «la portada, el registro y "Suscripción" los usan en
  # el momento, sin reiniciar nada».
  test "lo que se guarda aparece en «Suscripción» en la petición siguiente" do
    sign_in @fundador
    patch siga_ajustes_path, params: { siga_setting: datos, setup: datos_sueltos }
    sign_out @fundador

    sign_in @a.director
    get suscripcion_path

    assert_select ".suscripcion-medios", text: /Banesco \(0134\)/
    assert_select ".suscripcion-medios", text: /0426-5554433/
    assert_select ".suscripcion-medios", text: /pagos@empresa-nueva\.test/
    assert_select "a[href^='https://wa.me/584141234567']"
  end

  test "y vaciar un dato apaga su medio" do
    cargar_los_ajustes_de_siga
    sign_in @fundador
    patch siga_ajustes_path, params: { setup: { binance: "" } }
    sign_out @fundador

    sign_in @a.director
    get suscripcion_path

    assert_select ".suscripcion-medios", text: /Binance/, count: 0
    assert_select ".suscripcion-medio", 3
  end

  # ── El botón de WhatsApp sale de aquí ─────────────────────────────────────

  # ⚠️ El número es un ajuste, y ya no una variable leída al arrancar. Está en
  # las dos pantallas públicas donde alguien decide (decisión 20 del spec): la
  # portada y el registro.
  test "el WhatsApp de las pantallas públicas es el de los ajustes" do
    cargar_los_ajustes_de_siga(whatsapp: "0416-1112233")

    [ root_path, new_user_registration_path ].each do |pantalla|
      get pantalla

      assert_select "a[href^='https://wa.me/584161112233']", { minimum: 1 }, "falta el WhatsApp en #{pantalla}"
    end
  end

  # Un botón que abre un chat con nadie es peor que no tener botón.
  test "sin número, el botón no aparece" do
    con_la_variable("SIGA_WHATSAPP", nil) do
      [ root_path, new_user_registration_path ].each do |pantalla|
        get pantalla

        assert_response :success
        assert_select "a[href*='wa.me']", 0
      end
    end
  end

  # La variable sirve de valor inicial: el botón no desaparece el día del cambio.
  test "mientras nadie guarde los ajustes, vale la variable de entorno" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      get root_path

      assert_select "a[href^='https://wa.me/584241234567']"
    end
  end

  # ⚠️ Y el formulario la MUESTRA: el fundador ve el número que hoy ven los
  # colegios, y guardar por otra cosa lo deja escrito, no lo borra.
  test "el formulario muestra el número de la variable mientras no haya otro" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      sign_in @fundador
      get siga_ajustes_path

      assert_select "input[name='setup[whatsapp]'][value='0424-1234567']"
    end
  end

  # ⚠️ Una fila de WhatsApp vacía apaga la variable. Un envío que no trae el
  # campo no puede crearla: sería apagar el botón sin que nadie lo pidiera.
  test "guardar sin el campo del WhatsApp no apaga el de la variable" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      sign_in @fundador
      patch siga_ajustes_path, params: { siga_setting: datos, setup: { url_de_la_muestra: "https://demo.sigaeducando.com" } }

      assert_redirected_to siga_ajustes_path
      assert_nil Setup.fila("whatsapp")
      assert_equal "0424-1234567", Setup.whatsapp
    end
  end

  # ── La muestra sale de aquí ───────────────────────────────────────────────

  # Era la variable `SIGA_MUESTRA_URL`, que se ponía entrando al servidor.
  test "la dirección de la muestra la usa la portada en la petición siguiente" do
    sign_in @fundador
    patch siga_ajustes_path, params: { setup: { url_de_la_muestra: "https://otra-muestra.sigaeducando.com" } }
    sign_out @fundador

    get root_path
    assert_select ".portada-hero a[href=?]", muestra_path, text: /Vea un colegio funcionando/

    get muestra_path
    assert_redirected_to "https://otra-muestra.sigaeducando.com"
  end

  test "y vaciarla quita el botón de la portada" do
    Setup.create!(nombre: "url_de_la_muestra", valor: "https://demo.sigaeducando.com")
    sign_in @fundador
    patch siga_ajustes_path, params: { setup: { url_de_la_muestra: "" } }
    sign_out @fundador

    get root_path
    assert_select "a[href=?]", muestra_path, count: 0
  end

  private

  def datos
    { titular: "Empresa Nueva, C.A.", documento: "v-12.345.678",
      pago_movil_banco: "0134", pago_movil_telefono: "0426-5554433",
      cuenta: "0134-0000-00-0000009999" }
  end

  def datos_sueltos
    { whatsapp: "04141234567", url_de_la_muestra: "https://demo.sigaeducando.com/",
      binance: "112233445", paypal: " Pagos@Empresa-Nueva.test " }
  end
end
