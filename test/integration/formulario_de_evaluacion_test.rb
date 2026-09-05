require "test_helper"

# El formulario de una evaluación (MOR-223).
class FormularioDeEvaluacionTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
  end

  # ⚠️ Cada sección UNA vez. Un colegio que ya copió su estructura al año
  # siguiente tiene las mismas secciones en los dos, y el desplegable las
  # mostraba todas: treinta y dos renglones donde había dieciséis asignaciones.
  #
  # Daniel lo vio como «1er Año – A · Matemática» arriba de «1er Año – A ·
  # Matemática». Y no era solo feo: el segundo renglón crea la evaluación en el
  # año que viene, sin que nada lo diga.
  test "el desplegable no repite la sección del año siguiente" do
    con_el_colegio(@a.colegio) do
      que_viene = AcademicPeriod.create!(name: "2026-2027", start_date: Date.new(2026, 9, 15),
                                         end_date: Date.new(2027, 7, 31))
      copia = Section.create!(grade: @a.grado, academic_period: que_viene,
                              name: @a.seccion.name, capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: copia,
                             subject: @a.escenario.materia)
    end

    sign_in @a.profesor
    get new_evaluation_activity_path

    assert_response :success
    opciones = css_select("#evaluation_activity_asignacion option").map { |o| o.text.strip }
                 .reject(&:empty?)
    assert_equal opciones.uniq, opciones,
                 "cada sección tiene que aparecer UNA vez: la del año que viene no es otra opción"
  end

  # ── Dos selects: área primero, sección después (MOR-223) ──────────────────
  #
  # Daniel: *«esto lo separamos en 2 selects: si el profe solo da una materia
  # pues vamos directo, pero si dicta más de una, le colocamos el select
  # previo»*.

  test "con una sola área NO aparece el primer select" do
    sign_in @a.profesor
    get new_evaluation_activity_path

    # Un desplegable de una opción es un control que no decide nada.
    assert_select "select#evaluation_activity_area", count: 0
    # Pero el área viaja igual: `asignacion` la necesita para armarse.
    assert_select "input[name='evaluation_activity[area]']", 1
  end

  test "con dos áreas aparece, y la sección solo trae las de esa área" do
    otra = con_el_colegio(@a.colegio) do
      s = Subject.create!(department: @a.escenario.materia.department,
                          code: "LEN", name: "Castellano y Literatura")
      GradeSubject.create!(grade: @a.grado, subject: s)
      # En OTRA sección, para que se note el filtro.
      seccion = Section.create!(grade: @a.grado, academic_period: @a.escenario.periodo,
                                name: "Z", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion, subject: s)
      s
    end

    sign_in @a.profesor
    get new_evaluation_activity_path

    assert_select "select#evaluation_activity_area option", 2
    # La primera área por nombre es «Castellano y Literatura», y su única
    # sección es la Z: la del área de Matemática no puede estar en la lista.
    secciones = css_select("#evaluation_activity_asignacion option[value!='']").map { |o| o.text.strip }
    assert_equal 1, secciones.size,
                 "el segundo select trae SOLO las secciones del área elegida"
    assert_match(/Z/, secciones.first)
    assert_equal "Castellano y Literatura", otra.name
  end

  # ⚠️ El mapa de secciones por área viaja EMBEBIDO, igual que la ponderación y
  # el plan de competencias: la elección ocurre en esta pantalla, así que
  # pedirle al servidor la lista en cada cambio sería un viaje para no cambiar
  # de tema.
  test "las secciones de cada área viajan en el formulario" do
    con_el_colegio(@a.colegio) do
      s = Subject.create!(department: @a.escenario.materia.department, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @a.grado, subject: s)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: @a.seccion, subject: s)
    end
    sign_in @a.profesor
    get new_evaluation_activity_path

    assert_select "form[data-area-secciones-value]" do |formularios|
      mapa = JSON.parse(formularios.first["data-area-secciones-value"])
      assert_equal 2, mapa.keys.size, "una entrada por área que dicta"
    end
  end
end
