class TeacherSectionsController < ApplicationController
  before_action :set_section

  def create
    @teacher_section = @section.teacher_sections.build(teacher_section_params)
    if @teacher_section.save
      redirect_to @section, notice: "Profesor asignado exitosamente."
    else
      redirect_to @section, alert: @teacher_section.errors.full_messages.join(", ")
    end
  end

  def destroy
    @teacher_section = @section.teacher_sections.find(params[:id])
    @teacher_section.destroy
    redirect_to @section, notice: "Profesor removido exitosamente."
  end

  private

  def set_section
    @section = Section.find(params[:section_id])
  end

  def teacher_section_params
    params.permit(:teacher_id, :subject_id)
  end
end
