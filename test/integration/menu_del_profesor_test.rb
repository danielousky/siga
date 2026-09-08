require "test_helper"

# El menú del profesor: sus secciones, agrupadas por nivel.
#
# QA de Daniel: *«lo mismo con ese chorrero de secciones, hay que dividirlas por
# Nivel»*. Un profesor de Matemática con diecinueve secciones tenía diecinueve
# renglones seguidos, primaria y bachillerato mezclados.
class MenuDelProfesorTest < ActionDispatch::IntegrationTest
  setup do
    # PRIMARIA: es quien evalúa por competencias.
    @a, = dos_colegios_completos(nivel: :primaria)
  end

  # ── Las dos ramas, y la regla de poda (etapa ③) ───────────────────────────
  #
  # Daniel: *«creo que la siguiente división natural es el área y la guía»*, y
  # sobre el menú viejo: *«lo mismo con ese chorrero de secciones»*.
  #
  # ⚠️ Lo que hace usable al árbol es que **un escalón aparece solo si divide
  # algo** — la misma regla de las pastillas y del selector de nivel. Sin ella,
  # un profesor de una sola área leería una rama con su nombre y las dieciséis
  # secciones adentro: un renglón que no decide nada y hay que abrir igual.
  test "el área NO aparece cuando el profesor dicta una sola" do
    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".sidebar-section-title", text: "Dicto"
    # Con una sola área y un solo grado, todo colapsa hasta la sección.
    assert_select ".sidebar-rama-titulo", text: @a.escenario.materia.name, count: 0
  end

  test "con dos áreas, cada una es una rama" do
    otra = con_el_colegio(@a.colegio) do
      materia = Subject.create!(name: "Ciencias Naturales", code: "CNA", school: @a.colegio)
      seccion = Section.create!(grade: @a.seccion.grade, academic_period: @a.escenario.periodo,
                                name: "B", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion, subject: materia)
      materia
    end

    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".sidebar-rama-titulo", text: @a.escenario.materia.name
    assert_select ".sidebar-rama-titulo", text: otra.name
  end

  # ⚠️ Sin secciones que guiar, la rama NO se dibuja — ni vacía.
  # Decisión de Daniel: *«no se ve si no es guía»*.
  test "sin sección guía, la rama no aparece" do
    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".sidebar-section-title", text: "Soy guía de", count: 0

    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    get dashboards_profesor_path

    assert_select ".sidebar-section-title", text: "Soy guía de"
  end

  # ⚠️ La MISMA sección en las dos ramas, y no es un bug: son dos trabajos.
  # Como guía entro a la sección —la asistencia es de todos—; como docente del
  # área, a una asignación. Por eso solo la segunda lleva el área en la URL.
  test "la sección que guío y dicto sale en las dos, con destinos distintos" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    sign_in @a.profesor
    get dashboards_profesor_path

    destinos = css_select("a.sidebar-nav-link").map { |a| a["href"] }.select { |h| h.include?("/secciones/") }

    assert_includes destinos, section_path(@a.seccion)
    assert_includes destinos, section_path(@a.seccion, area: @a.escenario.materia.id)
  end

  # ── El resaltado marca UNA sección, no todas (QA del 7 de septiembre) ──────
  #
  # Daniel: *«el resaltado absorbe todas las secciones en el side»*. Y era
  # literal: las nueve secciones apuntan a `sections#show`, así que
  # `enlace_activo?` —que solo comparaba el CONTROLLER— las daba todas por
  # activas. Un menú que dice «estás en todas partes» no dice nada.
  # ⚠️ Con el árbol, la MISMA sección tiene dos destinos y se marcan distinto:
  # sin área es «Soy guía de» (la sección entera, para pasar lista) y con área
  # es la asignación (para planificar y calificar ESA).
  test "cada destino de la misma sección marca su propia entrada" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    sign_in @a.profesor

    get section_path(@a.seccion)
    assert_equal [ section_path(@a.seccion) ],
                 css_select("a.sidebar-nav-link.active").map { |a| a["href"] }

    get section_path(@a.seccion, area: @a.escenario.materia.id)
    assert_equal [ section_path(@a.seccion, area: @a.escenario.materia.id) ],
                 css_select("a.sidebar-nav-link.active").map { |a| a["href"] }
  end

  # ⚠️ «Mi trabajo» se retiró: sus tres entradas son pestañas de la sección.
  #
  # Daniel, tachando ese grupo: *«al final esta parte tiende a desaparecer»*. Es
  # la consecuencia de que el trabajo sea por sección — un renglón que lleva a
  # «todas mis competencias» sin decir de cuál es justo lo que las pestañas
  # evitan, y encima obliga a elegir grado, área, sección y lapso otra vez.
  test "el menú del profesor son sus secciones, y nada más" do
    sign_in @a.profesor
    get dashboards_profesor_path

    titulos = css_select(".sidebar-section-title").map(&:text)

    assert_equal [ "Dicto" ], titulos
    assert_select "a.sidebar-nav-link[data-nombre=?]", "Competencias e indicadores", count: 0
    assert_select "a.sidebar-nav-link[data-nombre=?]", "Mis evaluaciones", count: 0
  end

  # ⚠️ Pero las PANTALLAS no desaparecen: la dirección las usa desde su menú, y
  # un enlace viejo tiene que seguir abriendo.
  test "las pantallas que salieron del menú siguen respondiendo" do
    sign_in @a.profesor

    get evaluation_activities_path
    assert_response :success

    get competencies_path
    assert_response :success
  end

  # ⚠️ El resaltado marca UNA asignación, no todas las de la misma sección.
  #
  # Con el árbol, «6to Grado – A» aparece una vez por cada área que dicto ahí,
  # más otra en «Soy guía de». Comparando solo el id de la sección se marcaban
  # las tres: es la trampa del 7 de septiembre un escalón más abajo, porque lo
  # que identifica el destino ya no es la sección sino la asignación.
  test "abierta un área de una sección, solo esa entrada se resalta" do
    otra = con_el_colegio(@a.colegio) do
      materia = Subject.create!(name: "Ciencias Naturales", code: "CNA2", school: @a.colegio)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: @a.seccion, subject: materia)
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
      materia
    end

    sign_in @a.profesor
    get section_path(@a.seccion, area: otra.id)

    marcadas = css_select("a.sidebar-nav-link.active").map { |a| a["href"] }
    assert_equal [ section_path(@a.seccion, area: otra.id) ], marcadas
  end
end
