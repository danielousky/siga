# Título, descripción y tarjeta social de cada página (MOR-135).
#
# ## Por qué esto importa más de lo que parece
#
# El canal de venta de SIGA no es Google: es **una directora que le reenvía el
# enlace a otra directora por WhatsApp**. Ese reenvío es la única impresión que
# existe antes del clic, y hasta hoy no había ni una etiqueta `og:` en todo el
# repo — así que WhatsApp mostraba una URL pelada, sin imagen, sin título y sin
# una sola palabra de qué es esto.
#
#     ANTES                          AHORA
#     ─────                          ─────
#     siga.example.com               ┌──────────────────────────┐
#     (y ya)                         │  [ tarjeta 1200×630 ]    │
#                                    ├──────────────────────────┤
#                                    │ SIGA · Notas, boletines  │
#                                    │ y constancias desde el   │
#                                    │ teléfono                 │
#                                    │ Desde 25 $ al mes…       │
#                                    └──────────────────────────┘
#
# ## Las dos trampas
#
# 1. **`og:image` y `og:url` tienen que ser absolutas.** WhatsApp, Telegram y
#    Facebook piden la imagen desde SUS servidores, no desde el navegador de
#    quien la ve: una ruta relativa no resuelve contra nada. Por eso `asset_url`
#    y `request.original_url`, no `asset_path`.
# 2. **La descripción es lo que se lee, no lo que se indexa.** Va escrita para
#    una persona que la mira dos segundos en una lista de chats, no para un
#    buscador: sin palabras clave apiladas y sin la palabra "solución".
module MetadatosHelper
  TITULO_BASE = "SIGA · Gestión académica para colegios de Venezuela".freeze

  DESCRIPCION_BASE = "Notas, boletines y constancias desde el teléfono. " \
                     "Un sistema pensado para el colegio que hoy lleva todo en Word. " \
                     "Desde 25 $ al mes.".freeze

  # Cada vista puede poner lo suyo con `content_for :titulo` / `:descripcion`.
  # Sin eso, se usa el de la marca — nunca queda vacío ni dice "Untitled".
  def titulo_de_pagina
    propio = content_for(:titulo)
    propio.present? ? "#{propio} · SIGA" : TITULO_BASE
  end

  def descripcion_de_pagina
    content_for(:descripcion).presence || DESCRIPCION_BASE
  end

  # Las etiquetas sociales solo tienen sentido donde alguien puede llegar sin
  # cuenta. Adentro del panel, un `og:` es peso muerto: nadie va a compartir la
  # lista de alumnos de su colegio en Twitter, y si lo hiciera, el enlace pide
  # login igual.
  def pagina_publica?
    !user_signed_in?
  end
end
