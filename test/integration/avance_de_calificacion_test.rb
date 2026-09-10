require "test_helper"

# El avance de calificación, en el panel y en el menú (MOR-223).
#
# Daniel: *«en el panel de cada sección, además de un enlace al detalle, hay un
# indicativo de si les falta por calificar alguna nota de esa sección o si ya
# está calificada. Al hacer clic, me voy directamente a la calificación que
# falta. Si ya las tengo calificadas me aparece 20 de 20 y un check en verde; si
# me falta por calificar me aparece 20 de 30 y en amarillo; si no tengo nada
# calificado, me aparece en rojo»*.
class AvanceDeCalificacionTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nivel: :primaria, alumnos: 3)
    @lapso = @esc.lapso(1)
    @profesor = con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "Carlos", last_name: "García",
                             email: "carlos.avance@test.edu", password: "123123",
                             document: "V-89000111", document_type: :cedula_v)
      docente = Teacher.create!(user: usuario, school: @esc.colegio)
      TeacherSection.create!(teacher: docente, section: @esc.seccion, subject: @esc.materia)
      usuario
    end
  end

  test "una sección con todo cargado sale como completa" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Examen")
      Enrollment.where(section: @esc.seccion).map(&:student).each { |a| nota(examen, a, 15) }
    end

    sign_in @profesor
    get dashboards_profesor_path

    assert_select ".subject-avance--completo", text: /3 de 3/
  end

  test "a medias sale en ámbar, y sin nada en rojo" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Examen")
      nota(examen, Enrollment.where(section: @esc.seccion).first.student, 15)
    end

    sign_in @profesor
    get dashboards_profesor_path
    assert_select ".subject-avance--a_medias", text: /1 de 3/

    con_el_colegio(@esc.colegio) { ActivityGrade.destroy_all }
    get dashboards_profesor_path
    assert_select ".subject-avance--vacio", text: /0 de 3/
  end

  # ⚠️ El enlace lleva a la PRIMERA evaluación incompleta, no al listado: el
  # profesor entra a poner las que faltan, no a buscar cuál era.
  test "el avance enlaza a la evaluación que falta" do
    incompleta = con_el_colegio(@esc.colegio) do
      completa = actividad(@esc, lapso: @lapso, peso: 50, descripcion: "Ya está")
      Enrollment.where(section: @esc.seccion).map(&:student).each { |a| nota(completa, a, 15) }
      actividad(@esc, lapso: @lapso, peso: 50, descripcion: "Falta ésta")
    end

    sign_in @profesor
    get dashboards_profesor_path

    assert_select "a.subject-avance[href=?]", evaluation_activity_notas_path(incompleta)
  end

  # ⚠️ Una sección SIN evaluaciones no es «cero cargadas»: no hay nada que
  # cargar, y pintarla de rojo le reclama a un profesor por algo que no existe.
  test "sin evaluaciones no se pinta de rojo" do
    sign_in @profesor
    get dashboards_profesor_path

    assert_select ".subject-avance--sin_evaluaciones"
    assert_select ".subject-avance--vacio", count: 0
  end

  # ⚠️ El peor de sus áreas manda en el menú. Un profesor con una al día y otra
  # sin empezar necesita ver que le falta: promediarlas escondería el cero.
  test "en el menú, el peor estado de la sección es el que se muestra" do
    con_el_colegio(@esc.colegio) do
      otra = Subject.create!(department: @esc.materia.department, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @esc.grado, subject: otra)
      TeacherSection.create!(teacher: Teacher.find_by(user: @profesor), section: @esc.seccion, subject: otra)

      completa = actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Al día")
      Enrollment.where(section: @esc.seccion).map(&:student).each { |a| nota(completa, a, 15) }

      EvaluationActivity.create!(section: @esc.seccion, subject: otra, evaluation_moment: @lapso,
                                 description: "Sin empezar", weight_percentage: 100,
                                 date_scheduled: Date.new(2025, 11, 6))
    end

    sign_in @profesor
    get dashboards_profesor_path

    # Con un área al día y otra en cero, el menú tiene que mostrar la peor.
    assert_select ".seccion-estado--vacio"
  end

  # ── El estado del menú es un ICONO, y son CUATRO (QA del 7 de septiembre) ──
  #
  # Daniel: *«check o icon-check verde. Si no está completado, otro ícono
  # descriptivo. Incluso si no tiene evaluación, el ícono debe indicarlo»*.
  test "cada estado del menú lleva su propio icono, no un punto de color" do
    sign_in @profesor

    # 1 · Sin ninguna evaluación todavía — el caso NORMAL de septiembre, que
    # antes no se dibujaba: `estado_de_calificacion` devolvía nil.
    get dashboards_profesor_path
    assert_select ".seccion-estado--sin_evaluaciones svg", count: 1
    assert_select ".seccion-estado[aria-label=?]", "Todavía sin evaluaciones"

    examen = con_el_colegio(@esc.colegio) do
      actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Examen")
    end

    # 2 · Con la evaluación creada y ninguna nota.
    get dashboards_profesor_path
    assert_select ".seccion-estado--vacio svg", count: 1

    # 3 · Con una de tres.
    alumnos = con_el_colegio(@esc.colegio) { Enrollment.where(section: @esc.seccion).map(&:student) }
    con_el_colegio(@esc.colegio) { nota(examen, alumnos.first, 15) }
    get dashboards_profesor_path
    assert_select ".seccion-estado--a_medias svg", count: 1

    # 4 · Con las tres.
    con_el_colegio(@esc.colegio) { alumnos.drop(1).each { |a| nota(examen, a, 15) } }
    get dashboards_profesor_path
    assert_select ".seccion-estado--completo svg", count: 1
    assert_select ".seccion-estado[aria-label=?]", "Notas al día"
  end

  # ⚠️ El sidebar tiene `overflow-y: auto`, que arrastra el eje X: un globo
  # centrado sobre un icono pegado al borde derecho se corta al ras. Se veía
  # «Notas al dí…».
  test "el tooltip del estado se ancla a la derecha para no cortarse" do
    sign_in @profesor
    get dashboards_profesor_path

    assert_select ".seccion-estado[data-tooltip-izquierda]"
  end
end
