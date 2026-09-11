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
  include PlanillaQueSeGuardaSola
  before_action :require_profesor!
  before_action :set_evaluation_activity

  def index
    @inscripciones = @evaluation_activity.section.enrollments
                                         .includes(student: :user)
                                         .to_a
                                         .sort_by { |i| [i.student.user.last_name, i.student.user.first_name] }

    @notas_por_alumno = @evaluation_activity.activity_grades.index_by(&:student_id)

    # ⚠️ El promedio del lapso, al lado de la nota que se está cargando.
    #
    # Es la diferencia entre saber que un alumno sacó 8 y saber si ese 8 es un
    # accidente o una tendencia. El profesor lo tiene en la cabeza para los cinco
    # que conoce bien; para los otros veinticinco, no.
    #
    # Una sola consulta: pedirlo por alumno serían treinta.
    @promedios = MomentGrade
      .where(enrollment_id: @inscripciones.map(&:id),
             subject_id: @evaluation_activity.subject_id,
             evaluation_moment_id: @evaluation_activity.evaluation_moment_id)
      .pluck(:enrollment_id, :final_moment_score)
      .to_h
  end

  def update
    inscripcion = inscripcion_del_alumno
    return head(:not_found) if inscripcion.nil?

    puntaje = params[:score].to_s.strip
    nota    = @evaluation_activity.activity_grades.find_by(student_id: inscripcion.student_id)

    # Vacío = borrar. El alumno vuelve a "sin nota", que no es una nota baja.
    if puntaje.blank?
      anterior = nota&.score
      nota&.destroy
      auditar(inscripcion, "calificacion_eliminada", anterior, nil) if anterior
      return contestar(inscripcion, :vacio)
    end

    nota ||= @evaluation_activity.activity_grades.new(student_id: inscripcion.student_id)
    anterior = nota.score
    nota.score = puntaje

    if nota.save
      auditar(inscripcion,
              anterior.nil? ? "calificacion_registrada" : "calificacion_modificada",
              anterior, nota.score)
      contestar(inscripcion, :guardado)
    else
      contestar(inscripcion, :rechazado, nota.errors.full_messages.to_sentence,
                estado_http: :unprocessable_entity)
    end
  end

  private

  # Quién le puso qué nota a quién, y qué decía antes.
  #
  # ## Por qué una fila por nota, y no un resumen por planilla
  #
  # La pregunta que un colegio necesita responder es *"¿quién le cambió la nota
  # a mi hijo?"* — y la hace una madre, por una nota, meses después. Un resumen
  # tipo "el profesor García cargó 30 notas" no la contesta.
  #
  # Sí: cargar una sección son 30 filas, y corregir un tipeo agrega una más.
  # Esa fila de más **es la historia**, no ruido: dice que la nota fue 12 antes
  # de ser 15, y quién lo hizo.
  #
  # `log_activity` traga sus propios errores (ver `Auditable`), así que una
  # falla auditando nunca impide guardar la nota. El orden importa: primero se
  # guarda, después se audita.
  def auditar(inscripcion, accion, anterior, actual)
    # Guardar el mismo valor no es un cambio. La planilla reenvía al salir del
    # campo, así que sin esto un profesor que revisa sus notas sin tocar nada
    # generaría treinta "Calificación modificada" — y un historial lleno de
    # cambios que no ocurrieron **esconde los que sí**.
    return if anterior.to_i == actual.to_i && !anterior.nil? && !actual.nil?

    alumno = inscripcion.student.user
    cambio = if actual.nil?      then "le borró la nota (era #{anterior.to_i})"
             elsif anterior.nil? then "le puso #{actual.to_i}"
             else                     "le cambió el #{anterior.to_i} por #{actual.to_i}"
             end

    log_activity(
      action:  accion,
      subject: @evaluation_activity,
      message: "#{current_user.nombre_completo} #{cambio} a " \
               "#{alumno.last_name}, #{alumno.first_name} en «#{@evaluation_activity.description}»",
      metadata: { alumno_id: alumno.id, anterior: anterior&.to_i, actual: actual&.to_i }
    )
  end

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

  # ⚠️ `status:` va en el rechazo, y no es un detalle: Turbo solo procesa el
  # stream de una respuesta 2xx **o** de una 4xx/5xx si el formato es stream, y
  # el controlador de Stimulus mira `detail.success` para saber si el valor se
  # guardó. Con un 200 en un rechazo, el campo quedaría dado por guardado.
  def contestar(inscripcion, estado, mensaje = nil, estado_http: :ok)
    response.status = estado_http

    fila_de_la_planilla(
      id: "estado_#{inscripcion.student_id}", estado: estado, mensaje: mensaje,
      hechas: @evaluation_activity.activity_grades.count,
      total: @evaluation_activity.section.enrollments.count, nombre: "cargadas"
    )
  end

  def require_profesor!
    return if profesor?

    respond_to do |formato|
      formato.html { redirect_to dashboard_path_for_user, alert: "Solo el profesor que dicta la materia carga sus notas." }
      formato.turbo_stream { head :forbidden }
    end
  end
end
