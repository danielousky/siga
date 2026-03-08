class Dashboards::EstudianteController < ApplicationController
  before_action :require_estudiante!

  def index
    @student = current_user.student

    # Inscripciones activas con toda la información necesaria
    @enrollments = @student.enrollments
                           .where(status: :regular)
                           .includes(section: [:grade, :academic_period,
                                               teacher_sections: [:teacher, :subject]])
                           .order("grades.name, sections.name")

    # Estadísticas
    @total_sections = @enrollments.size
    @current_period = @enrollments.first&.section&.academic_period
  end

  private

  def require_estudiante!
    unless estudiante?
      redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para estudiantes."
    end
  end
end
