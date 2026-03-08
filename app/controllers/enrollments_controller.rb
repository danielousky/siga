class EnrollmentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_enrollment, only: [:show, :edit, :update, :destroy]

  def index
    @enrollments = Enrollment.includes(student: :user, section: [:grade, :academic_period]).all
  end

  def show; end

  def new
    @enrollment = Enrollment.new(enrollment_date: Date.today)
  end

  def edit; end

  def create
    @enrollment = Enrollment.new(enrollment_params)
    if @enrollment.save
      log_activity(
        action:  "enrollment_created",
        message: "#{current_user.name} #{current_user.last_name} inscribió al estudiante " \
                 "#{@enrollment.student.user.name} #{@enrollment.student.user.last_name} en " \
                 "#{@enrollment.section.grade.name} – Sección #{@enrollment.section.name}",
        subject: @enrollment
      )
      redirect_to @enrollment, notice: "Inscripción creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @enrollment.update(enrollment_params)
      redirect_to @enrollment, notice: "Inscripción actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    student_name = "#{@enrollment.student.user.name} #{@enrollment.student.user.last_name}"
    section_name = "#{@enrollment.section.grade.name} – Sección #{@enrollment.section.name}"
    if @enrollment.destroy
      log_activity(
        action:  "enrollment_destroyed",
        message: "#{current_user.name} #{current_user.last_name} anuló la inscripción de " \
                 "#{student_name} en #{section_name}"
      )
      redirect_to enrollments_url, notice: "Inscripción eliminada exitosamente."
    else
      redirect_to @enrollment, alert: @enrollment.errors.full_messages.join(", ")
    end
  end

  private

  def set_enrollment
    @enrollment = Enrollment.find(params[:id])
  end

  def enrollment_params
    params.require(:enrollment).permit(:student_id, :section_id, :enrollment_date, :status)
  end

  def require_admin_access!
    unless administrador? && can_manage_sections?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
