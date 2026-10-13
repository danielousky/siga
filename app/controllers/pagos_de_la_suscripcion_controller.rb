# Reportar el pago de la suscripción (spec `docs/specs/del-registro-al-cobro.md`, § 5.5).
#
#     GET    /suscripcion/pagos/reportar   el formulario
#     POST   /suscripcion/pagos            queda «en revisión», y a SIGA le llega un correo
#     DELETE /suscripcion/pagos/:id        retirarlo, mientras nadie lo haya mirado
#
# ⚠️ Reportar no abre nada: lo abre la validación del fundador, en `/siga`
# (decisión 4). Hasta entonces el colegio sigue como estaba —y si estaba por
# caer a solo lectura, no cae: `Subscription#actualizar_estado!` no baja
# mientras un pago espera—.
class PagosDeLaSuscripcionController < ApplicationController
  before_action :require_quien_paga!
  before_action :exigir_un_medio_de_pago!, only: [ :new, :create ]
  before_action :uno_a_la_vez!, only: [ :new ]

  def new
    @pago = SubscriptionPayment.nuevo_para(suscripcion, por: current_user,
                                           medio: ajustes.medios.first, pagado_el: Date.current)
  end

  def create
    @pago = SubscriptionPayment.nuevo_para(suscripcion, por: current_user)
    @pago.assign_attributes(datos_del_pago)

    return render :new, status: :unprocessable_entity unless guardar(@pago)

    log_activity(action: "suscripcion_pago_reportado", subject: @pago,
                 message: "#{current_user.nombre_completo} reportó el pago de la suscripción " \
                          "(#{@pago.nombre_del_medio}, #{importe_del(@pago)})")
    PlataformaMailer.pago_reportado(@pago).deliver_later

    redirect_to suscripcion_path,
                notice: "Recibimos su reporte. Le avisamos por correo apenas lo validemos."
  end

  # ⚠️ Solo mientras nadie lo ha mirado. Uno validado ya abrió el sistema, y uno
  # rechazado ya tiene su respuesta: retirarlos sería borrar la historia de qué
  # se pagó y qué se contestó.
  def destroy
    pago = SubscriptionPayment.find(params[:id])

    unless pago.se_puede_retirar?
      return redirect_to suscripcion_path, alert: "Ese pago ya se revisó: no se puede retirar."
    end

    pago.destroy!
    log_activity(action: "suscripcion_pago_retirado",
                 message: "#{current_user.nombre_completo} retiró el reporte del pago de la " \
                          "suscripción (#{pago.nombre_del_medio}, #{importe_del(pago)})")

    redirect_to suscripcion_path, notice: "Retirado. Puede reportarlo de nuevo cuando quiera."
  end

  private

  # ⚠️ En su propio `SAVEPOINT`, y con la red del índice único.
  #
  # Un doble envío son dos peticiones que pasan a la vez la validación de «uno
  # en revisión»: la segunda choca contra el índice de la base. Sin atraparla
  # era un 500 justo en la pantalla donde el colegio dice que pagó; y sin el
  # `SAVEPOINT`, el choque dejaba abortada la transacción de la petición entera.
  # El primero SÍ quedó guardado, así que se contesta eso.
  def guardar(pago)
    SubscriptionPayment.transaction(requires_new: true) { pago.save }
  rescue ActiveRecord::RecordNotUnique
    pago.errors.add(:base, "Ese pago ya quedó reportado: está esperando validación.")
    false
  end

  def ajustes = @ajustes ||= SigaSetting.actuales
  helper_method :ajustes

  # ⚠️ Todo colegio tiene su suscripción (decisión 16); si a alguno le faltara,
  # se le abre aquí la gratis, que es la que habría tenido. Sin fila, validar el
  # pago no tendría qué activar.
  def suscripcion
    @suscripcion ||= suscripcion_del_colegio ||
                     Subscription.abrir_gratis!(Current.school, nota: "Gratis: abierta al reportar un pago.")
  end

  # Sin un medio cargado no hay a dónde pagar, y un formulario sin opciones es
  # un callejón: se vuelve a «Suscripción», que dice cómo escribirnos.
  def exigir_un_medio_de_pago!
    return if ajustes.medios.any?

    redirect_to suscripcion_path, alert: "Todavía no hay medios de pago cargados. Escríbanos y le decimos cómo pagar."
  end

  # Uno en revisión a la vez (§ 5.5). El modelo lo exige igual; esto evita
  # llenar un formulario entero para enterarse al final.
  def uno_a_la_vez!
    return if suscripcion.pago_en_revision.blank?

    redirect_to suscripcion_path, alert: "Ya hay un pago esperando validación. Cuando se resuelva, puede reportar otro."
  end

  def datos_del_pago
    params.require(:subscription_payment).permit(:medio, :monto, :referencia, :pagado_el, :nota, :comprobante)
  end

  def importe_del(pago) = helpers.importe_del_pago(pago)
end
