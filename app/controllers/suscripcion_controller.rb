# La pantalla «Suscripción» (spec `docs/specs/del-registro-al-cobro.md`, § 5.3).
#
#     en qué está      sin activar · en revisión · activa · por vencer · en gracia · solo lectura
#     cuánto cuesta    la matrícula de hoy × su precio, el mínimo y el IVA
#     cómo se paga     los medios que SIGA tiene cargados, y el WhatsApp
#     qué se pagó      los reportes, con su respuesta
#
# Es la salida de los dos callejones del cobro: el muro de lo gratis y la solo
# lectura del vencido enlazan aquí. Por eso no la cierra ninguno de los dos
# (`RespetaLaSuscripcion`, en las listas de lo que siempre se abre).
#
# La ven dirección y finanzas (decisión 14): quien lleva el dinero es quien paga.
class SuscripcionController < ApplicationController
  before_action :require_quien_paga!

  def show
    # ⚠️ Un colegio sin fila cuenta como gratis (decisión 16). No debería
    # quedar ninguno, pero la pantalla no puede reventar por eso.
    @suscripcion = suscripcion_del_colegio || Subscription.new(school: Current.school, plan: :gratis)
    @cotizacion  = @suscripcion.cotizacion
    @ajustes     = SigaSetting.actuales
    @pagos       = SubscriptionPayment.includes(:reportado_por).recientes_primero.limit(12).to_a
    @en_revision = @pagos.find(&:en_revision?)

    # El último rechazo se dice ARRIBA solo si después no se reportó nada: si
    # ya volvió a reportar, el rechazo es historia y queda en la tabla.
    ultimo = @pagos.first
    @rechazo = ultimo if ultimo&.rechazado?
  end
end
