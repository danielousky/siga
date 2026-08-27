require "test_helper"

# El menú lateral, recorrido entero (MOR-149).
#
# ## Qué prueba esto que no probaba nada antes
#
# El menú se declaraba a mano, con `'active' if controller_name == 'students'`
# repetido cuarenta veces. Escribir mal ese nombre no rompe nada: el enlace
# simplemente **nunca se marca**, y eso no se ve mirando una pantalla — se ve
# entrando a las dieciocho.
#
# Ahora «estás acá» se deduce de la ruta, y este test es lo que sostiene esa
# promesa: entra a cada enlace del menú y exige que el menú lo señale.
class MenuTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # Un enlace del menú que da 404 o 500 es peor que no estar: enseña que los
  # enlaces de este sistema a veces no funcionan.
  #
  # Se siguen las redirecciones porque algunas son de diseño: `/asistencia` entra
  # derecho a la sección cuando el profesor tiene una sola.
  test "todo enlace del menú lleva a una página que responde" do
    enlaces_del_menu.each do |nombre, ruta|
      get ruta
      follow_redirect! while response.redirect?

      assert_response :success, "«#{nombre}» del menú lleva a #{ruta} y no responde"
    end
  end

  # ⚠️ El corazón de la convención.
  #
  # Al entrar por un enlace, el menú tiene que marcarlo — y marcar SOLO a ese.
  # Dos marcados a la vez fue un bug real: «Asistencia» e «Inasistencias»
  # apuntaban al mismo controlador y se encendían las dos, así que el menú
  # señalaba dos lugares para una sola pantalla.
  test "al entrar por un enlace, el menú marca ese y solo ese" do
    enlaces_del_menu.each do |nombre, ruta|
      get ruta
      follow_redirect! while response.redirect?

      marcados = css_select("a.sidebar-nav-link.active").map { |a| a["data-nombre"] }

      assert_includes marcados, nombre,
                      "entré por «#{nombre}» (#{ruta}) y el menú no lo marca: " \
                      "la ruta no cae en el controlador que el menú espera"
      assert_equal 1, marcados.size,
                   "«#{nombre}» (#{ruta}) enciende #{marcados.size} enlaces del menú " \
                   "(#{marcados.join(', ')}): el menú señala dos lugares para una pantalla"
    end
  end

  # Esconder dónde estás parado es peor que un menú largo: si la pantalla actual
  # vive en un grupo plegado, ese grupo se abre solo.
  test "el grupo que contiene la pantalla actual se dibuja abierto" do
    get importaciones_path # vive en Configuración, que nace plegado

    abierto = css_select("details#grupo-configuracion").first
    assert abierto, "no está el grupo Configuración"
    assert abierto["open"], "estoy en Importar datos y su grupo salió plegado"
  end

  test "el grupo de configuración nace plegado cuando no estás adentro" do
    get dashboards_administrador_path

    grupo = css_select("details#grupo-configuracion").first
    assert_nil grupo["open"], "Configuración salió abierto sin que nadie esté adentro"
  end

  # Las dos fusiones que pidió la tanda 2: una entrada de menú, dos pestañas.
  test "asistencia e inasistencias son pestañas de la misma pantalla" do
    [ asistencias_path, reporte_asistencia_path ].each do |ruta|
      get ruta
      follow_redirect! while response.redirect?

      assert_select "a.pestana", 2
      assert_select "a.pestana.activa", 1
      assert_equal 1, css_select("a.sidebar-nav-link.active").size,
                   "#{ruta} debería marcar UNA entrada del menú: son la misma pantalla"
    end
  end

  test "boletines y constancias son pestañas de la misma pantalla" do
    [ report_cards_path, constancias_path ].each do |ruta|
      get ruta

      assert_select "a.pestana", 2
      assert_select "a.pestana.activa", 1
      assert_equal [ "Documentos" ],
                   css_select("a.sidebar-nav-link.active").map { |a| a["data-nombre"] },
                   "#{ruta} tiene que marcar «Documentos»: boletín y constancia son " \
                   "el mismo trabajo con distinto papel al final"
    end
  end

  # El orden de los grupos, que es la decisión de producto de la tanda 2: el
  # corte pasó de FRECUENCIA («Día a día» / «El colegio») a QUÉ ES LA COSA, que
  # es como la gente pregunta — «¿dónde están los profesores?», en Usuarios.
  test "los grupos van en el orden acordado y configuración al final" do
    get dashboards_administrador_path

    titulos = css_select(".sidebar-index .sidebar-section-title").map(&:text).map(&:strip)

    assert_equal [ "Usuarios", "Académico", "Día a día", "Reportes", "Configuración" ], titulos
  end

  # ⚠️ Heredado de `MOR-135`, y sigue siendo el riesgo más caro de este menú.
  #
  # En el teléfono el menú es una tira horizontal con `overflow-y: hidden`, y un
  # grupo plegado esconde sus enlaces creciendo hacia abajo: justo donde está el
  # recorte. Antes se resolvía renderizando el menú DOS veces —una plegada y una
  # plana—, lo que duplicaba cada enlace; ahora se dibuja una sola vez y el CSS
  # lo destapa con `::details-content`.
  #
  # Lo que este test sostiene es la mitad que el CSS no puede: que los enlaces
  # ESTÉN en el HTML aunque su grupo salga plegado. Si algún día alguien los
  # renderiza condicionalmente al `open`, desaparecen del teléfono.
  test "los enlaces de un grupo plegado igual están en el HTML" do
    get dashboards_administrador_path

    plegado = css_select("details.sidebar-grupo:not([open])").first
    assert plegado, "ningún grupo salió plegado: el test no está probando nada"

    assert plegado.css("a.sidebar-nav-link").any?,
           "el grupo #{plegado['id']} salió plegado y SIN enlaces adentro: " \
           "en el teléfono esas pantallas quedan inalcanzables"
  end

  # El menú se dibuja UNA vez. Dos copias fue el diseño anterior, y es lo que
  # hace que arreglar un enlace en una no lo arregle en la otra.
  test "ningún enlace del menú aparece dos veces" do
    get dashboards_administrador_path

    rutas = css_select(".sidebar-index a.sidebar-nav-link").map { |a| a["href"] }
    repetidas = rutas.tally.select { |_, veces| veces > 1 }.keys

    assert_empty repetidas, "el menú dibuja dos veces: #{repetidas.join(', ')}"
  end

  private

  # Los enlaces tal como los ve quien mira la pantalla, no los que yo creo que
  # puse: se leen del HTML renderizado.
  def enlaces_del_menu
    get dashboards_administrador_path

    css_select("a.sidebar-nav-link").map { |a| [ a["data-nombre"], a["href"] ] }
  end
end
