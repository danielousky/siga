class SubjectsController < ApplicationController
  before_action :set_subject, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @subjects = pagy(Subject.includes(department: :school))
  end

  def show; end

  def new
    @subject = Subject.new
  end

  def edit; end

  def create
    @subject = Subject.new(subject_params)
    if @subject.save
      redirect_to @subject, notice: "Materia creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @subject.update(subject_params)
      redirect_to @subject, notice: "Materia actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @subject.destroy
      redirect_to subjects_url, notice: "Materia eliminada exitosamente."
    else
      redirect_to @subject, alert: @subject.errors.full_messages.join(", ")
    end
  end

  private

  def set_subject
    @subject = Subject.find(params[:id])
  end

  def subject_params
    params.require(:subject).permit(:code, :name, :department_id)
  end
end
