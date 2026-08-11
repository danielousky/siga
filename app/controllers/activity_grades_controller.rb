# La planilla de carga de notas.
#
# Es LA pantalla del producto. Todo lo demás del sistema lo usa un administrativo
# en una oficina; esta la usa un profesor un domingo por la noche, en su casa, en
# su teléfono. Si es incómoda el profesor vuelve al cuaderno, y el colegio deja de
# pagar — no porque el sistema no funcione, sino porque nadie lo usa.
#
# ## Cada nota se guarda sola
#
# No hay botón "Guardar" al final. Un formulario de 30 campos que se envía de una
# sola vez, con la conectividad que hay, es una promesa de perder el trabajo. Cada
# nota va al servidor cuando se escribe, y el profesor VE que se guardó: un
# guardado silencioso que falla es peor que no guardar, porque cierra el teléfono
# creyendo que terminó.
#
# ## Sin nota no es cero
#
# Mandar el campo vacío BORRA la nota y devuelve al alumno a "sin nota". No la
# pone en 1. Es la misma trampa que en `GradeCalculator`: confundir las dos cosas
# reprueba a la sección entera a mitad de lapso.
#
# Ver MOR-95.
class ActivityGradesController < ApplicationController
  before_action :require_profesor!
  before_action :set_evaluation_activity

  def index
    @inscripciones = @evaluation_activity.section.enrollments
                                         .includes(student: :user)
                                         .to_a
                                         .sort_by { |i| [i.student.user.last_name, i.student.user.name] }

    @notas_por_alumno = @evaluation_activity.activity_grades.index_by(&:student_id)
  end

  def update
    inscripcion = inscripcion_del_alumno
    return render(json: { estado: "error", mensaje: "Ese alumno no está inscrito en esta sección." }, status: :not_found) if inscripcion.nil?

    puntaje = params[:score].to_s.strip
    nota    = @evaluation_activity.activity_grades.find_by(student_id: inscripcion.student_id)

    # Vacío = borrar. El alumno vuelve a "sin nota", que no es una nota baja.
    if puntaje.blank?
      nota&.destroy
      return render json: respuesta(nil)
    end

    nota ||= @evaluation_activity.activity_grades.new(student_id: inscripcion.student_id)
    nota.score = puntaje

    if nota.save
      render json: respuesta(nota)
    else
      render json: { estado: "error", mensaje: nota.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  # El alcance del profesor decide qué planillas existen para él. `find` sale de
  # ahí, así que la actividad de otro profesor da 404 y no 403.
  def set_evaluation_activity
    @evaluation_activity = EvaluationActivity
                           .dictadas_por(current_user.teacher)
                           .find(params[:evaluation_activity_id])
  end

  # El alumno tiene que estar inscrito en ESTA sección. Sin esto, un `student_id`
  # cualquiera en la URL le pondría nota a un alumno de otra sección — el
  # aislamiento por colegio no lo agarraría, porque puede ser del mismo colegio.
  def inscripcion_del_alumno
    @evaluation_activity.section.enrollments.find_by(student_id: params[:student_id])
  end

  def respuesta(nota)
    {
      estado: "guardado",
      nota: nota&.score&.to_i,
      cargadas: @evaluation_activity.activity_grades.count,
      total: @evaluation_activity.section.enrollments.count
    }
  end

  def require_profesor!
    return if profesor?

    respond_to do |formato|
      formato.html { redirect_to dashboard_path_for_user, alert: "Solo el profesor que dicta la materia carga sus notas." }
      formato.json { render json: { estado: "error", mensaje: "No autorizado." }, status: :forbidden }
    end
  end
end
