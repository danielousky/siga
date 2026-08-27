# El buscador global (MOR-149).
#
# Responde el fragmento de resultados que pinta el modal de `⌘K`. No es una
# página: es el pedazo que el controlador de Stimulus pega mientras se escribe.
#
# ## Por qué no hay JSON
#
# Un endpoint JSON obligaría a escribir en JavaScript el mismo HTML que ya sabe
# escribir Haml —el avatar, el icono, el resaltado— y a mantener las dos copias
# sincronizadas. Así el servidor manda HTML y el navegador lo pega: es menos
# código y no hay dos verdades.
#
# ⚠️ **Y NO va envuelto en un `<turbo-frame>`**, aunque parezca el lugar obvio
# para uno. Un enlace de adentro de un frame navega DENTRO del frame, y abrir un
# resultado es ir a la ficha completa de un alumno. Costó dos bugs de «Content
# missing»; está explicado en `busquedas/_resultados.html.haml`.
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
