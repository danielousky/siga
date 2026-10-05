# El correo con el que alguien activa su acceso a SIGA (MOR-143).
#
# Es un mailer propio y no una plantilla más de Devise porque **no dice lo
# mismo**. El de Devise arranca con "alguien pidió cambiar su contraseña", y acá
# nadie pidió nada: el colegio dio de alta a esta persona y le está avisando.
# Recibir "¿pediste cambiar tu contraseña?" cuando uno nunca tuvo cuenta se lee
# como phishing, y con razón.
class AccesoMailer < ApplicationMailer
  def activacion(usuario, token, colegio)
    @usuario = usuario
    @colegio = colegio
    @url     = activar_url(token)
    @horas   = User::ACTIVACION_VALIDA_POR.in_hours.to_i
    a_nombre_de(colegio)

    mail to: @usuario.email,
         subject: "#{@colegio.name}: active su acceso a SIGA"
  end
end
