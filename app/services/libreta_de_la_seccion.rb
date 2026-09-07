# Todas las notas de una sección en UNA tabla (MOR-223).
#
# ## Lo que pidió Daniel
#
# > *«Está bien que califique particularmente cada evaluación, pero debería
# > tener una vista en la que aparezcan todas las evaluaciones y él pueda ir
# > ajustando durante el lapso… una tabla donde la primera columna es la lista
# > de los estudiantes y las siguientes columnas son las evaluaciones. Eso está
# > dentro de un panel por cada lapso.»*
#
# Y la razón, en una frase suya: *«ten presente que lo más importante para los
# profesores son sus estudiantes»*.
#
# Hoy el profesor carga notas **una evaluación a la vez**, y para saber cómo va
# un alumno tiene que abrir tres planillas y recordar. Esta es la misma
# información girada noventa grados:
#
#     LA PLANILLA (existe)          LA LIBRETA (esto)
#     ────────────────────          ─────────────────
#     una evaluación                un lapso entero
#     todos los alumnos             alumno × evaluación
#     para CARGAR                   para MIRAR y ajustar
#
# ## ⚠️ Es del ÁREA que dicta el profesor, no de la sección entera
#
# Daniel lo ratificó con Cyndi: *«califica el profe de la materia. Incluso el
# guía, al final, deben asignársele las áreas… ¿cómo sabes cuáles califica? Ese
# comportamiento es igual que en la educación media: guía + áreas asignadas»*.
#
# O sea que la pregunta «¿qué califica esta persona?» ya tiene respuesta en el
# modelo y no hay que inventarla: sus `teacher_sections`. El guía de 4to Grado
# que dicta cuatro de las seis áreas ve cuatro columnas, no seis.
#
# La DIRECCIÓN ve todas — no califica, supervisa.
class LibretaDeLaSeccion
  # Una fila: el alumno, su nota en cada evaluación, y su promedio del lapso.
  Fila = Data.define(:inscripcion, :notas, :promedio) do
    def alumno = inscripcion.student

    # Cuántas le faltan, que es lo que el profesor está buscando.
    def sin_nota = notas.count { |_, valor| valor.nil? }
  end

  # Una columna: la evaluación, con su peso, cuánto lleva cargado y QUÉ MIDE.
  Columna = Data.define(:evaluacion, :puestas, :total, :competencias) do
    def completa? = total.positive? && puestas >= total
    def vacia?    = puestas.zero?
    def faltan    = total - puestas

    # ⚠️ El estado en TRES niveles, que es lo que Daniel pidió ver de un
    # vistazo: *«si ya las tengo calificadas me aparece 20 de 20 y un check en
    # verde; si me falta por calificar me aparece 20 de 30 y en amarillo; si no
    # tengo nada calificado me aparece en rojo»*.
    def estado
      return :completa if completa?
      return :vacia    if vacia?

      :a_medias
    end
  end

  def self.para(seccion:, materia:, lapso:)
    new(seccion, materia, lapso).armar
  end

  def initialize(seccion, materia, lapso)
    @seccion = seccion
    @materia = materia
    @lapso   = lapso
  end

  def armar
    { columnas: columnas, filas: filas }
  end

  private

  def columnas
    @columnas ||= begin
      total = inscripciones.size

      evaluaciones.map do |evaluacion|
        Columna.new(evaluacion: evaluacion, puestas: notas_por_evaluacion[evaluacion.id].to_i,
                    total: total, competencias: evaluacion.competencies.to_a)
      end
    end
  end

  def filas
    inscripciones.map do |inscripcion|
      notas = evaluaciones.to_h do |evaluacion|
        [ evaluacion.id, notas_por_alumno.dig(inscripcion.student_id, evaluacion.id) ]
      end

      Fila.new(inscripcion: inscripcion, notas: notas, promedio: promedios[inscripcion.id])
    end
  end

  def evaluaciones
    # ⚠️ `includes(:competencies)` y no una consulta por columna: en una
    # libreta de cinco evaluaciones eso serían cinco viajes más, y esta pantalla
    # la abre un profesor desde el teléfono.
    @evaluaciones ||= EvaluationActivity
                      .where(section_id: @seccion.id, subject_id: @materia.id,
                             evaluation_moment_id: @lapso.id)
                      .includes(:competencies)
                      .order(:date_scheduled, :id)
                      .to_a
  end

  # ⚠️ Solo los REGULARES. Un alumno retirado no tiene que calificarse, y
  # contarlo dejaría la evaluación en «29 de 30» para siempre.
  def inscripciones
    @inscripciones ||= Enrollment.where(section_id: @seccion.id, status: :regular)
                                 .includes(student: :user)
                                 .to_a
                                 .sort_by { |i| i.student.user.apellidos_y_nombres }
  end

  # ⚠️ UNA consulta para todas las notas, no una por celda. Una sección de
  # treinta alumnos con cinco evaluaciones son ciento cincuenta celdas, y este
  # panel lo abre un profesor desde el teléfono.
  def notas_por_alumno
    @notas_por_alumno ||= ActivityGrade
                          .where(evaluation_activity_id: evaluaciones.map(&:id))
                          .pluck(:student_id, :evaluation_activity_id, :score)
                          .each_with_object({}) do |(alumno, evaluacion, nota), mapa|
                            (mapa[alumno] ||= {})[evaluacion] = nota
                          end
  end

  def notas_por_evaluacion
    @notas_por_evaluacion ||= ActivityGrade
                              .where(evaluation_activity_id: evaluaciones.map(&:id))
                              .group(:evaluation_activity_id).count
  end

  # ⚠️ El promedio sale de `moment_grades`, NO se recalcula acá.
  #
  # Es el que ya calculó `GradeCalculator` con las reglas del Art. 111 —el 70/30
  # y los pesos de cada evaluación—. Recalcularlo en la vista sería una segunda
  # aritmética que se separa de la primera, y la primera es la que sale impresa
  # en el boletín.
  def promedios
    @promedios ||= MomentGrade
                   .where(enrollment_id: inscripciones.map(&:id),
                          subject_id: @materia.id, evaluation_moment_id: @lapso.id)
                   .pluck(:enrollment_id, :final_moment_score).to_h
  end
end
