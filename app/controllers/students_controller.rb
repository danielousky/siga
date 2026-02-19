class StudentsController < ApplicationController
  before_action :set_student, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @students = pagy(Student.includes(:user, :school))
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
      redirect_to @student, notice: "Estudiante creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @student.update(student_params)
      redirect_to @student, notice: "Estudiante actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @student.destroy
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
    params.require(:student).permit(:school_card, :school_id,
      user_attributes: [:id, :name, :last_name, :id_card, :email, :password, :password_confirmation])
  end
end
