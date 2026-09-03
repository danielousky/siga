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

  def require_puede_elegir!
    return if administrador? || equipo_de_siga?

    redirect_back fallback_location: dashboard_path_for_user,
                  alert: "El nivel lo define la dirección."
  end
end
