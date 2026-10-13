# Lo que SIGA le dice a un colegio sobre su suscripción (spec
# `docs/specs/del-registro-al-cobro.md`).
#
#     pago_validado    «su suscripción está activa hasta el 9 de noviembre»
#     pago_rechazado   «no pudimos validar su pago», con el motivo
#
# Esos dos le llegan a quien REPORTÓ el pago: es quien está esperando la
# respuesta. Y los tres de la escalera (§ 5.7), a quienes pagan en el colegio
# —dirección y finanzas—, porque nadie los pidió: los manda el calendario.
#
#     por_vencer       5 días antes: «vence el 9 de noviembre»
#     vencio           el día que vence: «le quedan 15 días»
#     solo_lectura     pasada la gracia: «su colegio quedó en solo lectura»
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
    @whatsapp = Setup.whatsapp_url("Hola, escribo por el pago de la suscripción de #{@colegio.name}.")

    mail to: @persona.email, subject: "No pudimos validar el pago de su suscripción a SIGA"
  end

  # ── La escalera (§ 5.7) ───────────────────────────────────────────────────
  #
  # ⚠️ Dicen lo que el colegio va a leer arriba de su pantalla, con las mismas
  # fechas: un correo que dice «vence el 9» y un aviso que dice «vence el 10»
  # son dos sistemas.
  #
  # ⚠️ Y ninguno amenaza. El colegio no pierde nada de lo que cargó en ningún
  # escalón, y cada correo lo dice: lo que se quiere es que pague, no que se
  # asuste y se vaya.

  def por_vencer(suscripcion)
    preparar(suscripcion)

    mail to: @destinatarios,
         subject: "Su suscripción a SIGA vence el #{I18n.l(suscripcion.vigente_hasta, format: :long)}"
  end

  def vencio(suscripcion)
    preparar(suscripcion)
    @hasta = suscripcion.fin_de_la_gracia

    mail to: @destinatarios,
         subject: "Su suscripción a SIGA venció: todo sigue funcionando hasta el #{I18n.l(@hasta, format: :long)}"
  end

  def solo_lectura(suscripcion)
    preparar(suscripcion)

    mail to: @destinatarios, subject: "#{@colegio.name} quedó en solo lectura en SIGA"
  end

  private

  def preparar(suscripcion)
    @suscripcion   = suscripcion
    @colegio       = suscripcion.school
    @cotizacion    = suscripcion.cotizacion
    @destinatarios = suscripcion.correos_de_quienes_pagan
    @url           = suscripcion_url
    @whatsapp      = Setup.whatsapp_url("Hola, escribo por la suscripción de #{@colegio.name}.")
  end
end
