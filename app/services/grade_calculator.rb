# Las notas oficiales de un alumno: la de cada lapso y la definitiva del año.
#
# ## La norma manda, no Ruby
#
# Reglamento General de la Ley Orgánica de Educación, **Artículo 108**:
#
# > La expresión cuantitativa de la calificación obtenida por el alumno de la
# > tercera etapa de educación básica y en el nivel de educación media
# > diversificada y profesional, se expresará mediante **un número entero**
# > comprendido en la escala del uno (1) al veinte (20), ambos inclusive. En todo
# > caso la calificación mínima aprobatoria de cada asignatura o similar será de
# > diez (10) puntos.
# >
# > Cuando al efectuar los cómputos se obtuvieren fracciones decimales de
# > **cincuenta centésimas (0,50) o más se adoptará el número inmediato superior**.
#
# Y **Artículo 111**: "La calificación definitiva para el área, asignatura o
# similar, se obtendrá del promedio de las calificaciones alcanzadas en los tres
# lapsos." Las calificaciones de los lapsos ya son enteras por el 108, así que el
# promedio anual se calcula sobre los ENTEROS, no sobre los decimales crudos.
#
# El orden importa y no es un detalle contable:
#
#   lapsos 9,5 · 9,5 · 9,4
#     promediando los decimales   → 9,47 → 9   ✗ el alumno repite
#     promediando los enteros     → 10 · 10 · 9 = 9,67 → 10   ✓ el alumno aprueba
#
# ## Lo que este servicio NO decide
#
# La ponderación entre lapsos sale de `evaluation_moments.weight`, no de acá. El
# 111 describe un promedio simple de tres lapsos; el sistema permite pesos porque
# muchos colegios usan 30/30/40 y algunos años se dividen en dos semestres
# (MOR-83). Con pesos iguales el resultado es exactamente el del Reglamento: el
# promedio ponderado lo generaliza, no lo contradice.
class GradeCalculator
  # Artículo 108: media hacia arriba, que no es lo que hace el redondeo bancario.
  # 9,50 → 10. Esa décima es la diferencia entre repetir y aprobar el año.
  def self.redondear(valor)
    return nil if valor.nil?

    valor.to_d.round(0, :half_up).to_i
  end

  # La calificación de un lapso: promedio ponderado de las actividades del lapso
  # según su `weight_percentage`.
  #
  # Devuelve `nil` —y no escribe nada— cuando no hay con qué calcular. Un alumno
  # al que todavía no le cargaron ninguna nota queda SIN nota, nunca con cero:
  # confundir las dos cosas reprueba a la sección entera a mitad de lapso.
  def self.calculate_moment_grade(enrollment:, subject:, evaluation_moment:)
    activities = EvaluationActivity.where(
      section_id: enrollment.section_id,
      subject_id: subject.id,
      evaluation_moment_id: evaluation_moment.id
    )

    return nil if activities.empty?

    total_weight = 0
    weighted_sum = 0

    activities.each do |activity|
      grade = ActivityGrade.find_by(
        evaluation_activity_id: activity.id,
        student_id: enrollment.student_id
      )
      # Una actividad sin nota no cuenta como cero: se saca del promedio, junto
      # con su peso. Mientras el lapso está abierto eso da "cómo va hasta ahora";
      # al cerrarlo, el profesor tiene que haber cargado todo.
      next unless grade

      weighted_sum += grade.score * activity.weight_percentage
      total_weight += activity.weight_percentage
    end

    return nil if total_weight.zero?

    # Se divide por el peso REALMENTE cargado, no por 100. Si el profesor definió
    # actividades por el 80 %, el promedio es sobre ese 80 % y no castiga al
    # alumno por lo que todavía no existe.
    score = redondear(weighted_sum / total_weight)

    MomentGrade.find_or_initialize_by(
      enrollment_id: enrollment.id,
      subject_id: subject.id,
      evaluation_moment_id: evaluation_moment.id
    ).tap do |mg|
      mg.final_moment_score = score
      mg.save!
    end
  end

  # La calificación definitiva del año: promedio ponderado de las calificaciones
  # de los lapsos (que ya son enteras, Art. 108 + 111).
  def self.calculate_final_grade(enrollment:, subject:)
    # Solo los momentos del período de ESTA inscripción. Antes decía
    # `EvaluationMoment.all`, que con los momentos compartidos daba lo mismo —
    # pero desde que cuelgan del período eso traería también los lapsos de otros
    # colegios y otros años, y el promedio anual se calcularía sobre una base
    # que no es la del alumno.
    moments = moments_for(enrollment)
    return nil if moments.empty?

    total_weight = 0
    weighted_sum = 0

    moments.each do |moment|
      mg = MomentGrade.find_by(
        enrollment_id: enrollment.id,
        subject_id: subject.id,
        evaluation_moment_id: moment.id
      )
      # Un lapso sin calificar tampoco cuenta como cero. En noviembre, con un
      # solo lapso cerrado, el "anual" es el de ese lapso — no un tercio de él.
      next unless mg

      weighted_sum += mg.final_moment_score * moment.weight
      total_weight += moment.weight
    end

    return nil if total_weight.zero?

    annual_average = redondear(weighted_sum / total_weight)

    FinalGradeBook.find_or_initialize_by(
      enrollment_id: enrollment.id,
      subject_id: subject.id
    ).tap do |fgb|
      fgb.annual_average = annual_average

      # La reparación solo se presenta estando aplazado, así que en la práctica
      # `max` y "la nota de la segunda oportunidad es la definitiva" (Art. 112)
      # dan el mismo resultado: si aprobó la reparación es la mayor, y si no,
      # las dos están por debajo de 10. `max` además no puede bajar una nota ya
      # obtenida.
      fgb.final_score = if fgb.remedial_exam_score.present?
                          [annual_average, redondear(fgb.remedial_exam_score)].max
                        else
                          annual_average
                        end
      fgb.save!
    end
  end

  # Calcula todas las notas para una inscripción (todas las materias del grado).
  def self.calculate_all_for_enrollment(enrollment)
    subjects = enrollment.section.grade.subjects
    moments  = moments_for(enrollment)

    subjects.map do |subject|
      moments.each do |moment|
        calculate_moment_grade(enrollment: enrollment, subject: subject, evaluation_moment: moment)
      end

      calculate_final_grade(enrollment: enrollment, subject: subject)
    end.compact
  end

  # Los momentos de evaluación del período en el que está inscrito el alumno.
  # Es el único conjunto sobre el que tiene sentido promediarle el año.
  def self.moments_for(enrollment)
    EvaluationMoment.where(academic_period_id: enrollment.section.academic_period_id)
  end
  private_class_method :moments_for

  # Calcula todas las notas de una sección completa.
  def self.calculate_all_for_section(section)
    section.enrollments.each do |enrollment|
      calculate_all_for_enrollment(enrollment)
    end
  end
end
