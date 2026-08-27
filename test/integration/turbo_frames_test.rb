require "test_helper"

# Los `<turbo-frame>` de la app, vistos desde la página completa (MOR-149).
#
# ## Por qué esto no lo atrapaba el test del endpoint
#
# El buscador global se entregó pintando «Content missing». La respuesta del
# endpoint era **perfecta** —traía su frame, con sus resultados adentro— y yo la
# verifiqué así, con curl, y la di por buena.
#
# El bug vivía en el DOM de la página completa: el layout abría un
# `<turbo-frame id="resultados-de-busqueda">` y adentro renderizaba el parcial,
# que abría OTRO con el mismo id. Dos elementos con el mismo `id`, anidados, y
# Turbo sin saber cuál reemplazar.
#
# La lección, que es la misma de los controladores sin registrar: **verificar la
# parte no es verificar el todo.**
class TurboFramesTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # ⚠️ Un `id` de frame no puede aparecer dos veces en una página.
  #
  # El buscador global se entregó con «Content missing»: el layout abría un
  # `<turbo-frame id="resultados-de-busqueda">` y adentro renderizaba el parcial,
  # que abría OTRO con el mismo id. Al reemplazar, Turbo no sabía cuál era.
  #
  # Y **no se veía desde el endpoint**: la respuesta traía un frame perfecto. Solo
  # se ve mirando el DOM de la página completa, que es lo que este test hace.
  test "ningún id de turbo-frame se repite en una página" do
    [ dashboards_administrador_path, students_path, sections_path, teachers_path ].each do |ruta|
      get ruta
      assert_response :success

      ids = response.body.scan(/<turbo-frame[^>]*\bid=['"]([^'"]+)['"]/).flatten
      repetidos = ids.tally.select { |_, veces| veces > 1 }.keys

      assert_empty repetidos,
                   "#{ruta} tiene turbo-frames con id duplicado: #{repetidos.join(', ')}. " \
                   "Turbo no sabe cuál reemplazar y pinta «Content missing»."
    end
  end

  # ⚠️ El buscador NO usa `<turbo-frame>`, y volver a ponerlo trae dos bugs.
  #
  # El primero fue el id duplicado. El segundo, con el id ya único: **abrir un
  # resultado con Enter daba «Content missing»**, porque un enlace de adentro de
  # un frame navega DENTRO del frame, y la ficha de un alumno no contiene ningún
  # frame con ese id.
  #
  # Es exactamente lo que el comentario de `students/index.html.haml` ya explicaba
  # sobre `target: "_top"` — escrito en este proyecto, meses antes, y que no
  # apliqué acá.
  test "el buscador devuelve un fragmento suelto, sin turbo-frame" do
    get busqueda_path, params: { q: "prueba" }

    assert_response :success
    assert_select "a.busqueda-resultado", minimum: 1
    assert_no_match(/<turbo-frame/, response.body,
                    "el buscador volvió a envolverse en un turbo-frame: abrir un " \
                    "resultado con Enter va a dar «Content missing» otra vez")
  end

  # La comprobación de verdad: **seguir el enlace**. Un resultado lleva a una
  # página entera, y esa página tiene que responder.
  #
  # Se prueban los cuatro tipos porque el bug se veía distinto en cada uno: el
  # alumno y la materia daban «Content missing», y una sección hubiera dado lo
  # mismo. Que ande uno no prueba que anden los demás.
  test "cada resultado enlaza a una página que existe" do
    { "prueba" => "alumnos", "prof" => "profesores",
      "matem" => "materias", "1er" => "secciones" }.each do |termino, que|
      get busqueda_path, params: { q: termino }

      enlaces = css_select("a.busqueda-resultado").map { |a| a["href"] }.uniq
      assert enlaces.any?, "«#{termino}» no encontró #{que}: el test no está probando nada"

      enlaces.each do |ruta|
        get ruta
        assert_response :success, "un resultado enlazaba a #{ruta} y esa página no responde"
      end
    end
  end
end
