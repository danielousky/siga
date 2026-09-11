# Guardar una valoración descriptiva de Educación Inicial.
#
# Es la calificación de un área en un lapso, y en Inicial es un TEXTO: no hay
# nota del 1 al 20, ni escala, ni promedio (ver `docs/specs/educacion-inicial.md`).
#
# ## ⚠️ Guarda al salir del campo, una casilla por vez
#
# Son tres áreas por niño y hasta treinta niños: noventa textos por lapso. Un
# botón «Guardar» al final de esa pantalla pierde el trabajo de una hora en
# cuanto el navegador se cierra, y es lo que ya resolvió la planilla de notas
# (`MOR-95`): guardado incremental, sin botón.
class ValoracionesController < ApplicationController
  before_action :set_seccion
  before_action :require_acceso!

  def update
    valoracion = MomentGrade.find_or_initialize_by(
      enrollment_id: inscripcion.id, subject_id: area.id, evaluation_moment_id: lapso.id
    )

    # ⚠️ Vaciar el campo BORRA la fila, no guarda un texto vacío.
    #
    # Es la misma regla que la planilla de notas: «sin nota» no es un cero, y
    # acá «sin valoración» no es un texto en blanco. Una fila vacía saldría en
    # la boleta como un renglón mudo, y contaría como escrita en «¿por dónde
    # iba?».
    if params[:descripcion].blank?
      valoracion.destroy if valoracion.persisted?
      return refrescar
    end

    valoracion.descripcion = params[:descripcion]
    valoracion.origen = :calculada
    valoracion.save

    refrescar(valoracion)
  end

  private

  # La pantalla entera vuelve a dibujarse dentro de su frame: la casilla guardada
  # y el contador de «cuántas van».
  def refrescar(valoracion = nil)
    @valoraciones = ValoracionesDeLaSeccion.para(seccion: @seccion, lapso: lapso)
    @error = valoracion&.errors&.full_messages&.to_sentence.presence
    @guardada = "valoracion_#{inscripcion.id}_#{area.id}" if @error.nil?

    render partial: "sections/valoraciones", formats: [ :html ],
           locals: { seccion: @seccion, lapso: lapso,
                     # Quien llegó hasta acá ya pasó `require_acceso!`.
                     puede_valorar: true }
  end

  # ⚠️ `section_id` y no `seccion_id`: la ruta anidada toma el nombre del
  # RECURSO —`resources :sections`— y el `path: "secciones"` solo cambia la URL
  # que se ve. Es la misma regla que ordena inglés en los modelos y español en
  # las URLs (`MOR-162`).
  def set_seccion
    @seccion = Section.find(params[:section_id])
  end

  def inscripcion = @inscripcion ||= @seccion.enrollments.find(params[:enrollment_id])

  def area = @area ||= @seccion.grade.subjects.find(params[:subject_id])

  def lapso
    @lapso ||= EvaluationMoment.where(academic_period_id: @seccion.academic_period_id)
                               .find(params[:lapso])
  end

  # ⚠️ Quién escribe: el profesor asignado a la sección y la dirección.
  #
  # En Educación Inicial la maestra dicta las tres áreas, así que basta con que
  # tenga la sección. Y la dirección también, porque una sección puede no tener
  # profesor asignado todavía y esos niños se quedarían sin valoración.
  def require_acceso!
    return if can_manage_sections?
    return if profesor? && TeacherSection.exists?(section_id: @seccion.id,
                                                  teacher_id: current_user.teacher&.id)

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
  end
end
