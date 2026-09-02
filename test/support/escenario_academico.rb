# Arma un colegio entero para los tests: período, lapsos, grado, sección,
# materia y alumnos inscritos.
#
# Existe porque las fixtures YAML no sirven acá. Con el RLS encendido, una
# fixture se inserta sin contexto de colegio y el `WITH CHECK` la rechaza; y aun
# sin eso, la cadena que hace falta para calcular una nota —colegio → período →
# lapso → grado → sección → materia → alumno → inscripción → actividad— es
# demasiado larga para escribirla a mano en cada test.
#
# Todo lo que se crea vive dentro de una transacción de test, así que se deshace
# solo al terminar.
module EscenarioAcademico
  # ⚠️ El contador es POR PROCESO, y los tests corren en diez a la vez.
  #
  # `parallelize(workers: :number_of_processors)` forkea, así que cada worker
  # arranca su propio `@@secuencia` en 0 — y el escenario 7 del worker A y el
  # escenario 7 del worker B pedían el mismo `dea_code` y la misma cédula
  # escolar, que son índices únicos GLOBALES.
  #
  # Fallaba una corrida de cada varias, y siempre en un test distinto: el que
  # tuviera la mala suerte de que dos workers coincidieran. Se veía como
  # «Cedula escolar ya está en uso» en un test que no toca cédulas escolares.
  #
  # El PID desempata, y no hace falta que sea bonito: solo que dos procesos vivos
  # a la vez no puedan chocar.
  @@secuencia = 0

  def self.siguiente
    @@secuencia += 1

    # Cinco dígitos del PID alcanzan para no chocar y dejan el número corto:
    # `cedula_escolar` tiene su propio formato y no conviene inflarlo.
    (Process.pid % 100_000) * 1_000 + @@secuencia
  end

  Escenario = Struct.new(
    :colegio, :periodo, :lapsos, :grado, :seccion, :materia, :alumnos, :inscripciones,
    keyword_init: true
  ) do
    # El alumno n-ésimo, contando desde 1 como cuenta un profesor.
    def alumno(n = 1) = alumnos[n - 1]
    def inscripcion(n = 1) = inscripciones[n - 1]
    def lapso(n = 1) = lapsos[n - 1]
  end

  # `pesos` son los de los lapsos: [30, 30, 40] es lo habitual en Venezuela,
  # [50, 50] un colegio con dos semestres.
  #
  # `nivel` decide si el grado es de bachillerato o de primaria, y con él viene
  # la escala: en secundaria la calificación es SIEMPRE numérica, la literal es
  # de primaria (MOR-129). Un test que necesite literal pide `nivel: :primaria`
  # en vez de forzarle la escala a un grado de bachillerato.
  def escenario_academico(nombre: "U.E. de Prueba", pesos: [30, 30, 40], alumnos: 1, nivel: :secundaria)
    n = EscenarioAcademico.siguiente

    colegio = Current.sin_aislamiento do
      School.create!(name: "#{nombre} #{n}", dea_code: "TEST#{n}", location: "Caracas")
    end

    con_el_colegio(colegio) do
      periodo = AcademicPeriod.create!(
        school: colegio, name: "2025-2026", start_date: Date.new(2025, 9, 15), end_date: Date.new(2026, 7, 31)
      )

      lapsos = pesos.each_with_index.map do |peso, i|
        EvaluationMoment.create!(academic_period: periodo, name: "Lapso #{i + 1}")
      end

      departamento = Department.create!(school: colegio, name: "Ciencias #{n}")
      materia      = Subject.create!(department: departamento, code: "MAT", name: "Matemática")
      grado        = Grade.create!(school: colegio, level: nivel,
                                   name: nivel.to_sym == :primaria ? "6to Grado" : "1er Año")
      GradeSubject.create!(grade: grado, subject: materia)

      seccion = Section.create!(grade: grado, academic_period: periodo, name: "A", capacity: 30)

      registros = Array.new(alumnos) do |i|
        usuario = User.create!(
          first_name: "Alumno#{i + 1}", last_name: "Prueba", email: "alumno#{i + 1}.t#{n}@test.edu",
          password: "123123",
          # Un alumno de prueba se identifica con cédula ESCOLAR, no nacional:
          # es el caso real de primaria y ejercita la validación de MOR-138.
          #
          # ⚠️ Sin truncar. Antes era `"T#{n}#{...}"[0, 12]`, y el corte a doce
          # hacía COLISIONAR escenarios distintos: con n=100 y con n=1000 el
          # resultado era el mismo `T10000000000`. No se veía porque hacían falta
          # ~1000 escenarios en una corrida para llegar ahí — y la suite creció
          # hasta ahí. El índice de `users.cedula_escolar` es único y global.
          cedula_escolar: "T#{n.to_s.rjust(6, '0')}#{(i + 1).to_s.rjust(3, '0')}"
        )
        estudiante = Student.create!(user: usuario, school: colegio, school_card: "#{n}-#{i + 1}")
        inscripcion = Enrollment.create!(student: estudiante, section: seccion, enrollment_date: Date.new(2025, 9, 20))
        [estudiante, inscripcion]
      end

      Escenario.new(
        colegio: colegio, periodo: periodo, lapsos: lapsos, grado: grado, seccion: seccion,
        materia: materia, alumnos: registros.map(&:first), inscripciones: registros.map(&:last)
      )
    end
  end

  # Un año escolar ANTERIOR, con sus lapsos y una sección del mismo grado.
  #
  # Es lo que exige el historial (`MOR-126`, tanda 3): una nota de 2023 cuelga de
  # un lapso, el lapso del período, y la inscripción de una sección de ESE año.
  def ano_escolar_viejo(escenario, nombre: "2023-2024", lapsos: 3, seccion: "A")
    inicio = nombre[/\A(\d{4})/, 1].to_i

    con_el_colegio(escenario.colegio) do
      periodo = AcademicPeriod.create!(
        school: escenario.colegio, name: nombre,
        start_date: Date.new(inicio, 9, 15), end_date: Date.new(inicio + 1, 7, 31)
      )
      parejo = 100 / lapsos
      lapsos.times do |i|
        peso = i == lapsos - 1 ? 100 - (parejo * (lapsos - 1)) : parejo
        EvaluationMoment.create!(academic_period: periodo, name: "Lapso #{i + 1}")
      end
      Section.create!(grade: escenario.grado, academic_period: periodo, name: seccion, capacity: 30)

      periodo
    end
  end

  # Una actividad evaluativa de la sección, con su ponderación dentro del lapso.
  def actividad(esc, lapso:, peso:, descripcion: "Evaluación")
    EvaluationActivity.create!(
      section: esc.seccion, subject: esc.materia, evaluation_moment: lapso,
      description: descripcion, weight_percentage: peso, date_scheduled: Date.new(2025, 10, 1)
    )
  end

  def nota(actividad, alumno, puntaje)
    ActivityGrade.create!(evaluation_activity: actividad, student: alumno, score: puntaje)
  end

  # Cuenta filas sin depender del contexto de colegio que haya quedado puesto.
  #
  # Hace falta en los tests de integración: la petición fija `siga.school_id` con
  # `SET LOCAL` dentro de la transacción del test, así que sobrevive a la
  # petición. Un `Modelo.count` antes y otro después corren con contextos
  # distintos y la diferencia mide eso en vez de medir lo que hizo la acción.
  def cantidad(modelo)
    Current.sin_aislamiento { modelo.count }
  end

  # Pone el colegio en las DOS capas: `Current.school` para el `default_scope` y
  # la variable de sesión de Postgres para el RLS. Sin la segunda, cualquier
  # INSERT lo rechaza el `WITH CHECK`.
  def con_el_colegio(colegio)
    anterior = Current.school
    Current.school = colegio
    fijar_contexto_rls(colegio&.id)
    yield
  ensure
    Current.school = anterior
    fijar_contexto_rls(anterior&.id)
  end

  def fijar_contexto_rls(id)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(["SELECT set_config('siga.school_id', ?, true)", id.to_s])
    )
  rescue ActiveRecord::StatementInvalid
    # Si el test dejó la transacción abortada —un CHECK violado a propósito, por
    # ejemplo— no hay contexto que restaurar: se va a deshacer todo igual.
    # Reventar acá taparía el error que el test estaba probando.
    nil
  end
end
