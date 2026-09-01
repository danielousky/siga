# Escribe las notas de años anteriores (MOR-126, tanda 3).
#
# De cada fila salen hasta cuatro cosas, y todas se buscan antes de crearse:
#
#     Student         el alumno, si no estaba (pudo egresar hace tres años)
#     Enrollment      su inscripción en la sección de ESE año
#     MomentGrade     una por lapso con nota
#     FinalGradeBook  la definitiva del año en esa materia
#
# ⚠️ **Todo lo que escribe va con `origen: :importada`**, y sin eso este
# importador no sirve para nada: `GradeCalculator` borra las calificaciones que
# no tienen actividades debajo, y una nota de 2023 no las tiene ni las va a
# tener. Medido antes de existir esta clase:
#
#     nota histórica cargada:   1
#     tras UN recálculo:        0
#
# ## La definitiva del colegio manda
#
# Si la planilla trae la definitiva, esa se guarda tal cual: es la que está
# impresa en el boletín que el colegio ya entregó, y puede no coincidir con el
# promedio de los lapsos —por una reparación vieja, por un redondeo que aquel
# sistema hacía distinto, o porque no nos dieron los tres lapsos—. Si no la trae,
# se calcula del promedio de los lapsos que sí vinieron (Art. 111).
class CargaDeHistorial
  include EscribePersonas

  Resultado = Struct.new(:alumnos_creados, :alumnos_reutilizados, :inscripciones,
                         :notas_de_lapso, :definitivas, :anos_tocados, :fallidas,
                         keyword_init: true) do
    def total_cargado = notas_de_lapso + definitivas

    def to_h_para_guardar
      {
        "alumnos_creados" => alumnos_creados,
        "alumnos_reutilizados" => alumnos_reutilizados,
        "inscripciones" => inscripciones,
        "notas_de_lapso" => notas_de_lapso,
        "definitivas" => definitivas,
        "anos" => anos_tocados.to_a.sort,
        "fallidas" => fallidas
      }
    end
  end

  def initialize(historial:, colegio:)
    @historial = historial
    @colegio = colegio
    @personas = Set.new
    @resultado = Resultado.new(
      alumnos_creados: 0, alumnos_reutilizados: 0, inscripciones: 0,
      notas_de_lapso: 0, definitivas: 0, anos_tocados: Set.new, fallidas: []
    )
  end

  def ejecutar
    @historial.cargables.each { |fila| cargar(fila) }
    @resultado
  end

  private

  def cargar(fila)
    ActiveRecord::Base.transaction(requires_new: true) do
      alumno = crear_alumno(fila)
      inscripcion = inscribir(alumno, fila)

      escribir_lapsos(inscripcion, fila)
      escribir_definitiva(inscripcion, fila)

      @resultado.anos_tocados << fila.periodo.name
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    @resultado.fallidas << { "fila" => fila.numero, "alumno" => fila.etiqueta, "motivo" => e.message }
  end

  # ── el alumno ─────────────────────────────────────────────────────────────

  # Puede no estar en SIGA: un historial de 2021 trae alumnos que ya egresaron y
  # que nadie va a cargar por la matrícula. Igual son personas de la plataforma,
  # así que se buscan sin aislamiento (ver `EscribePersonas`).
  def crear_alumno(fila)
    datos = fila.alumno
    persona = persona_existente(datos[:document], datos[:cedula_escolar])

    if persona.nil?
      persona = User.new(datos)
    else
      actualizar(persona, datos, Student.unscoped.exists?(user: persona, school: @colegio))
    end
    persona.save!

    alumno = Student.find_or_initialize_by(user: persona, school: @colegio)
    creado = alumno.new_record?
    alumno.school_card ||= siguiente_carnet(fila)
    alumno.save!

    unless visto?(datos[:document] || datos[:cedula_escolar])
      creado ? @resultado.alumnos_creados += 1 : @resultado.alumnos_reutilizados += 1
    end

    alumno
  end

  # La fecha de inscripción es la del año escolar al que pertenece la nota, no la
  # de hoy: se está registrando algo que pasó en 2023.
  def inscribir(alumno, fila)
    inscripcion = Enrollment.find_or_initialize_by(student: alumno, section: fila.seccion)
    return inscripcion unless inscripcion.new_record?

    inscripcion.enrollment_date = fila.periodo.start_date || Date.current
    inscripcion.save!
    @resultado.inscripciones += 1

    inscripcion
  end

  # ── las notas ─────────────────────────────────────────────────────────────

  # ⚠️ Los lapsos se toman POR POSICIÓN, en el orden en que el colegio los tiene
  # cargados. La planilla dice «LAPSO 2» y eso es el segundo lapso del año, sea
  # como sea que ese colegio lo haya nombrado.
  def escribir_lapsos(inscripcion, fila)
    momentos = lapsos_de(fila.periodo)

    fila.lapsos.each do |numero, puntaje|
      momento = momentos[numero - 1]
      next if momento.nil?

      nota = MomentGrade.find_or_initialize_by(
        enrollment: inscripcion, subject: fila.materia, evaluation_moment: momento
      )
      nota.final_moment_score = puntaje
      nota.origen = :importada
      nota.save!

      @resultado.notas_de_lapso += 1
    end
  end

  def escribir_definitiva(inscripcion, fila)
    anual = fila.definitiva || promedio_de_lapsos(fila)
    return if anual.nil?

    libro = FinalGradeBook.find_or_initialize_by(enrollment: inscripcion, subject: fila.materia)
    libro.annual_average = anual
    libro.remedial_exam_score = fila.reparacion
    # Art. 112: la nota de la segunda oportunidad es la definitiva. `max` no puede
    # bajar una nota ya obtenida, y en la práctica da lo mismo porque a
    # reparación solo va quien está aplazado.
    libro.final_score = fila.reparacion ? [ anual, fila.reparacion ].max : anual
    libro.origen = :importada
    libro.save!

    @resultado.definitivas += 1
  end

  # Art. 111: promedio SIMPLE de los lapsos, sin ponderar, y sobre los enteros.
  def promedio_de_lapsos(fila)
    return nil if fila.lapsos.empty?

    GradeCalculator.redondear(fila.lapsos.values.sum.to_d / fila.lapsos.size)
  end

  def lapsos_de(periodo)
    @lapsos ||= {}
    @lapsos[periodo.id] ||= EvaluationMoment.where(academic_period: periodo).order(:id).to_a
  end

  # ── el carnet ─────────────────────────────────────────────────────────────

  # Un alumno que llega por el historial igual necesita carnet, y el año del que
  # viene es mejor prefijo que el de hoy: es cuando el colegio lo numeró.
  def siguiente_carnet(fila)
    # ⚠️ El prefijo sale del año de la FILA, no del vigente: cada fila de un
    # historial es de un año escolar distinto. El resto —formato y
    # consecutivo— lo pone `Student`.
    Student.siguiente_carnet(@colegio, prefijo: Student.prefijo_de_carnet(fila.periodo))
  end

  # Los conteos son de personas DISTINTAS: un alumno con diez materias es una
  # persona, no diez.
  def visto?(clave)
    ya = @personas.include?(clave)
    @personas << clave
    ya
  end
end
