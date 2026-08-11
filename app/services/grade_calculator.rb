class GradeCalculator
  # Calcula la nota de un momento para un estudiante en una materia/sección.
  # Promedio ponderado de activity_grades según weight_percentage de cada actividad.
  def self.calculate_moment_grade(enrollment:, subject:, evaluation_moment:)
    section = enrollment.section

    activities = EvaluationActivity.where(
      section_id: section.id,
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
      next unless grade

      weighted_sum += grade.score * activity.weight_percentage
      total_weight += activity.weight_percentage
    end

    return nil if total_weight.zero?

    score = (weighted_sum / total_weight).round(2)

    MomentGrade.find_or_initialize_by(
      enrollment_id: enrollment.id,
      subject_id: subject.id,
      evaluation_moment_id: evaluation_moment.id
    ).tap do |mg|
      mg.final_moment_score = score
      mg.save!
    end
  end

  # Calcula la nota final anual para un estudiante en una materia.
  # Promedio ponderado de moment_grades según weight de cada evaluation_moment.
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
      next unless mg

      weighted_sum += mg.final_moment_score * moment.weight
      total_weight += moment.weight
    end

    return nil if total_weight.zero?

    annual_average = (weighted_sum / total_weight).round(2)

    FinalGradeBook.find_or_initialize_by(
      enrollment_id: enrollment.id,
      subject_id: subject.id
    ).tap do |fgb|
      fgb.annual_average = annual_average
      fgb.final_score = if fgb.remedial_exam_score.present?
                          [annual_average, fgb.remedial_exam_score].max
                        else
                          annual_average
                        end
      fgb.save!
    end
  end

  # Calcula todas las notas para una inscripción (todas las materias del grado).
  def self.calculate_all_for_enrollment(enrollment)
    subjects = enrollment.section.grade.subjects

    moments = moments_for(enrollment)

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
