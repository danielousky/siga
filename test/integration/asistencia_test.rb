require "test_helper"

# La toma de asistencia (MOR-111).
#
# El criterio del issue es de tiempo —"menos de un minuto para treinta"— y eso
# no se prueba con un test. Lo que sí se prueba es lo que hace posible ese
# tiempo, y lo que pasa cuando el día sale mal:
#
#   · que no marcar a nadie signifique "todos presentes"
#   · que volver a entrar corrija en vez de duplicar
#   · que un colegio no alcance la sección de otro
class AsistenciaTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    # La asistencia la toma el profesor GUÍA del grado, y el escenario no asigna
    # ninguno: se arma acá para dejar visible de qué depende el permiso.
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: @a.registro_de_profesor) }
    con_el_colegio(@b.colegio) { @b.seccion.update!(leader_teacher: @b.registro_de_profesor) }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Todos presentes por defecto
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Es la decisión que hace que la pantalla entre en un minuto: la mayoría de los
  # días faltan dos o tres de treinta. Marcar 27 presencias para registrar 3
  # ausencias es exactamente lo que hace que nadie tome asistencia.

  test "no marcar a nadie registra a todos como presentes" do
    sign_in @a.profesor

    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :success
    con_el_colegio(@a.colegio) do
      assert_equal 2, Attendance.del_dia(Date.current).count
      assert Attendance.del_dia(Date.current).all?(&:presente?)
    end
  end

  test "solo se marcan las excepciones" do
    sign_in @a.profesor
    ausente = @a.inscripcion

    post seccion_asistencia_path(@a.seccion),
         params: { dia: Date.current.to_s, estados: { ausente.id.to_s => "ausente" } }, as: :json

    assert_response :success
    con_el_colegio(@a.colegio) do
      assert Attendance.find_by(enrollment_id: ausente.id, date: Date.current).ausente?
      # El resto quedó presente sin haberlo tocado.
      otros = Attendance.del_dia(Date.current).where.not(enrollment_id: ausente.id)
      assert otros.any? && otros.all?(&:presente?)
    end
  end

  test "los tres estados se registran" do
    sign_in @a.profesor
    inscripciones = con_el_colegio(@a.colegio) { @a.seccion.enrollments.order(:id).to_a }

    post seccion_asistencia_path(@a.seccion),
         params: { dia: Date.current.to_s,
                   estados: { inscripciones.first.id.to_s => "tarde",
                              inscripciones.last.id.to_s  => "ausente" } }, as: :json

    assert_response :success
    con_el_colegio(@a.colegio) do
      assert Attendance.find_by(enrollment_id: inscripciones.first.id).tarde?
      assert Attendance.find_by(enrollment_id: inscripciones.last.id).ausente?
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Volver a entrar corrige, no duplica
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Abrir la pantalla dos veces es lo más normal del mundo —el profesor se
  # equivocó, o el alumno llegó tarde y hay que corregirlo—. Sin el índice único
  # cada apertura crea un día nuevo y los reportes de inasistencia cuentan mal.

  test "tomar la asistencia dos veces corrige en vez de duplicar" do
    sign_in @a.profesor
    ausente = @a.inscripcion

    post seccion_asistencia_path(@a.seccion),
         params: { dia: Date.current.to_s, estados: { ausente.id.to_s => "ausente" } }, as: :json
    post seccion_asistencia_path(@a.seccion),
         params: { dia: Date.current.to_s, estados: { ausente.id.to_s => "presente" } }, as: :json

    con_el_colegio(@a.colegio) do
      assert_equal 1, Attendance.where(enrollment_id: ausente.id, date: Date.current).count,
                   "el índice único tiene que impedir dos filas del mismo día"
      assert Attendance.find_by(enrollment_id: ausente.id, date: Date.current).presente?
    end
  end

  test "la base rechaza dos asistencias del mismo alumno el mismo día" do
    con_el_colegio(@a.colegio) do
      Attendance.create!(enrollment: @a.inscripcion, date: Date.current, status: :presente)
      repetida = Attendance.new(enrollment: @a.inscripcion, date: Date.current, status: :ausente)

      assert_not repetida.valid?
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El futuro no se toma
  # ══════════════════════════════════════════════════════════════════════════
  #
  # No es un error de dedo inofensivo: deja el día cerrado antes de que ocurra, y
  # el profesor que entre mañana ve la sección "ya tomada" y sigue de largo.

  test "no se puede tomar asistencia de un día que no llegó" do
    sign_in @a.profesor

    post seccion_asistencia_path(@a.seccion),
         params: { dia: (Date.current + 1).to_s }, as: :json

    assert_response :unprocessable_entity
    con_el_colegio(@a.colegio) { assert_equal 0, Attendance.count }
  end

  test "el modelo también lo rechaza, no solo el controller" do
    con_el_colegio(@a.colegio) do
      futura = Attendance.new(enrollment: @a.inscripcion, date: Date.current + 1, status: :presente)

      assert_not futura.valid?
      assert_includes futura.errors[:date].to_sentence, "no llegó"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El aislamiento, que una pantalla nueva no puede aflojar
  # ══════════════════════════════════════════════════════════════════════════

  # 404 y no 403: un 403 confirmaría que esa sección existe.
  test "un profesor no toma asistencia de la sección de otro colegio" do
    sign_in @a.profesor

    post seccion_asistencia_path(@b.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :not_found
    con_el_colegio(@b.colegio) { assert_equal 0, Attendance.count }
  end

  test "la asistencia de un colegio no se ve desde el otro" do
    con_el_colegio(@b.colegio) do
      Attendance.create!(enrollment: @b.inscripcion, date: Date.current, status: :ausente)
    end

    con_el_colegio(@a.colegio) do
      assert_equal 0, Attendance.count, "el default_scope tiene que filtrar la asistencia ajena"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién puede tomarla
  # ══════════════════════════════════════════════════════════════════════════

  test "el profesor guía ve su sección" do
    sign_in @a.profesor

    get asistencias_path

    # Con una sola sección a cargo entra directo: un paso menos.
    assert_redirected_to seccion_asistencia_path(@a.seccion, dia: Date.current)
  end

  # ⚠️ El test que faltaba, y por eso el error vivió meses (MOR-209).
  #
  # Con UNA sección por grado, «guía del grado» y «guía de la sección» se
  # comportan igual: ningún test los distingue y el escenario de prueba tenía
  # justamente una. La diferencia aparece cuando el grado tiene A y B con guías
  # distintos —el caso normal de un colegio— y ahí el modelo viejo hacía dos
  # cosas mal a la vez: le mostraba a un profesor alumnos que no son suyos, y le
  # escondía al otro los propios.
  test "cada guía ve su sección, no todas las del grado" do
    seccion_b, profesor_b = con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "Guía", last_name: "DeLaB",
                             email: "guia.b@aislamiento.test", password: "123123",
                             document: "V-98765432", document_type: :cedula_v)
      registro = Teacher.create!(user: persona, school: @a.colegio)
      seccion = Section.create!(grade: @a.grado, academic_period: @a.seccion.academic_period,
                                name: "B", capacity: 30, leader_teacher: registro)
      [ seccion, persona ]
    end

    sign_in profesor_b
    get asistencias_path
    assert_redirected_to seccion_asistencia_path(seccion_b, dia: Date.current),
                         "el guía de B tiene que entrar a B, no a la primera del grado"

    sign_out profesor_b
    sign_in @a.profesor
    get asistencias_path
    assert_redirected_to seccion_asistencia_path(@a.seccion, dia: Date.current),
                         "el guía de A ve las DOS secciones del grado: el guía volvió a " \
                         "colgar del grado en vez de la sección"
  end

  # El coordinador del grado NO pasa lista: coordina a los guías, que es otra
  # cosa. Es la mitad que quedaría suelta si alguien «arregla» esto volviendo a
  # mirar el grado.
  test "el coordinador de un grado no toma la asistencia de sus secciones" do
    con_el_colegio(@a.colegio) do
      @a.seccion.update!(leader_teacher: nil)
      @a.grado.update!(coordinator_teacher: @a.registro_de_profesor)
    end
    sign_in @a.profesor

    get asistencias_path

    assert_response :success
    assert_match(/Sin secciones a cargo/, response.body)
  end

  test "un profesor que no es guía de ninguna sección no ve secciones" do
    con_el_colegio(@a.colegio) { @a.seccion.update!(leader_teacher: nil) }
    sign_in @a.profesor

    get asistencias_path

    assert_response :success
    assert_match(/Sin secciones a cargo/, response.body)
  end

  # El día que el guía falta, alguien tiene que poder tomarla igual.
  test "la dirección puede tomar la asistencia de cualquier sección" do
    sign_in @a.director

    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :success
  end

  test "un estudiante no alcanza la pantalla de toma" do
    sign_in @a.estudiante

    get asistencias_path

    assert_redirected_to dashboards_estudiante_path
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La justificación llega después, y de otra persona
  # ══════════════════════════════════════════════════════════════════════════

  test "una falta cuenta como inasistencia hasta que alguien traiga el papel" do
    con_el_colegio(@a.colegio) do
      falta = Attendance.create!(enrollment: @a.inscripcion, date: Date.current, status: :ausente)

      assert falta.cuenta_como_inasistencia?
      assert_not falta.justificada?

      falta.update!(justificacion: "Cita médica", justificada_en: Time.current,
                    justificada_por: @a.director)

      assert falta.justificada?
      assert_not falta.cuenta_como_inasistencia?
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El reporte, que es para lo que sirve todo lo anterior
  # ══════════════════════════════════════════════════════════════════════════

  test "el reporte no cuenta las faltas ya justificadas" do
    con_el_colegio(@a.colegio) do
      justificada = Attendance.create!(enrollment: @a.inscripcion, date: Date.current - 1,
                                       status: :ausente)
      justificada.update!(justificacion: "Reposo", justificada_en: Time.current,
                          justificada_por: @a.director)
    end
    sign_in @a.director

    get reporte_asistencia_path

    assert_response :success
    assert_no_match(/#{Regexp.escape(@a.alumno.user.last_name)}/, response.body,
                    "un alumno con la falta justificada no puede figurar como caso a revisar")
  end

  # El que llega tarde cinco veces y no falta nunca es justo el que el colegio
  # quiere ver ANTES de que se convierta en el otro. Filtrando solo por
  # ausencias era invisible.
  test "el reporte también muestra a quien solo llega tarde" do
    con_el_colegio(@a.colegio) do
      3.times { |i| Attendance.create!(enrollment: @a.inscripcion, date: Date.current - i, status: :tarde) }
    end
    sign_in @a.director

    get reporte_asistencia_path

    assert_response :success
    assert_match(/#{Regexp.escape(@a.alumno.user.apellidos)}/, response.body)
  end

  test "el historial de un alumno resume sus días" do
    con_el_colegio(@a.colegio) do
      Attendance.create!(enrollment: @a.inscripcion, date: Date.current,     status: :presente)
      Attendance.create!(enrollment: @a.inscripcion, date: Date.current - 1, status: :ausente)
    end
    sign_in @a.director

    get historial_asistencia_path(@a.inscripcion)

    assert_response :success
    assert_match(/Sin justificar/, response.body)
  end

  test "una tardanza no es una inasistencia" do
    con_el_colegio(@a.colegio) do
      tarde = Attendance.create!(enrollment: @a.inscripcion, date: Date.current, status: :tarde)

      assert_not tarde.cuenta_como_inasistencia?
    end
  end
end
