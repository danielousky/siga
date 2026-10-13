import { Controller } from "@hotwired/stimulus"

// El reporte del pago de la suscripción cambia según el MEDIO (spec
// `del-registro-al-cobro`, § 5.5):
//
//     Pago Móvil o transferencia   monto en Bs   referencia   comprobante
//     Binance (USDT)               monto en $    referencia   comprobante
//     PayPal                       monto en $    referencia   comprobante
//     Efectivo en dólares          monto en $    —            comprobante, si hay
//
// La unidad la da el medio: nadie escribe «Bs» o «$» a mano, y un monto sin
// unidad es un número que el fundador tiene que adivinar al validar.
//
// ⚠️ El servidor dibuja ya el estado del medio elegido —también al volver con
// un error—, así que esto solo ACOMPAÑA el cambio. Sin JavaScript el formulario
// sigue siendo correcto para el medio con que se abrió.
//
// ⚠️ La referencia se APAGA en efectivo, no solo se esconde: un campo escondido
// pero encendido se envía igual, y un `required` escondido bloquea el envío sin
// que la persona vea por qué.
export default class extends Controller {
  static targets = ["unidad", "conReferencia", "referencia", "comprobante", "comprobanteOpcional"]

  connect() {
    this.elegir()
  }

  elegir() {
    const elegido = this.element.querySelector("input[type='radio'][name$='[medio]']:checked")
    if (!elegido) return

    const efectivo = elegido.value === "efectivo"

    this.unidadTargets.forEach((unidad) => { unidad.textContent = elegido.dataset.unidad })

    if (this.hasConReferenciaTarget) this.conReferenciaTarget.hidden = efectivo
    if (this.hasReferenciaTarget) {
      this.referenciaTarget.disabled = efectivo
      this.referenciaTarget.required = !efectivo
    }

    if (this.hasComprobanteTarget) this.comprobanteTarget.required = !efectivo
    if (this.hasComprobanteOpcionalTarget) this.comprobanteOpcionalTarget.hidden = !efectivo
  }
}
