class Dashboards::ProfesorController < ApplicationController
  before_action :require_profesor!

  def index
    @teacher = current_user.teacher

    # Secciones asignadas con toda la información necesaria
    @teacher_sections = @teacher.teacher_sections
                                .includes(section: [:grade, :academic_period, :enrollments])
                                .includes(:subject)
                                .order("grades.name, sections.name")

    # Grados que lidera
    @led_grades = @teacher.led_grades.includes(:sections)

    # Resumen estadístico
    @total_sections = @teacher_sections.size
    @total_students = @teacher_sections.sum { |ts| ts.section.enrollments.count }
    @total_subjects = @teacher_sections.map(&:subject_id).uniq.size
  end

  private

  def require_profesor!
    unless profesor?
      redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para profesores."
    end
  end
end
