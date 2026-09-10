# Descartar el enlace de acceso que está a la vista.
#
# ⚠️ Existe porque el código NO vive en el `flash`: ahí duraba un render y el
# redirect de Turbo produce dos —el segundo repintaba la pantalla sin él—. En la
# sesión sobrevive a la recarga, y por eso hace falta decir cuándo se va.
#
# Un controller propio y no un método en cada rol: en la sesión hay UN código,
# sea de un representante, un profesor o un administrador.
class CodigosALaVistaController < ApplicationController
  def destroy
    session.delete(:codigo_a_la_vista)

    # ⚠️ De vuelta a donde estaba: el botón vive en la ficha de la persona, y
    # `redirect_back` sin destino manda al panel, que no es donde uno estaba.
    redirect_back fallback_location: root_path
  end
end
