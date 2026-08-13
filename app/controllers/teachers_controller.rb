class TeachersController < ApplicationController
  before_action :require_admin_access!
  before_action :set_teacher, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @teachers = pagy(Teacher.includes(:user, :school))
  end

  def show; end

  def new
    @teacher = Teacher.new
    @teacher.build_user
  end

  def edit; end

  def create
    @teacher = Teacher.new(teacher_params)
    if @teacher.save
      redirect_to @teacher, notice: "Profesor creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @teacher.update(teacher_params)
      redirect_to @teacher, notice: "Profesor actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @teacher.destroy
      redirect_to teachers_url, notice: "Profesor eliminado exitosamente."
    else
      redirect_to @teacher, alert: @teacher.errors.full_messages.join(", ")
    end
  end

  private

  def set_teacher
    @teacher = Teacher.find(params[:id])
  end

  def teacher_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:teacher).permit(
      user_attributes: [:id, :name, :last_name, :id_card, :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && can_manage_teachers?
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
    end
  end
end
