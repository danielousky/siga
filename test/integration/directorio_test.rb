require "test_helper"

# El directorio público de planteles.
#
# ## Qué se prueba, y por qué justo esto
#
# Lo que trae tráfico no es que la página exista: es que cada nivel sea una URL
# de verdad, con su título propio, enlazada desde la de arriba. Un directorio
# que responde 200 y comparte el `<title>` de la marca en sus 13.434 páginas es
# una sola página repetida — la manera exacta de no rankear con ninguna.
class DirectorioTest < ActionDispatch::IntegrationTest
  setup do
    @plantel = Current.sin_aislamiento do
      PlantelOficial.create!(nombre: "U.E.P. COLEGIO DE PRUEBA DEL DIRECTORIO",
                             dea_code: "PD09999901", entidad_federal: "Miranda",
                             municipio: "Baruta")
    end
  end

  # ── se entra sin cuenta ───────────────────────────────────────────────────

  test "los cuatro niveles son públicos" do
    [ directorio_path,
      directorio_estado_path("miranda"),
      directorio_municipio_path("miranda", "baruta"),
      directorio_plantel_path("miranda", "baruta", @plantel.slug) ].each do |ruta|
      get ruta
      assert_response :success, "#{ruta} debería abrirse sin sesión"
    end
  end

  # ── cada nivel enlaza al siguiente ────────────────────────────────────────

  # ⚠️ Sin el enlace, la página de abajo existe y NADIE la encuentra: un
  # buscador llega por enlaces, no adivinando URL.
  test "el índice enlaza al estado, el estado al municipio y el municipio al plantel" do
    get directorio_path
    assert_select "a[href=?]", directorio_estado_path("miranda")

    get directorio_estado_path("miranda")
    assert_select "a[href=?]", directorio_municipio_path("miranda", "baruta")

    get directorio_municipio_path("miranda", "baruta")
    assert_select "a[href=?]", directorio_plantel_path("miranda", "baruta", @plantel.slug)
  end

  # ── el título es propio de cada página ────────────────────────────────────

  test "cada nivel tiene su propio titulo y su propia descripcion" do
    titulos = [ directorio_path,
                directorio_estado_path("miranda"),
                directorio_municipio_path("miranda", "baruta"),
                directorio_plantel_path("miranda", "baruta", @plantel.slug) ].map do |ruta|
      get ruta
      css_select("title").first.text
    end

    assert_equal titulos.size, titulos.uniq.size,
                 "dos niveles con el mismo <title> son la misma página para un buscador"
    assert_match(/Miranda/, titulos[1])
    assert_match(/Baruta/, titulos[2])
    assert_match(/PD09999901/, titulos[3], "la ficha tiene que decir el código DEA")
  end

  # ── el remate, que es para lo que existe todo esto ────────────────────────

  # ⚠️ Quien llegó a Google buscando su propio colegio abre el formulario con el
  # nombre y el código ya puestos. Sin esto, el directorio es una tabla bonita
  # que no hace nada por SIGA.
  test "la ficha lleva al registro con el colegio ya puesto" do
    get directorio_plantel_path("miranda", "baruta", @plantel.slug)

    # ⚠️ Rails escapa el corchete del parámetro anidado —`school%5Bdea_code%5D`—
    # así que lo que se busca es el CÓDIGO, no el nombre del campo.
    assert_select "a[href*=?]", "PD09999901"
  end

  test "el registro abre con lo que trae la URL, y editable" do
    get new_user_registration_path(school: { name: "COLEGIO SUGERIDO", dea_code: "PD09999901" })

    assert_select "input[name='school[name]'][value=?]", "COLEGIO SUGERIDO"
    assert_select "input[name='school[dea_code]'][value=?]", "PD09999901"
    assert_select "input[name='school[name]'][readonly]", 0,
                  "es una sugerencia: tiene que poder cambiarse"
  end

  # ⚠️ Solo el nombre y el código. Aceptar más convertiría la URL en una manera
  # de preparar un registro entero desde afuera.
  test "el registro ignora lo que no sea el nombre y el código" do
    get new_user_registration_path(school: { name: "X", tope_de_arrastre: 99 })

    assert_response :success
    assert_select "input[name='school[tope_de_arrastre]'][value=?]", "99", 0
  end

  # ── lo que NO se publica ──────────────────────────────────────────────────

  # ⚠️ Sin municipio no hay dónde colgarlo en el árbol, y sin código DEA su URL
  # no es única. Los 2.520 así siguen sirviendo para SUGERIR al registrarse,
  # que es para lo que se compiló el catálogo.
  test "un plantel sin municipio o sin código no sale en el directorio" do
    sin_nada = Current.sin_aislamiento do
      PlantelOficial.create!(nombre: "PLANTEL SIN UBICAR", entidad_federal: "Miranda")
    end

    get directorio_municipio_path("miranda", "baruta")
    assert_select "a", text: "PLANTEL SIN UBICAR", count: 0
    assert_nil sin_nada.slug, "sin código no hay URL que dar"
  end

  # ⚠️ Dos URL para la misma ficha es justo lo que el canonical existe para
  # evitar: el plantel tiene que estar DONDE DICE la URL.
  test "una ficha bajo un municipio que no es el suyo da 404" do
    get directorio_plantel_path("zulia", "maracaibo", @plantel.slug)

    assert_response :not_found
  end

  test "un estado o un municipio inventados dan 404" do
    get directorio_estado_path("narnia")
    assert_response :not_found

    get directorio_municipio_path("miranda", "narnia")
    assert_response :not_found
  end

  # ── el slug ───────────────────────────────────────────────────────────────

  # ⚠️ El nombre del slug es decoración para el buscador: lo que identifica es
  # la cola. Así, corregir una tilde en el catálogo no rompe el enlace de nadie.
  test "el slug se resuelve por el código, no por el nombre" do
    assert_equal @plantel.id, PlantelOficial.por_slug("cualquier-otro-nombre-pd09999901").id
  end

  # ── el sitemap ────────────────────────────────────────────────────────────

  test "el sitemap trae los estados y los municipios, y NO las fichas" do
    get sitemap_path

    assert_match %r{<loc>[^<]+/colegios</loc>}, response.body
    assert_match %r{<loc>[^<]+/colegios/miranda</loc>}, response.body
    assert_match %r{<loc>[^<]+/colegios/miranda/baruta</loc>}, response.body
    # ⚠️ Trece mil páginas finas en un sitemap le dicen a Google «indexa esto»
    # trece mil veces, y la desconfianza alcanza al sitio entero.
    assert_no_match %r{<loc>[^<]+/colegios/miranda/baruta/[^<]+</loc>}, response.body
  end

  # ── el estado escrito de dos maneras ──────────────────────────────────────

  # ⚠️ En el catálogo conviven «Bolívar» y «Bolivar». Sin normalizar, el
  # directorio mostraría dos estados y cada uno con la mitad de los planteles.
  test "un estado escrito con y sin tilde es UN estado" do
    Current.sin_aislamiento do
      PlantelOficial.create!(nombre: "CON TILDE", dea_code: "PD09999902",
                             entidad_federal: "Bolívar", municipio: "Caroní")
      PlantelOficial.create!(nombre: "SIN TILDE", dea_code: "PD09999903",
                             entidad_federal: "Bolivar", municipio: "Caroní")
    end

    get directorio_path
    assert_select "a", text: "Bolivar", count: 0, message: "el fantasma sin tilde no va"

    get directorio_municipio_path("bolivar", "caroni")
    assert_select "a", text: "CON TILDE"
    assert_select "a", text: "SIN TILDE"
  end
end
