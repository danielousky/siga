class Dashboards::AdministradorController < ApplicationController
  before_action :require_admin!

  def index
    @admin = current_user.admin
    @total_students = Student.count
    @total_teachers = Teacher.count
    @total_sections = Section.count
    @total_admins = Admin.count

    # Actividad reciente solo para desarrollador y director
    if show_recent_activity?
      @recent_enrollments = Enrollment.includes(student: :user, section: [:grade]).order(created_at: :desc).limit(10)
    end
  end

  private

  def require_admin!
    unless administrador?
      redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para administradores."
    end
  end
end
