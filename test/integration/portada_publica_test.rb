require "test_helper"

# La superficie pública (MOR-135).
#
# Es la única parte del sistema que ve alguien que todavía no es cliente, y la
# que decide si llega a serlo. Estos tests fijan las cosas que se rompieron una
# vez y no deberían volver.
class PortadaPublicaTest < ActionDispatch::IntegrationTest
  test "la portada es pública" do
    get root_path
    assert_response :success
  end

  # Cuatro de los seis enlaces del pie anterior no iban a ninguna parte: dos
  # anclas inexistentes (`#features`, `#benefits`) y dos `href="#"`. Un enlace
  # muerto le enseña a la visitante a no confiar en los demás.
  test "todos los enlaces de la portada llevan a alguna parte" do
    get root_path

    destinos = css_select("a").map { |a| a["href"] }.compact
    assert destinos.any?, "la portada debería tener enlaces"

    muertos = destinos.select { |d| d == "#" || d.blank? }
    assert_empty muertos, "hay enlaces que no llevan a ninguna parte: #{muertos.inspect}"

    # Un ancla solo vale si el id existe en la misma página.
    css_select("a[href^='#']").map { |a| a["href"].delete_prefix("#") }.each do |ancla|
      assert_select "##{ancla}", 1, "el pie apunta a ##{ancla} y ese id no existe"
    end
  end

  # "100 % Digital · 24/7 · ∞ Usuarios · ⚡ Rápido" no decían nada, y
  # "Únete a las instituciones que han transformado su administración con SIGA"
  # era directamente falso: no hay ninguna todavía.
  test "no quedan cifras de relleno ni la afirmación falsa de clientes" do
    get root_path

    assert_no_match(/∞/, response.body)
    assert_no_match(/24\/7/, response.body)
    assert_no_match(/instituciones educativas que han transformado/i, response.body)
  end

  # El precio se lee de `Subscription::PRECIO_POR_ALUMNO`, que es lo que cobra
  # el sistema. Escrito a mano en la vista, el día que cambie el precio la
  # portada seguiría prometiendo el viejo.
  test "el precio de la portada sale del mismo lugar que lo cobra el sistema" do
    get root_path

    precio = ApplicationController.helpers.cifra(Subscription::PRECIO_POR_ALUMNO)
    assert_select "span.portada-plan-monto", text: precio, count: 1,
                  message: "falta el precio por alumno, #{precio}"
    # ⚠️ El precio es final: la portada no dice «más IVA» (decisión 28 del spec).
    minimo = ApplicationController.helpers.numero_en_dolares(Subscription::MINIMO_MENSUAL)
    assert_select "p.portada-plan-cupo", text: /con un mínimo de #{Regexp.escape(minimo)} al mes/
    assert_select "p.portada-plan-cupo", text: /IVA/, count: 0
  end

  # ── La puerta (spec `del-registro-al-cobro`, tanda 4) ─────────────────────
  #
  #     ANTES                                      AHORA
  #     [Agende una demostración de 20 min]        [Registre su colegio →]
  #     [Entrar al sistema]                        [Escríbanos por WhatsApp]
  #     ¿Todavía no tiene cuenta? Registre…        [Vea un colegio funcionando]

  # ⚠️ El registro es el botón PRINCIPAL, no un enlace discreto. Daniel, 8 de
  # octubre de 2026: *«si la persona registra el colegio (cosa que no se induce
  # por ningún lado)…»*.
  test "el botón principal de la portada registra un colegio" do
    get root_path

    assert_select ".portada-hero .portada-cta--principal[href=?]", registrarse_path, text: /Registre su colegio/
    assert_select ".portada-cierre .portada-cta--principal[href=?]", registrarse_path
  end

  # Las solicitudes de demostración no le avisaban a nadie: la puerta era un
  # formulario que nadie leía.
  test "la portada ya no ofrece pedir una demostración" do
    get root_path

    assert_select "a[href*='demo_requests']", 0
    assert_no_match(/Agende una demostración|Pedir una demostración/i, response.body)
  end

  test "la portada lleva el WhatsApp de SIGA, arriba y en el cierre" do
    Setup.create!(nombre: "whatsapp", valor: "0414-1234567")

    get root_path

    assert_select ".portada-hero a[href^='https://wa.me/584141234567']", text: /WhatsApp/
    assert_select ".portada-cierre a[href^='https://wa.me/584141234567']"
  end

  # Y fijo en la esquina (decisión 38): entre el de arriba y el del cierre hay
  # seis secciones. Es solo un glifo, así que su nombre va en `aria-label`.
  test "con número, la portada lleva el WhatsApp fijo en la esquina" do
    Setup.create!(nombre: "whatsapp", valor: "0414-1234567")

    get root_path

    assert_select ".portada a.portada-whatsapp[href^='https://wa.me/584141234567']" \
                  "[aria-label='Escríbanos por WhatsApp'][target=_blank][rel=noopener]", 1
    assert_select "a.portada-whatsapp svg[aria-hidden=true]"
  end

  test "sin número, no hay WhatsApp en la esquina" do
    Setup.create!(nombre: "whatsapp", valor: "")

    get root_path

    assert_select "a.portada-whatsapp", 0
  end

  # La muestra vive en otra instancia: la portada la enlaza solo si se sabe dónde.
  test "con la muestra configurada, la portada invita a ver un colegio funcionando" do
    con_la_direccion_de_la_muestra("https://demo.sigaeducando.com") do
      get root_path

      assert_select ".portada-hero a[href=?]", muestra_path, text: /Vea un colegio funcionando/
      assert_select ".portada-pieza-mas[href=?]", muestra_path, text: /Verlo funcionando/, count: 3

      get muestra_path
      assert_redirected_to "https://demo.sigaeducando.com"
    end
  end

  # Un botón que lleva a un 404 le enseña a la visitante a no confiar en los demás.
  test "sin la muestra configurada, no la ofrece: invita a probarlo en su colegio" do
    con_la_direccion_de_la_muestra(nil) do
      get root_path

      assert_select "a[href=?]", muestra_path, count: 0
      assert_select ".portada-pieza-mas[href=?]", registrarse_path, text: /Probarlo en su colegio/, count: 3
    end
  end

  # ⚠️ El precio NO va en el hero. Daniel: *«se ve como antipático, como que si
  # le estoy cobrando antes de sentarse»*.
  #
  # No es esconderlo —sigue completo en «La suscripción», y el test de arriba lo
  # exige— es que ahí lo contesta quien fue a buscarlo.
  test "el hero no habla de plata" do
    get root_path

    # ⚠️ Se mira `.portada-hero-inner` y no el `<header>` entero: la barra de
    # arriba vive adentro del header y ahí «La suscripción» es el nombre de una
    # sección, no un precio.
    tesis = css_select(".portada-hero-inner").first
    assert tesis.present?, "no se encontró el bloque de la tesis"
    assert_no_match(/\$|precio|suscripción mensual/i, tesis.to_s,
                    "el hero volvió a poner el precio delante de quien todavía no preguntó")
  end

  # La superficie pública trata de usted; adentro se tutea. Decisión de Daniel.
  test "la portada trata de usted, no de tú" do
    get root_path

    texto = response.body
    %w[Únete tuyo tienes puedes tu\ colegio].each do |tuteo|
      assert_no_match(/\b#{Regexp.escape(tuteo)}\b/i, texto,
                      "#{tuteo.inspect} tutea en una superficie pública")
    end
  end

  test "la portada trae la tarjeta social para el reenvío por WhatsApp" do
    get root_path

    assert_select "meta[property='og:image']"
    assert_select "meta[property='og:description']"
    assert_select "title"
  end

  private

  # Dónde vive la muestra: un ajuste de `/siga` (`Setup`). Lo deshace la
  # transacción del test.
  def con_la_direccion_de_la_muestra(direccion)
    Setup.where(nombre: "url_de_la_muestra").delete_all
    Setup.create!(nombre: "url_de_la_muestra", valor: direccion) if direccion
    yield
  end
end
