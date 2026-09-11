# Los informes descriptivos de una sección, en un lapso (MOR-216).
#
# ## Una planilla, no un formulario por alumno
#
# La maestra escribe veinticinco informes seguidos. Con una pantalla por alumno
# son cincuenta clics de navegación además de lo que escribe, y el trabajo se
# abandona a la mitad. Es el mismo problema que resolvió la planilla de notas, y
# la misma solución: todos en una pantalla, con guardado incremental.
#
# ## ⚠️ Quién escribe
#
# El **profesor guía de la sección**. En primaria una sola maestra dicta todo,
# así que es ella; en bachillerato son doce profesores y ninguno ve al alumno
# entero — el guía sí (`Section#leader_teacher`, MOR-209).
#
# Y la **dirección** también, porque una sección puede no tener guía: el cargo
# es opcional y sin esto esos alumnos se quedarían sin informe para siempre.
class InformesController < ApplicationController
  include PlanillaQueSeGuardaSola
  before_action :set_seccion
  before_action :require_acceso!
  before_action :set_lapso

  def index
    @inscripciones = Enrollment.en_orden_de_lista(Enrollment.where(section_id: @seccion.id))

    @informes = Informe.del_lapso(@lapso&.id)
                       .where(enrollment_id: @inscripciones.map(&:id))
                       .index_by(&:enrollment_id)

    # El promedio del lapso al lado del nombre: la maestra escribe veinticinco
    # informes seguidos y necesita recordar de quién habla sin salir de acá.
    @promedios = promedios_del_lapso
    @rubricas  = Rubric.en_orden.to_a
  end

  # ⚠️ Guardado incremental, como la planilla de notas: cada informe viaja solo
  # apenas se deja de escribir. Un formulario de veinticinco textos largos que
  # se envía al final es una promesa de perder el trabajo de una noche.
  def update
    inscripcion = Enrollment.find_by(id: params[:enrollment_id], section_id: @seccion.id)
    return head(:not_found) if inscripcion.nil?
    return contestar(params[:enrollment_id], :rechazado, "Elija un lapso.",
                     estado_http: :unprocessable_entity) if @lapso.nil?

    cuerpo  = params[:cuerpo].to_s.strip
    informe = Informe.para(inscripcion.id, @lapso.id)

    # Vacío = borrar. El alumno vuelve a «sin informe», que no es un informe en
    # blanco: la boleta no tiene que imprimir un renglón vacío.
    if cuerpo.blank?
      informe&.destroy
      return contestar(inscripcion.id, :vacio)
    end

    informe ||= Informe.new(enrollment: inscripcion, evaluation_moment: @lapso)
    informe.escrito_por = current_user
    informe.cuerpo = cuerpo

    if informe.save
      contestar(inscripcion.id, :guardado)
    else
      contestar(inscripcion.id, :rechazado, informe.errors.full_messages.to_sentence,
                estado_http: :unprocessable_entity)
    end
  end

  private

  # ⚠️ Sin barra de progreso: acá el contador vive arriba y cuenta CUÁNTOS
  # informes hay escritos, que es una consulta a la tabla entera. Recalcularla
  # en cada tecla de una planilla de treinta no vale lo que cuesta — el profesor
  # ya ve, fila por fila, cuáles quedaron.
  def contestar(inscripcion_id, estado, mensaje = nil, estado_http: :ok)
    response.status = estado_http

    fila_de_la_planilla(id: "estado_#{inscripcion_id}", estado: estado, mensaje: mensaje)
  end

  def set_seccion
    @seccion = Section.find(params[:section_id])
  end

  def set_lapso
    lapsos = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id)
                             .order(:starts_on, :id)
    @lapsos = lapsos.to_a
    @lapso  = @lapsos.find { |l| l.id.to_s == params[:lapso].to_s } || @lapsos.first
  end

  # ⚠️ El guía de ESTA sección, o la dirección. Un profesor que dicta acá pero
  # no es el guía no escribe el informe: es un juicio sobre el alumno entero, y
  # el de Educación Física no lo tiene.
  def require_acceso!
    return if can_manage_sections?
    return if profesor? && @seccion.leader_teacher_id == current_user.teacher&.id

    redirect_to dashboard_path_for_user,
                alert: "El informe descriptivo lo escribe el profesor guía de la sección."
  end

  def promedios_del_lapso
    return {} if @lapso.nil?

    MomentGrade.where(evaluation_moment_id: @lapso.id,
                      enrollment_id: @inscripciones.map(&:id))
               .group(:enrollment_id).average(:final_moment_score)
               .transform_values { |v| GradeCalculator.redondear(v) }
  end
end
