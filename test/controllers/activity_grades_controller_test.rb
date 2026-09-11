require "test_helper"

# La planilla de carga. Lo que se prueba: que cada nota se guarde sola, que
# "sin nota" siga siendo distinto de una nota baja, y que un profesor no pueda
# calificar a un alumno que no es suyo.
#
# Ver MOR-95.
class ActivityGradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(alumnos: 3)

    con_el_colegio(@esc.colegio) do
      @garcia   = profesor_de(@esc.materia, @esc.seccion, "garcia")
      @examen   = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")
    end
  end

  # ════════════════════════════════════════════════════════════════════════
  # Cargar
  # ════════════════════════════════════════════════════════════════════════

  test "la planilla lista a todos los inscritos de la sección" do
    sign_in @garcia

    get evaluation_activity_notas_url(@examen)

    assert_response :success
    @esc.alumnos.each { |a| assert_match a.user.apellidos, response.body }
  end

  test "una nota se guarda sola y la respuesta trae el avance" do
    sign_in @garcia

    assert_difference -> { cantidad(ActivityGrade) }, 1 do
      patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id),
            params: { score: "18" }, as: :turbo_stream
    end

    assert_response :success
    # ⚠️ Lo que llega es un Turbo Stream con lo que CAMBIÓ —la marca de la fila
    # y el contador— y nunca la lista entera: repintarla en cada tecla se
    # llevaría el foco del campo siguiente.
    marca_de(@esc.alumno(1), "guardado")
    assert_select "turbo-stream[target=?]", "progreso_de_la_planilla" do
      assert_select "template .carga-progreso-texto", "1 de 3 cargadas"
    end
    assert_select "turbo-stream", 2
  end

  # La marca que quedó al lado del campo de ese alumno.
  def marca_de(alumno, estado)
    assert_select "turbo-stream[action=replace][target=?]", "estado_#{alumno.id}" do
      assert_select "template .planilla-estado[data-estado=?]", estado
    end
  end

  test "volver a mandar la misma nota la actualiza, no la duplica" do
    sign_in @garcia

    patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "18" }, as: :turbo_stream

    assert_no_difference -> { cantidad(ActivityGrade) } do
      patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "12" }, as: :turbo_stream
    end

    assert_response :success
    con_el_colegio(@esc.colegio) do
      assert_equal 12, ActivityGrade.find_by(evaluation_activity_id: @examen.id,
                                             student_id: @esc.alumno(1).id).score.to_i
    end
  end

  # ════════════════════════════════════════════════════════════════════════
  # Sin nota NO es cero
  # ════════════════════════════════════════════════════════════════════════

  test "mandar el campo vacío BORRA la nota y devuelve al alumno a sin nota" do
    sign_in @garcia
    patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "18" }, as: :turbo_stream

    assert_difference -> { cantidad(ActivityGrade) }, -1 do
      patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "" }, as: :turbo_stream
    end

    assert_response :success
    # «—», no «0»: el alumno no tiene nota, no sacó lo mínimo.
    marca_de(@esc.alumno(1), "vacio")
    assert_select "turbo-stream[target=?]", "progreso_de_la_planilla" do
      assert_select "template .carga-progreso-texto", "0 de 3 cargadas"
    end
  end

  test "borrar una nota no deja al alumno con el promedio en cero" do
    sign_in @garcia
    patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "18" }, as: :turbo_stream
    patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: "" }, as: :turbo_stream

    con_el_colegio(@esc.colegio) do
      resultado = GradeCalculator.calculate_moment_grade(
        enrollment: @esc.inscripcion(1), subject: @esc.materia, evaluation_moment: @esc.lapso(1)
      )
      assert_nil resultado, "sin notas cargadas el alumno queda SIN nota de lapso"
    end
  end

  # ════════════════════════════════════════════════════════════════════════
  # La escala, en el servidor
  # ════════════════════════════════════════════════════════════════════════

  test "una nota fuera de 1 a 20 se rechaza y el mensaje va en español" do
    sign_in @garcia

    ["0", "21", "-3"].each do |invalida|
      assert_no_difference -> { cantidad(ActivityGrade) } do
        patch evaluation_activity_nota_url(@examen, @esc.alumno(1).id), params: { score: invalida }, as: :turbo_stream
      end

      # ⚠️ 422 y no 200: el controlador de Stimulus mira si la respuesta fue
      # un éxito para saber si el valor quedó guardado. Con un 200, el campo
      # se daría por bueno con una nota que el servidor rechazó.
      assert_response :unprocessable_entity
      marca_de(@esc.alumno(1), "rechazado")
      # ⚠️ El motivo va en la MARCA de esa fila, no en un aviso arriba: en una
      # planilla de treinta, «no se pudo guardar» sin decir a quién obliga a
      # revisarlos uno por uno.
      assert_select "turbo-stream template .planilla-estado[data-tooltip*=?]", "Nota"
    end
  end

  # ════════════════════════════════════════════════════════════════════════
  # El límite
  # ════════════════════════════════════════════════════════════════════════

  test "un profesor no puede abrir la planilla de una materia que no dicta" do
    otro = escenario_academico(nombre: "Otra")
    ajena = con_el_colegio(otro.colegio) { actividad(otro, lapso: otro.lapso(1), peso: 100) }

    sign_in @garcia
    get evaluation_activity_notas_url(ajena)

    assert_response :not_found
  end

  test "un profesor no puede ponerle nota a un alumno de otra sección" do
    otro = escenario_academico(nombre: "Otra")
    sign_in @garcia

    assert_no_difference -> { cantidad(ActivityGrade) } do
      patch evaluation_activity_nota_url(@examen, otro.alumno.id), params: { score: "20" }, as: :turbo_stream
    end

    assert_response :not_found
  end

  test "un director no carga notas: la planilla es del profesor" do
    director = con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "Dire", last_name: "Ctor",
                             email: "dir.#{@esc.colegio.id}@test.edu", password: "123123",
                        document: "V-#{"dir.#{@esc.colegio.id}@test.edu".bytes.sum}")
      Admin.create!(user: usuario, school: @esc.colegio, role: :director)
      usuario
    end

    sign_in director
    get evaluation_activity_notas_url(@examen)

    assert_redirected_to dashboards_administrador_path
    assert_match(/Solo el profesor/, flash[:alert])
  end

  private

  def profesor_de(materia, seccion, apellido)
    usuario = User.create!(first_name: "Prof", last_name: apellido.capitalize,
                           email: "#{apellido}.#{seccion.id}@test.edu", password: "123123",
                        document: "V-#{"#{apellido}.#{seccion.id}@test.edu".bytes.sum}")
    docente = Teacher.create!(user: usuario, school: @esc.colegio)
    TeacherSection.create!(teacher: docente, section: seccion, subject: materia)
    usuario
  end
end
