# El registro abierto (MOR-158).
#
# ## Qué cambia respecto de `MOR-101`
#
# El registro se había cerrado porque `users.email` es único en TODA la
# plataforma: cualquiera puede quemar el correo de un profesor real
# registrándolo antes que su colegio. Eso sigue siendo cierto.
#
# La decisión de producto es aceptarlo: **facilidad y velocidad de registro por
# encima de la seguridad**, mientras el acceso sea compartir el enlace a mano.
#
# ⚠️ Lo que hace tolerable el riesgo es el aislamiento, no la confianza:
# registrarse **crea siempre un colegio nuevo** y nunca se une a uno existente,
# así que el daño máximo de un abuso es una fila que no ve nada de nadie. Ese
# invariante vive en `MiColegioController` y no se puede aflojar sin volver a
# discutir esto.
class RegistrosController < Devise::RegistrationsController
  # Lo mínimo para que una persona EXISTA en este sistema.
  #
  # ⚠️ La cédula no es opcional y no es burocracia: `User` exige documento o
  # cédula escolar (`MOR-138`), porque es lo que identifica a una PERSONA en toda
  # la plataforma y lo que evita que dos «María Pérez» sean la misma fila. Sin
  # ella el registro devuelve 422 y la pantalla no dice por qué.
  #
  # No es fricción real: quien se registra es un director de colegio venezolano,
  # tiene su cédula a mano, y el sistema se la iba a pedir igual el día del
  # primer documento.
  PERMITIDOS = %i[first_name last_name document document_type
                  email password password_confirmation].freeze

  before_action :configure_permitted_parameters

  # Después de registrarse hay UNA sola cosa que hacer: crear su colegio.
  def after_sign_up_path_for(_recurso) = nuevo_mi_colegio_path

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: PERMITIDOS)
  end
end
