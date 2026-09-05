# Cambiar el nivel que se está mirando.
#
# Gemelo de `AnioEscolarController`, y POST por la misma razón: cambia el estado
# de la sesión, y eso no se hace con un GET — un enlace se puede prefetchear,
# cachear o disparar desde otra pestaña.
class NivelEscolarController < ApplicationController
  before_action :require_puede_elegir!

  def update
    session[LlevaElNivel::CLAVE] = pedido

    redirect_back fallback_location: dashboard_path_for_user
  end

  private

  # ⚠️ Se guarda el valor CRUDO, sin comprobar acá que el colegio dicte ese
  # nivel. La comprobación la hace `LlevaElNivel` al leerlo, contra
  # `niveles_para_elegir` — que sale de los grados que el colegio tiene. Un
  # nivel que no dicta no está en la lista y cae a «todos».
  #
  # Validarlo también acá sería la misma pregunta contestada dos veces, y la
  # segunda copia es la que se olvida de actualizar.
  def pedido = params[:nivel].to_s

  # ⚠️ La MISMA pregunta que hace la barra: `hay_nivel_que_elegir?`, no
  # `puede_elegir_nivel?`.
  #
  # Las dos existen y significan cosas distintas: `puede_elegir_nivel?` es el
  # permiso, y `hay_nivel_que_elegir?` es permiso **más** que haya más de un
  # nivel entre qué elegir. La barra usa la segunda, así que el controller tiene
  # que usar la segunda — con la primera, un profesor de un solo nivel no ve
  # botones pero un POST a mano sí le cambia la sesión, y termina con un filtro
  # puesto que ninguna pantalla le muestra ni le deja quitar.
  #
  # Acá había además una tercera copia escrita a mano —«administrador? ||
  # equipo_de_siga?»— y al ampliar el criterio (MOR-223) quedó atrás: la barra
  # dibujaba los botones y este controller rechazaba el POST. Es la clase de
  # desparejo que ya documenta `MenuHelper#puede_ver_administradores?`: «la
  # MISMA lista que los permisos, no una copia».
  def require_puede_elegir!
    return if hay_nivel_que_elegir?

    redirect_back fallback_location: dashboard_path_for_user,
                  alert: "El nivel lo define la dirección."
  end
end
