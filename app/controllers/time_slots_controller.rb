# Las HORAS de un turno, corregidas una por una en la ficha del turno.
#
# No tiene pantallas: cada fila de la ficha es su propio formulario, y las tres
# acciones vuelven a ella.
#
# ## ⚠️ Cada guardado va en su `SAVEPOINT`
#
# Que dos horas de un turno no se pisen lo exige la base
# (`time_slots_no_se_pisan`), y una restricción violada ABORTA la transacción —
# que en SIGA es la petición entera—. Sin el `SAVEPOINT`, el aviso que viene
# después ya no se podría ni escribir: «current transaction is aborted». Es la
# lección del doble clic de «pagar sin consola».
#
# La validación del modelo dice lo mismo antes, con palabras («se pisa con la
# 2da hora»). La restricción es para lo que la validación no ve: dos personas
# corrigiendo el timbre a la vez.
class TimeSlotsController < ApplicationController
  el_nivel_no_aplica "un turno le sirve a secciones de cualquier nivel"

  before_action :require_admin_access!
  before_action :set_turno
  before_action :set_hora, only: [ :update, :destroy ]

  def create
    guardar TimeSlot.new(hora_params.merge(bell_schedule: @bell_schedule)), "Hora agregada."
  end

  def update
    @hora.assign_attributes(hora_params)
    guardar @hora, "Hora corregida."
  end

  def destroy
    @hora.destroy!
    registrar_cambio(:actualizado, @bell_schedule, @bell_schedule.name)
    redirect_to @bell_schedule, notice: "Hora eliminada."
  end

  private

  def guardar(hora, aviso)
    guardada = TimeSlot.transaction(requires_new: true) { hora.save }

    if guardada
      registrar_cambio(:actualizado, @bell_schedule, @bell_schedule.name)
      redirect_to @bell_schedule, notice: aviso
    else
      redirect_to @bell_schedule, alert: hora.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::ExclusionViolation
    redirect_to @bell_schedule, alert: "Esa hora se pisa con otra del mismo turno."
  end

  def set_turno
    @bell_schedule = BellSchedule.find(params[:bell_schedule_id])
  end

  def set_hora
    @hora = @bell_schedule.time_slots.find(params[:id])
  end

  def hora_params
    params.require(:time_slot).permit(:desde, :hasta, :kind)
  end

  def require_admin_access!
    return if administrador? && can_manage_sections?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
  end
end
