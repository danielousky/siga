class TeacherSectionsController < ApplicationController
  before_action :set_section

  def create
    @teacher_section = @section.teacher_sections.build(teacher_section_params)
    if @teacher_section.save
      log_activity(
        action:  "teacher_assigned",
        message: "#{current_user.nombre_completo} asignó al profesor " \
                 "#{@teacher_section.teacher.user.nombre_completo} " \
                 "para dictar #{@teacher_section.subject.name} en " \
                 "#{@section.grade.name} – Sección #{@section.name}",
        subject: @teacher_section
      )
      redirect_to @section, notice: "Profesor asignado exitosamente."
    else
      redirect_to @section, alert: @teacher_section.errors.full_messages.join(", ")
    end
  end

  def destroy
    @teacher_section = @section.teacher_sections.find(params[:id])
    teacher_name  = "#{@teacher_section.teacher.user.nombre_completo}"
    subject_name  = @teacher_section.subject.name
    section_label = "#{@section.grade.name} – Sección #{@section.name}"
    @teacher_section.destroy
    log_activity(
      action:  "teacher_removed",
      message: "#{current_user.nombre_completo} removió al profesor " \
               "#{teacher_name} de #{subject_name} en #{section_label}"
    )
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
