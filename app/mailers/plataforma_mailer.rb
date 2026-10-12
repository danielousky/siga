# Los avisos que le llegan al equipo de SIGA, no al colegio (MOR-158).
#
# ## Por qué existe este correo
#
# Con el registro abierto, un colegio entra sin que nadie de SIGA se entere. Eso
# es exactamente lo que se quería —que la persona siga sin depender de nadie—
# pero deja al equipo comercial ciego: un cliente potencial acaba de cargar su
# matrícula completa y nadie lo sabe.
#
# El correo resuelve las dos mitades: la persona no espera a nadie, y SIGA se
# entera en el momento.
class PlataformaMailer < ApplicationMailer
  # Los montos de un pago, escritos como en todas las pantallas: «109.586,17 Bs».
  helper PagosHelper, ApplicationHelper

  # ⚠️ A quién le llega. Va por variable de entorno y NO a una dirección escrita
  # en el código: el día que haya alguien más en el equipo, cambiarlo no puede
  # exigir un despliegue.
  #
  # Sin la variable NO se manda nada y no falla: un aviso interno que no sale no
  # puede tumbar el registro de un cliente.
  def self.destinatario = ENV["SIGA_AVISOS_EMAIL"].presence

  def colegio_registrado(colegio, usuario)
    return if self.class.destinatario.blank?

    @colegio = colegio
    @usuario = usuario
    @cuando = Time.current

    mail to: self.class.destinatario,
         subject: "Nuevo colegio en SIGA: #{colegio.name}"
  end

  # Un colegio reportó el pago de su suscripción (spec `del-registro-al-cobro`,
  # § 5.5): hay que mirarlo en `/siga/cartera` y validarlo o rechazarlo.
  #
  # ⚠️ Es lo que hace que reportar no sea un formulario al vacío. Sin este
  # correo el pago espera hasta que alguien abra la Cartera por otra razón, y
  # el colegio que pagó sigue sin poder calificar.
  def pago_reportado(pago)
    return if self.class.destinatario.blank?

    @pago = pago
    @colegio = pago.school

    mail to: self.class.destinatario,
         subject: "Pago por validar: #{@colegio.name} · #{ApplicationController.helpers.importe_del_pago(pago)}"
  end
end
