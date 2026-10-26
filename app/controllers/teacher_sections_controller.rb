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
      volver notice: ["Profesor asignado exitosamente.", desubicadas(@teacher_section)].compact.join(" ")
    else
      volver alert: @teacher_section.errors.full_messages.join(", ")
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
    volver notice: "Profesor removido exitosamente."
  end

  private

  # Las clases que el profesor nuevo no pudo tomar porque ya dicta en otra
  # sección a esa hora: volvieron a «por ubicar» (spec `horarios`, decisión 8).
  def desubicadas(asignacion)
    clases = asignacion.clases_desubicadas
    return if clases.empty?

    "#{clases.size == 1 ? "Una clase volvió" : "#{clases.size} clases volvieron"} a «por ubicar» en el horario: " \
      "#{clases.join("; ")}."
  end

  # ⚠️ Vuelve a DONDE SE VINO, no siempre a la ficha de section (MOR-198).
  #
  # Esta acción se dispara ahora desde dos lados —la ficha de section y la de
  # la materia—, porque Daniel preguntó lo obvio mirando una materia sin grados:
  # *«¿por qué no puedo asignar desde allí los grados y los profes?»*. Mandar
  # siempre a la misma pantalla deja a quien asignó desde la materia parado en
  # un sitio que no pidió.
  #
  # `allow_other_host: false` —el default— es lo que impide que un `Referer`
  # armado a mano convierta esto en un redirector abierto.
  def volver(**mensaje)
    redirect_back fallback_location: @section, allow_other_host: false, **mensaje
  end

  def set_section
    @section = Section.find(params[:section_id])
  end

  def teacher_section_params
    params.permit(:teacher_id, :subject_id)
  end
end
