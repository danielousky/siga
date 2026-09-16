# El vistazo final antes de que la familia vea su boletín.
#
#     GET   /boletines/revisar   ?seccion=&lapso=&alumno=
#     PATCH /boletines/liberar   ?seccion=&lapso=
#     PATCH /boletines/esconder  ?seccion=&lapso=
#
# Daniel: *«las boletas deberán pasar por una revisión por parte de Admin antes
# de ser mostradas al representante, por si algo no está bien. Una especie de
# vistazo final. Debería poder ver una por una y cuando considere que todo está
# OK, liberar… con un solo clic»*.
#
# ## ⚠️ Por SECCIÓN y lapso, no por lapso de todo el colegio
#
# Un colegio de diecinueve secciones no revisa las diecinueve de una sentada, y
# la coordinadora de primaria no libera bachillerato. El «un solo clic» es sobre
# lo que se acaba de revisar.
class RevisionDeBoletinesController < ApplicationController
  before_action :require_emisor!
  before_action :set_seccion_y_lapso

  def show
    @boletines = BoletinesDelLapso.de(@seccion, @lapso)
    @fichas = @boletines.fichas
    @elegida = @fichas.find { |f| f.inscripcion.id == params[:alumno].to_i } || @fichas.first
    @posicion = @fichas.index(@elegida)
  end

  # ⚠️ Libera lo EMITIDO, aunque falten notas en otros.
  #
  # Bloquear la liberación entera por un boletín incompleto obliga a perseguir a
  # un profesor para poder entregarle los otros veinte que sí están. La pantalla
  # dice cuántos faltan; la decisión es de quien revisa.
  def liberar
    cuantos = ReportCard.where(id: sin_liberar.map(&:id)).count
    ReportCard.where(id: sin_liberar.map(&:id))
              .update_all(liberado_el: Time.current, liberado_por_id: current_user.id)

    avisar_a_las_familias(sin_liberar)
    registrar("boletines_liberados",
              "#{current_user.nombre_completo} liberó #{helpers.contar(cuantos, 'boletín', 'boletines')} " \
              "de #{@seccion.grade.name} – #{@seccion.name} · #{@lapso.name}")

    redirect_to revisar_boletines_path(contexto),
                notice: "Listo. #{helpers.contar(cuantos, 'boletín', 'boletines')} a la vista de las familias."
  end

  # ⚠️ Reversible: si al liberar aparece un error, se vuelve a esconder.
  def esconder
    liberados = BoletinesDelLapso.de(@seccion, @lapso).liberados.filter_map(&:boletin)
    ReportCard.where(id: liberados.map(&:id)).update_all(liberado_el: nil, liberado_por_id: nil)

    registrar("boletines_escondidos",
              "#{current_user.nombre_completo} volvió a esconder " \
              "#{helpers.contar(liberados.size, 'boletín', 'boletines')} de " \
              "#{@seccion.grade.name} – #{@seccion.name} · #{@lapso.name}")

    redirect_to revisar_boletines_path(contexto),
                notice: "Escondidos. Las familias dejan de verlos."
  end

  private

  def set_seccion_y_lapso
    @seccion = Section.find(params[:seccion])
    @lapso = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id)
                             .find_by(id: params[:lapso]) ||
             EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id).first
    raise ActiveRecord::RecordNotFound if @lapso.nil?

    @lapsos = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id)
  end

  def sin_liberar
    @sin_liberar ||= BoletinesDelLapso.de(@seccion, @lapso)
                                      .emitidos.reject(&:liberado?).filter_map(&:boletin)
  end

  def contexto = { seccion: @seccion.id, lapso: @lapso.id }

  # ⚠️ El aviso va DESPUÉS de escribir, y uno por familia.
  #
  # Y dice dos cosas distintas según la deuda: a quien está al día, que ya puede
  # descargarlo; a quien no, que está listo y qué falta para verlo. Mandarle a
  # una familia en mora «ya puede descargarlo» es prometerle una pantalla que la
  # va a rebotar.
  def avisar_a_las_familias(boletines)
    boletines.each { |boletin| BoletinMailer.liberado(boletin).deliver_later }
  end

  def registrar(accion, mensaje) = log_activity(action: accion, message: mensaje)

  def require_emisor!
    return if can_manage_students?

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para revisar boletines."
  end
end
