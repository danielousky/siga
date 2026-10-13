require "test_helper"

# Lo que un buscador necesita para traer tráfico solo.
#
# ## Por qué esto se prueba y no se mira a ojo
#
# Todo lo de SEO es INVISIBLE: vive en el `<head>` y en dos archivos de texto.
# Una etiqueta que se cae no rompe ninguna pantalla, no aparece en ningún log y
# nadie la echa de menos — se nota tres meses después, en que el tráfico no
# llegó. Es el mismo silencio que dejó a `@sugerido` sin escribir durante cuatro
# etapas.
class SeoTest < ActionDispatch::IntegrationTest
  setup do
    @colegio = escenario_academico(nombre: "Colegio SEO").colegio
  end

  # ── robots.txt ────────────────────────────────────────────────────────────

  test "robots.txt dice dónde está el sitemap" do
    get robots_path

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match %r{^Sitemap: https?://.+/sitemap\.xml$}, response.body
  end

  # ⚠️ Lo que se prohíbe NO es «lo que pide login»: ahí un buscador no entra
  # igual. Es lo que contesta 200 sin cuenta y no debe salir en un resultado.
  test "robots.txt esconde el documento de una persona y el autocompletado" do
    get robots_path

    assert_match %r{^Disallow: /verificar/$}, response.body,
                 "una constancia indexada es el boletín de un niño en Google"
    assert_match %r{^Disallow: /planteles$}, response.body
  end

  # ⚠️ `/verificar` A SECAS se indexa: alguien busca «verificar una constancia
  # de SIGA» y tiene que encontrar el formulario. Se esconde la que trae código.
  test "robots.txt no esconde el formulario de verificar" do
    get robots_path

    assert_no_match %r{^Disallow: /verificar$}, response.body
  end

  # ── sitemap.xml ───────────────────────────────────────────────────────────

  test "el sitemap trae las públicas y NINGUNA del panel" do
    get sitemap_path

    assert_response :success
    assert_equal "application/xml", response.media_type
    [ "/registrarse", "/verificar" ].each do |ruta|
      assert_match %r{<loc>https?://[^<]+#{Regexp.escape(ruta)}</loc>}, response.body
    end
    # El formulario de demostración salió: su dirección lleva a la portada, y
    # un mapa no anuncia una página que redirige.
    assert_no_match %r{demo_requests}, response.body
    # ⚠️ Un sitemap con el panel adentro le regala a cualquiera el mapa exacto
    # de la aplicación, aunque cada pantalla pida login.
    %w[/alumnos /boletines /importaciones /siga].each do |privada|
      assert_no_match %r{<loc>[^<]*#{Regexp.escape(privada)}</loc>}, response.body,
                      "#{privada} no tiene nada que hacer en el sitemap"
    end
  end

  # ── canonical ─────────────────────────────────────────────────────────────

  # ⚠️ `/?utm_source=whatsapp` y `/` son la misma página, y sin canonical son
  # dos: el texto se reparte entre las dos y ninguna rankea.
  test "el canonical se come la query string" do
    get root_path(utm_source: "whatsapp", fbclid: "abc123")

    assert_select "link[rel=canonical]" do |enlaces|
      href = enlaces.first["href"]
      assert_not_includes href, "utm_source"
      assert href.end_with?("/"), "el canonical de la portada es la raíz, no #{href}"
    end
  end

  # ── noindex ───────────────────────────────────────────────────────────────

  test "la portada y el registro SÍ se indexan" do
    [ root_path, new_user_registration_path ].each do |ruta|
      get ruta
      assert_select "meta[name=robots]", 0, "#{ruta} no debería llevar noindex"
    end
  end

  # ⚠️ Un código de verificación identifica el documento de una persona.
  test "una verificación con código lleva noindex" do
    get verificar_path(code: "NOEXISTE1234")

    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
  end

  test "adentro del panel todo lleva noindex" do
    director = con_el_colegio(@colegio) do
      usuario = usuario("dir", @colegio.id)
      Admin.create!(user: usuario, school: @colegio, role: :director)
      usuario
    end
    sign_in director

    get dashboards_administrador_path

    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
  end

  # ── la ficha estructurada ─────────────────────────────────────────────────

  # ⚠️ El precio sale de `Subscription::PRECIO_POR_ALUMNO`. La descripción lo
  # tenía escrito a mano y decía «desde 25 $» meses después de subir a 30.
  test "la ficha estructurada trae el precio que cobra el sistema" do
    get root_path

    fichas = css_select("script[type='application/ld+json']")
    assert_equal 1, fichas.size, "la ficha del producto va UNA vez, en la portada"

    ficha = JSON.parse(fichas.first.text)
    assert_equal "SoftwareApplication", ficha["@type"]
    assert_equal "Venezuela", ficha.dig("areaServed", "name")

    ofertas = ficha["offers"]
    assert_equal 1, ofertas.size, "un solo plan, una sola oferta"
    assert_equal format("%.2f", Subscription::PRECIO_POR_ALUMNO), ofertas.first["price"]
    assert_equal "alumno", ofertas.first.dig("priceSpecification", "referenceQuantity", "unitText")
    # ⚠️ Del IVA la ficha no afirma nada: el precio es final y no se desglosa
    # (decisión 28 del spec). Decía `valueAddedTaxIncluded: false`.
    assert_not ofertas.first["priceSpecification"].key?("valueAddedTaxIncluded")
    assert_no_match(/IVA/, ofertas.first["description"])
  end

  # ⚠️ UNA sola: repetirla en cada pantalla pública le dice a un buscador que
  # hay tres productos distintos con el mismo nombre y el mismo precio.
  test "la ficha estructurada NO se repite fuera de la portada" do
    get new_user_registration_path

    assert_select "script[type='application/ld+json']", 0
  end

  # ⚠️ Y la descripción tampoco puede tenerlo escrito a mano.
  test "la descripción no promete un precio viejo" do
    get root_path

    assert_select "meta[name=description]" do |etiquetas|
      texto = etiquetas.first["content"]
      assert_includes texto, "#{ApplicationController.helpers.cifra(Subscription::PRECIO_POR_ALUMNO)} $ por alumno"
    end
  end
end
