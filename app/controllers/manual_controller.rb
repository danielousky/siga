# El manual de SIGA, público y compartible.
#
#     /manual        las 37 funciones con sus capturas
#     /manual.pdf    lo mismo, para imprimir o mandar por WhatsApp
#
# ## ⚠️ Por qué NO son dos archivos en `public/`
#
# `config.public_file_server.headers` le pone a todo lo de ahí un `max-age` de
# UN AÑO. Es correcto para un asset con huella en el nombre —`application-a1b2`
# no cambia nunca— y es veneno para un documento que se corrige: el navegador
# de un colegio se quedaría con el manual de hoy hasta 2027, sin manera de
# forzarlo.
#
# Acá el caché es de una hora: suficiente para que no pese, corto para que una
# corrección llegue el mismo día.
#
# ⚠️ Las CAPTURAS sí viven en `public/manual/capturas/` y se sirven estáticas:
# son las mismas cuarenta y nueve imágenes, no cambian de contenido sin cambiar
# de manual, y así 2,7 MB no pasan por Ruby.
#
# ## ⚠️ Y por qué el HTML no lleva las imágenes adentro
#
# La versión de una pieza —la que se publica como artifact y la que imprime el
# PDF— las lleva en base64 y pesa 3,5 MB. En un colegio con conexión mala eso
# son 3,5 MB que hay que bajar ENTEROS antes de ver la primera línea. Servido
# aparte, el texto aparece de una y las capturas van llegando con `lazy`.
class ManualController < ApplicationController
  skip_before_action :authenticate_user!
  skip_around_action :con_el_colegio_de_la_sesion

  PUBLICADO = Rails.root.join("docs", "manual", "publicado")
  CACHE = 1.hour

  # ⚠️ Una sola acción, y el formato decide. `/manual.pdf` es esta misma ruta
  # con `format: :pdf`: el punto es el separador del formato en Rails, siempre.
  #
  # ⚠️ Y el PDF va `inline`, no `attachment`: en el teléfono —que es desde donde
  # lo va a abrir la mitad de la gente— un adjunto se baja a una carpeta que
  # nadie encuentra. Quien lo quiera guardar tiene el botón de su visor.
  def show
    if request.format.pdf?
      entregar(PUBLICADO.join("manual-de-siga.pdf"), "application/pdf")
    else
      entregar(PUBLICADO.join("index.html"), "text/html")
    end
  end

  private

  def entregar(archivo, tipo)
    raise ActionController::RoutingError, "Todavía no hay manual" unless archivo.exist?

    expires_in CACHE, public: true
    send_file archivo, type: tipo, disposition: "inline"
  end
end
