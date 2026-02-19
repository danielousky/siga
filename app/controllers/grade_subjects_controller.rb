class GradeSubjectsController < ApplicationController
  before_action :set_grade

  def create
    @grade_subject = @grade.grade_subjects.build(grade_subject_params)
    if @grade_subject.save
      redirect_to @grade, notice: "Materia asignada exitosamente."
    else
      redirect_to @grade, alert: @grade_subject.errors.full_messages.join(", ")
    end
  end

  def destroy
    @grade_subject = @grade.grade_subjects.find(params[:id])
    @grade_subject.destroy
    redirect_to @grade, notice: "Materia removida exitosamente."
  end

  private

  def set_grade
    @grade = Grade.find(params[:grade_id])
  end

  def grade_subject_params
    params.permit(:subject_id)
  end
end
