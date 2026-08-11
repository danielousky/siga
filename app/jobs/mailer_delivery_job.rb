# Todo `deliver_later` pasa por acá.
#
# Sin esta clase el correo se entregaría con `ActionMailer::MailDeliveryJob`, que
# no hereda de `ApplicationJob` y por lo tanto no lleva colegio: un mailer que
# busque al representante de un alumno se encontraría con cero filas.
#
# Va como `colegio_opcional`, no como obligatorio, porque **el correo de "olvidé
# mi contraseña" se manda sin sesión**. En ese momento no hay usuario autenticado
# ni inquilino que poner, y exigirlo rompería el único flujo de correo que la app
# tiene hoy. Sigue sin ver datos de ningún colegio: sin contexto, el RLS devuelve
# cero filas.
#
# Ver MOR-88.
class MailerDeliveryJob < ActionMailer::MailDeliveryJob
  include CarriesSchool

  colegio_opcional
end
