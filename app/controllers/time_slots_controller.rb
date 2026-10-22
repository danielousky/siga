# Corregir una hora del timbre desde la rejilla, con «Armar» abierto (spec
# `horarios`, decisión 20). Vuelve al horario de la sección con su mensaje.
#
# Corregir la hora mueve los minutos de todas sus clases: lo hace la base, con
# la llave compuesta `lessons_en_su_hora` (`ON UPDATE CASCADE`).
#
# ## ⚠️ Cada guardado va en su `SAVEPOINT`
#
# Que dos horas de un turno no se pisen lo exige la base
# (`time_slots_no_se_pisan`), y que un profesor no quede en dos sitios a la vez
# también (`lessons_un_profesor_en_un_sitio`, al mover los minutos). Una
# restricción violada ABORTA la transacción —que en SIGA es la petición
# entera—: sin el SAVEPOINT, el mensaje que viene después ya no se podría ni
# escribir. Es la lección del doble clic de «pagar sin consola».
class TimeSlotsController < ApplicationController
  el_nivel_no_aplica "un turno le sirve a secciones de cualquier nivel"

  before_action :require_admin_access!
  before_action :set_hora

  def update
    @hora.assign_attributes(hora_params)
    if TimeSlot.transaction(requires_new: true) { @hora.save }
      registrar_cambio(:actualizado, @bell_schedule, @bell_schedule.name)
      nombre = @hora.receso? ? "El receso" : "La #{@bell_schedule.nombre_de(@hora)}"
      decir "ok", "#{nombre} ahora va de #{HoraDelDia.texto(@hora.starts_min)} a #{HoraDelDia.texto(@hora.ends_min)}. " \
                  "Cambió en #{helpers.contar(@bell_schedule.sections.size, 'sección', 'secciones')} del " \
                  "#{@bell_schedule.name.downcase}."
      volver
    else
      decir "aviso", @hora.errors.full_messages.to_sentence
      volver hora: @hora.id
    end
  rescue ActiveRecord::ExclusionViolation
    decir "aviso", "No se guardó: con esa hora, una clase quedaría encima de otra del mismo profesor o de la misma sección."
    volver hora: @hora.id
  end

  private

  def decir(tipo, texto) = flash[:horario] = { "tipo" => tipo, "texto" => texto }

  def volver(**extra)
    redirect_to horarios_path(seccion: params[:seccion].presence, armar: 1, area: params[:area].presence, **extra)
  end

  def set_hora
    @bell_schedule = BellSchedule.find(params[:bell_schedule_id])
    @hora = @bell_schedule.time_slots.find(params[:id])
  end

  def hora_params
    params.require(:time_slot).permit(:desde, :hasta)
  end

  def require_admin_access!
    return if administrador? && can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
