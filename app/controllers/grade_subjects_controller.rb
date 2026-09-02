class GradeSubjectsController < ApplicationController
  before_action :set_grade

  def create
    @grade_subject = @grade.grade_subjects.build(grade_subject_params)
    if @grade_subject.save
      volver notice: "Materia asignada exitosamente."
    else
      volver alert: @grade_subject.errors.full_messages.join(", ")
    end
  end

  def destroy
    @grade_subject = @grade.grade_subjects.find(params[:id])
    @grade_subject.destroy
    volver notice: "Materia removida exitosamente."
  end

  private

  # ⚠️ Vuelve a DONDE SE VINO, no siempre a la ficha de grade (MOR-198).
  #
  # Esta acción se dispara ahora desde dos lados —la ficha de grade y la de
  # la materia—, porque Daniel preguntó lo obvio mirando una materia sin grados:
  # *«¿por qué no puedo asignar desde allí los grados y los profes?»*. Mandar
  # siempre a la misma pantalla deja a quien asignó desde la materia parado en
  # un sitio que no pidió.
  #
  # `allow_other_host: false` —el default— es lo que impide que un `Referer`
  # armado a mano convierta esto en un redirector abierto.
  def volver(**mensaje)
    redirect_back fallback_location: @grade, allow_other_host: false, **mensaje
  end

  def set_grade
    @grade = Grade.find(params[:grade_id])
  end

  def grade_subject_params
    params.permit(:subject_id)
  end
end
