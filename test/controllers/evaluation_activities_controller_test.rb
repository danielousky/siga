require "test_helper"

# Lo que se prueba acá no es el CRUD —eso lo sostiene Rails— sino el LÍMITE:
# dos profesores del mismo colegio no se ven las evaluaciones, y ninguno puede
# tocar las del otro pasando un id a mano.
#
# Ver MOR-94.
class EvaluationActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(alumnos: 2)

    con_el_colegio(@esc.colegio) do
      # Dos profesores del MISMO colegio. Garcia dicta Matemática en la sección;
      # Torres dicta Castellano en la misma sección.
      @garcia = profesor("garcia", @esc.materia, @esc.seccion)

      departamento = Department.create!(school: @esc.colegio, name: "Lengua")
      @castellano  = Subject.create!(department: departamento, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @esc.grado, subject: @castellano)
      @torres = profesor("torres", @castellano, @esc.seccion)

      @de_garcia = actividad(@esc, lapso: @esc.lapso(1), peso: 40, descripcion: "Examen de Matemática")
      @de_torres = EvaluationActivity.create!(
        section: @esc.seccion, subject: @castellano, evaluation_moment: @esc.lapso(1),
        description: "Ensayo de Castellano", weight_percentage: 50, date_scheduled: Date.new(2025, 10, 1)
      )
    end
  end

  # ════════════════════════════════════════════════════════════════════════
  # El límite
  # ════════════════════════════════════════════════════════════════════════

  test "un profesor lista solo las evaluaciones de las materias que dicta" do
    entrar_como @garcia

    get evaluation_activities_url

    assert_response :success
    assert_match "Examen de Matemática", response.body
    assert_no_match(/Ensayo de Castellano/, response.body)
  end

  test "un profesor no puede ver la evaluación de otro ni pidiéndola por id" do
    entrar_como @garcia

    get evaluation_activity_url(@de_torres)

    # 404 y no 403: pedir un id ajeno ni siquiera confirma que exista.
    assert_response :not_found
  end

  test "un profesor no puede editar la evaluación de otro" do
    entrar_como @garcia

    patch evaluation_activity_url(@de_torres), params: { evaluation_activity: { weight_percentage: 90 } }

    assert_response :not_found
    assert_equal 50, con_el_colegio(@esc.colegio) { @de_torres.reload.weight_percentage }
  end

  test "un profesor no puede crear una evaluación en la sección de otro" do
    otro = escenario_academico(nombre: "Colegio Ajeno")
    entrar_como @garcia

    assert_no_difference -> { cantidad(EvaluationActivity) } do
      post evaluation_activities_url, params: { evaluation_activity: {
        asignacion: "#{otro.seccion.id}:#{otro.materia.id}",
        evaluation_moment_id: otro.lapso(1).id,
        description: "Colada", weight_percentage: 10, date_scheduled: Date.new(2025, 10, 1)
      } }
    end

    assert_response :unprocessable_entity
    assert_match "Elegí una de tus secciones", response.body
  end

  # ════════════════════════════════════════════════════════════════════════
  # El trabajo del profesor
  # ════════════════════════════════════════════════════════════════════════

  test "un profesor crea una evaluación en su sección" do
    entrar_como @garcia

    assert_difference -> { cantidad(EvaluationActivity) }, 1 do
      post evaluation_activities_url, params: { evaluation_activity: {
        asignacion: "#{@esc.seccion.id}:#{@esc.materia.id}",
        evaluation_moment_id: @esc.lapso(1).id,
        description: "Taller", weight_percentage: 30, date_scheduled: Date.new(2025, 10, 15)
      } }
    end

    creada = EvaluationActivity.unscoped.order(:id).last
    assert_equal "Taller", creada.description
    assert_equal @esc.colegio.id, creada.school_id
    assert_redirected_to evaluation_activity_url(creada)
  end

  test "pasarse de 100 % se rechaza diciendo cuánto queda" do
    entrar_como @garcia

    assert_no_difference -> { cantidad(EvaluationActivity) } do
      post evaluation_activities_url, params: { evaluation_activity: {
        asignacion: "#{@esc.seccion.id}:#{@esc.materia.id}",
        evaluation_moment_id: @esc.lapso(1).id,
        description: "Se pasa", weight_percentage: 70, date_scheduled: Date.new(2025, 10, 15)
      } }
    end

    assert_response :unprocessable_entity
    # Ya hay 40 % comprometido: quedan 60.
    assert_match(/quedan 60 % disponibles/, response.body)
  end

  test "una evaluación no puede colgar del lapso de otro año escolar" do
    entrar_como @garcia

    otro_ano = con_el_colegio(@esc.colegio) do
      periodo = AcademicPeriod.create!(
        school: @esc.colegio, name: "2026-2027",
        start_date: Date.new(2026, 9, 1), end_date: Date.new(2027, 7, 31)
      )
      EvaluationMoment.create!(academic_period: periodo, name: "Primer Semestre", weight: 50)
    end

    assert_no_difference -> { cantidad(EvaluationActivity) } do
      post evaluation_activities_url, params: { evaluation_activity: {
        asignacion: "#{@esc.seccion.id}:#{@esc.materia.id}",
        evaluation_moment_id: otro_ano.id,
        description: "Del año que viene", weight_percentage: 10, date_scheduled: Date.new(2026, 10, 1)
      } }
    end

    assert_response :unprocessable_entity
    assert_match(/no pertenece al año escolar de la sección/, response.body)
  end

  # ════════════════════════════════════════════════════════════════════════
  # El borrado, que es lo que puede costar datos
  # ════════════════════════════════════════════════════════════════════════

  test "una evaluación sin notas se elimina" do
    entrar_como @garcia

    assert_difference -> { cantidad(EvaluationActivity) }, -1 do
      delete evaluation_activity_url(@de_garcia)
    end
    assert_redirected_to evaluation_activities_url
  end

  test "una evaluación CON notas no se elimina, y el mensaje lo dice en español" do
    con_el_colegio(@esc.colegio) { nota(@de_garcia, @esc.alumno, 15) }
    entrar_como @garcia

    assert_no_difference -> { cantidad(EvaluationActivity) } do
      delete evaluation_activity_url(@de_garcia)
    end

    assert_redirected_to evaluation_activity_url(@de_garcia)
    assert_match(/no se puede eliminar mientras tenga/i, flash[:alert])
    assert_no_match(/Cannot delete/, flash[:alert])
  end

  # ════════════════════════════════════════════════════════════════════════
  # La dirección mira, no edita
  # ════════════════════════════════════════════════════════════════════════

  test "el director ve las evaluaciones de TODO el colegio" do
    entrar_como director

    get evaluation_activities_url

    assert_response :success
    assert_match "Examen de Matemática", response.body
    assert_match "Ensayo de Castellano", response.body
  end

  test "el director no puede crear ni editar la ponderación de un profesor" do
    entrar_como director

    get new_evaluation_activity_url
    assert_redirected_to evaluation_activities_url
    assert_match(/la define el profesor/i, flash[:alert])

    patch evaluation_activity_url(@de_garcia), params: { evaluation_activity: { weight_percentage: 90 } }
    assert_equal 40, con_el_colegio(@esc.colegio) { @de_garcia.reload.weight_percentage }
  end

  test "un estudiante no entra" do
    entrar_como estudiante

    get evaluation_activities_url
    assert_redirected_to dashboards_estudiante_path
  end

  private

  def profesor(apellido, materia, seccion)
    usuario = User.create!(
      name: "Prof", last_name: apellido.capitalize,
      email: "#{apellido}.#{seccion.id}@test.edu", password: "123123"
    )
    docente = Teacher.create!(user: usuario, school: @esc.colegio)
    TeacherSection.create!(teacher: docente, section: seccion, subject: materia)
    usuario
  end

  def director
    @director ||= con_el_colegio(@esc.colegio) do
      usuario = User.create!(
        name: "Dire", last_name: "Ctor", email: "director.#{@esc.colegio.id}@test.edu", password: "123123"
      )
      Admin.create!(user: usuario, school: @esc.colegio, role: :director)
      usuario
    end
  end

  def estudiante
    @esc.alumno.user
  end

  def entrar_como(usuario)
    sign_in usuario
  end
end
