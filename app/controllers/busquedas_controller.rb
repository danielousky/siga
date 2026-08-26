# El buscador global (MOR-149).
#
# Responde el fragmento de resultados que pinta el modal de `⌘K`. No devuelve una
# página: es un `<turbo-frame>` que se reemplaza mientras la persona escribe.
#
# ## Por qué no hay JSON
#
# Un endpoint JSON obligaría a escribir en JavaScript el mismo HTML que ya sabe
# escribir Haml —el avatar, el icono, el resaltado— y a mantener las dos copias
# sincronizadas. Con Turbo, el servidor manda HTML y el navegador lo pega: es
# menos código y no hay dos verdades.
class BusquedasController < ApplicationController
  def show
    @termino = params[:q].to_s.strip
    @resultados = BusquedaGlobal.para(@termino, rutas: self)
    @suficiente = @termino.length >= BusquedaGlobal::MINIMO

    # Sin layout: lo que se devuelve es el contenido del frame, no una pantalla.
    render partial: "busquedas/resultados",
           locals: { resultados: @resultados, termino: @termino, suficiente: @suficiente }
  end
end
