class StudentsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_student, only: [:show, :edit, :update, :destroy]

  def index
    scope = Student.includes(:user, :school)
    if params[:q].present?
      q = "%#{params[:q].strip}%"
      scope = scope.joins(:user).where(
        "users.name ILIKE :q OR users.last_name ILIKE :q OR users.id_card ILIKE :q OR students.school_card ILIKE :q",
        q: q
      )
    end
    @pagy, @students = pagy(scope.order("users.last_name, users.name"))
  end

  def show; end

  def new
    @student = Student.new
    @student.build_user
  end

  def edit; end

  def create
    @student = Student.new(student_params)
    if @student.save
      log_activity(
        action:  "student_created",
        message: "#{current_user.name} #{current_user.last_name} registró al estudiante " \
                 "#{@student.user.name} #{@student.user.last_name} (Exp: #{@student.school_card})",
        subject: @student
      )
      redirect_to @student, notice: "Estudiante creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @student.update(student_params)
      log_activity(
        action:  "student_updated",
        message: "#{current_user.name} #{current_user.last_name} actualizó los datos del estudiante " \
                 "#{@student.user.name} #{@student.user.last_name}",
        subject: @student
      )
      redirect_to @student, notice: "Estudiante actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    student_name = "#{@student.user.name} #{@student.user.last_name}"
    if @student.destroy
      log_activity(
        action:  "student_destroyed",
        message: "#{current_user.name} #{current_user.last_name} eliminó al estudiante #{student_name}"
      )
      redirect_to students_url, notice: "Estudiante eliminado exitosamente."
    else
      redirect_to @student, alert: @student.errors.full_messages.join(", ")
    end
  end

  private

  def set_student
    @student = Student.find(params[:id])
  end

  def student_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:student).permit(:school_card,
      user_attributes: [:id, :name, :last_name, :id_card, :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_students?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
