# Lo que SIGA le dice a un colegio sobre su suscripción (spec
# `docs/specs/del-registro-al-cobro.md`).
#
#     pago_validado    «su suscripción está activa hasta el 9 de noviembre»
#     pago_rechazado   «no pudimos validar su pago», con el motivo
#
# Le llegan a quien REPORTÓ el pago: es quien está esperando la respuesta.
#
# ⚠️ Son correos DE SIGA, no del colegio: SIGA le escribe a su cliente. Por eso
# no llaman `a_nombre_de` y salen con la cabecera de la plataforma.
#
# ⚠️ Y se encolan DENTRO del colegio (`Siga::PagosController`): el pago es una
# fila con RLS, y un trabajo que corre sin colegio no la encuentra.
class SuscripcionMailer < ApplicationMailer
  # Los montos, escritos como en todas las pantallas: «126,00 $», «109.586,17 Bs».
  helper PagosHelper, ApplicationHelper

  # Decisión 23 del spec: el colegio se entera de que ya puede calificar sin
  # tener que entrar a mirar ni escribir a preguntar.
  def pago_validado(pago)
    @pago     = pago
    @colegio  = pago.school
    @persona  = pago.reportado_por
    @url      = root_url

    mail to: @persona.email,
         subject: "Su suscripción a SIGA está activa hasta el #{I18n.l(pago.cubre_hasta, format: :long)}"
  end

  # El rechazo, con su motivo (§ 5.6): el colegio lo ve también en su pantalla,
  # pero quien reportó no tiene por qué estar mirándola.
  def pago_rechazado(pago)
    @pago     = pago
    @colegio  = pago.school
    @persona  = pago.reportado_por
    @url      = suscripcion_url
    @whatsapp = SigaSetting.actuales.whatsapp_url("Hola, escribo por el pago de la suscripción de #{@colegio.name}.")

    mail to: @persona.email, subject: "No pudimos validar el pago de su suscripción a SIGA"
  end
end
