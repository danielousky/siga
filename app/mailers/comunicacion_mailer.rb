# El correo que el colegio le escribe a una familia (MOR-181).
#
# ## ⚠️ El remitente NO es el colegio, y no se puede cambiar
#
# ElasticEmail solo despacha correo cuyo remitente esté en un dominio
# VERIFICADO, y el único verificado es el de SIGA (ver `ApplicationMailer`).
# Mandar como `direccion@sucolegio.edu.ve` haría que el correo se rechace en el
# primer envío — o peor, que llegue a spam por fallar el SPF del colegio.
#
# La salida es el `reply_to`: **el correo sale de SIGA y la respuesta va a quien
# lo escribió**. Para la mamá el efecto es el correcto —contesta y le llega a la
# secretaria— y para el colegio no hay nada que configurar.
#
# El asunto lleva el nombre del colegio adelante porque es lo que hace que la
# familia lo reconozca en una bandeja llena.
class ComunicacionMailer < ApplicationMailer
  def mensaje_del_colegio(destinatario:, colegio:, remitente:, asunto:, cuerpo:)
    @cuerpo = cuerpo
    @colegio = colegio
    @remitente = remitente
    @destinatario = destinatario

    mail to: destinatario.email,
         reply_to: remitente.email.presence,
         subject: "#{colegio.name}: #{asunto}"
  end
end
