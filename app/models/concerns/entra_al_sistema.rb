# El rol que SÍ necesita poder entrar (MOR-142).
#
# Desde `MOR-142` el correo es opcional en `users`: un alumno de 2do grado no es
# una cuenta, es un registro. Pero "opcional en el esquema" no es "opcional para
# todos" —un profesor sin correo no puede cargar notas, y un director sin correo
# no tiene forma de recuperar su contraseña, porque el mailer de Devise manda
# justamente ahí—.
#
# La regla vive en el ROL y no en `User` porque es el rol el que sabe si esta
# persona TRABAJA con el sistema o solamente aparece en él:
#
#     Student         nunca      · el que consulta es su representante
#     Representative  opcional   · entra si lo tiene; si no, el colegio se lo pide
#     Teacher         obligado
#     Admin           obligado
#     SigaStaff       obligado
module EntraAlSistema
  extend ActiveSupport::Concern

  included do
    validate :el_usuario_tiene_correo
  end

  private

  # `user.blank?` se salta la validación a propósito: de eso ya se queja el
  # `belongs_to`, y dos errores por la misma causa confunden a quien llena el
  # formulario.
  def el_usuario_tiene_correo
    return if user.blank? || user.email.present?

    errors.add(:base, "Hace falta un correo electrónico: este rol entra al sistema")
  end
end
