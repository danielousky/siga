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
  # ⚠️ La cédula ya NO se pide acá (`MOR-196`). `User` exige documento o cédula
  # escolar (`MOR-138`) porque una persona sin identificador no puede aparecer
  # en una planilla del MPPE — pero quien acaba de registrarse no aparece en
  # ninguna: no tiene colegio, ni alumnos, ni documentos que firmar. Se le pide
  # el día que haga falta. Ver `User#se_registro_solo?`.
  PERMITIDOS = %i[first_name last_name email password password_confirmation].freeze

  before_action :configure_permitted_parameters

  # Después de registrarse hay UNA sola cosa que hacer: crear su colegio.
  def after_sign_up_path_for(_recurso) = nuevo_mi_colegio_path

  # ⚠️ El correo de bienvenida sale ACÁ y no en un `after_create` del modelo
  # (`MOR-196`): `User` se crea también desde el importador —360 de una vez— y
  # desde el alta que hace el colegio, y ninguno de esos casos manda esto. Lo
  # que dispara el correo es HABERSE REGISTRADO, no haber nacido una fila.
  #
  # `deliver_later` y no `deliver_now`: si ElasticEmail está lento o caído, lo
  # que no puede pasar es que la persona se quede mirando el formulario. Se
  # registró; el correo llega cuando llegue.
  def create
    super

    BienvenidaMailer.cuenta_creada(resource).deliver_later if resource.persisted?
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: PERMITIDOS)
  end
end
