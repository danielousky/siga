# En el colegio de muestra NO sale ningún correo (spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
# Las personas de la muestra son inventadas, pero sus correos tienen forma de
# correo: `director.bolivar@mail.com` puede ser el buzón de alguien de verdad.
# Y quien visita la muestra puede escribir CUALQUIER dirección en la ficha de un
# representante y tocar «Enviar»: con el correo saliendo, la muestra sería una
# manera de mandarle mensajes a un desconocido con la firma de SIGA.
#
# ## Por qué un interceptor y no «no configurar el SMTP»
#
# No configurarlo es una ausencia, y una ausencia la corrige cualquiera que
# copie las variables del sitio de verdad para «arreglar» que no llega nada.
# Esto es una regla escrita: se puede leer, y se puede probar.
#
# Se engancha en `config/application.rb` y corre en todo entorno; fuera de la
# muestra no hace nada.
class NadaSaleDeLaMuestra
  def self.delivering_email(mensaje)
    mensaje.perform_deliveries = false if Muestra.activa?
  end
end
