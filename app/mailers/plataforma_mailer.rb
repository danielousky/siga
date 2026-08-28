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
end
