# Cambiar el año escolar que se está mirando (MOR-165).
#
# ## Por qué es un POST y no un enlace
#
# Cambia el estado de la sesión, y eso no se hace con un GET: un enlace se puede
# prefetchear, cachear o disparar desde otra pestaña. Cambiar de año escolar
# afecta a todo lo que la persona ve después.
class AnioEscolarController < ApplicationController
  before_action :require_puede_elegir!

  def update
    session[LlevaElAnioEscolar::CLAVE] = pedido

    redirect_back fallback_location: dashboard_path_for_user
  end

  private

  # ⚠️ Se guarda el id CRUDO, sin comprobar acá que el año exista.
  #
  # La comprobación la hace `LlevaElAnioEscolar` al leerlo, buscando con el
  # `default_scope` de `SchoolScoped`: un id de otro colegio no encuentra nada y
  # cae al valor por defecto. Validarlo también acá sería la misma pregunta
  # contestada dos veces, y la segunda copia es la que se olvida de actualizar.
  def pedido
    params[:id] == LlevaElAnioEscolar::TODOS ? LlevaElAnioEscolar::TODOS : params[:id].to_s
  end

  def require_puede_elegir!
    return if administrador? || equipo_de_siga?

    # Un profesor no elige año: ve el que está cursando. Ver el concern.
    redirect_back fallback_location: dashboard_path_for_user,
                  alert: "El año escolar lo define la dirección."
  end
end
