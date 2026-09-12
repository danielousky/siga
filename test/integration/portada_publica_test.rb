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

  # Los precios se leen de `Subscription::PLANES`, que es lo que cobra el
  # sistema. Escritos a mano en la vista, el día que cambie el precio la
  # portada seguiría prometiendo el viejo.
  test "los precios de la portada salen del mismo lugar que los cobra el sistema" do
    get root_path

    Subscription::PLANES.each_value do |datos|
      assert_select "span.portada-plan-monto", text: datos[:precio].to_s,
                    count: 1, message: "falta el precio #{datos[:precio]}"
    end
  end

  # ⚠️ La portada tenía DOS salidas —pedir una demostración y entrar— y ninguna
  # para el colegio que quiere empezar solo. Que es justamente al que apunta el
  # plan Inicial: sin costo, sin vendedor y sin esperar una llamada.
  test "la portada ofrece registrar un colegio" do
    get root_path

    assert_select "a[href=?]", registrarse_path, minimum: 1,
                  message: "sin esta puerta, /registrarse solo se alcanza con el enlace a mano"
    assert_select ".portada-alta-enlace", /Registre su colegio/
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
end
