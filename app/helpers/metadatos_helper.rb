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
#                                    │ Desde 39 $ al mes…       │
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

  # ⚠️ El precio SALE DE `Subscription::PLANES` y no escrito a mano. Decía
  # «Desde 25 $ al mes» y llevaba meses mintiendo: los planes subieron a
  # 30/60/90 en septiembre y esta cadena se quedó donde estaba. Lo cuida
  # `los_precios_de_un_solo_lugar_test`.
  #
  # ⚠️ Y sí lleva el precio, a diferencia del hero de la portada, que lo perdió
  # a propósito. No es una contradicción: en el hero el precio lo lee alguien
  # que todavía no preguntó nada; en un resultado de búsqueda lo lee quien
  # buscó justamente esto. Y en un mercado donde NINGÚN competidor publica sus
  # precios, el número es lo que distingue el resultado.
  def self.descripcion_base
    "Notas, boletines y constancias desde el teléfono. " \
      "Un sistema pensado para el colegio que hoy lleva todo en Word. " \
      "Desde #{Subscription::PLANES.dig(:basico, :precio)} $ al mes."
  end

  # Cada vista puede poner lo suyo con `content_for :titulo` / `:descripcion`.
  # Sin eso, se usa el de la marca — nunca queda vacío ni dice "Untitled".
  def titulo_de_pagina
    propio = content_for(:titulo)
    propio.present? ? "#{propio} · SIGA" : TITULO_BASE
  end

  def descripcion_de_pagina
    content_for(:descripcion).presence || MetadatosHelper.descripcion_base
  end

  # Las etiquetas sociales solo tienen sentido donde alguien puede llegar sin
  # cuenta. Adentro del panel, un `og:` es peso muerto: nadie va a compartir la
  # lista de alumnos de su colegio en Twitter, y si lo hiciera, el enlace pide
  # login igual.
  def pagina_publica?
    !user_signed_in?
  end

  # ── Lo que hace falta para que Google entienda la página ──────────────────

  # ⚠️ El canonical va SIN query string, y eso es todo su trabajo.
  #
  # `/?utm_source=whatsapp`, `/?fbclid=…` y `/` son la MISMA página, y para un
  # buscador son tres — el texto se reparte entre las tres y ninguna rankea.
  #
  # ⚠️ Y se arma con `SIGA_HOST`, no con `request.host`: el día que el mismo
  # contenido responda en dos dominios —el de SIGA y el propio de un colegio
  # del plan dedicado— el canonical tiene que nombrar UNO.
  def url_canonica
    host = ENV.fetch("SIGA_HOST", request.host_with_port)
    protocolo = host.start_with?("localhost", "127.0.0.1") ? "http" : "https"
    "#{protocolo}://#{host}#{request.path}"
  end

  # Qué NO debe aparecer en un resultado de búsqueda. No es lo mismo que «pide
  # login»: ahí Google no entra y no hace falta decírselo.
  #
  #   /verificar/CÓDIGO   el documento de UNA persona. Indexarlo pone el
  #                       boletín de un niño en Google.
  #   /planteles          el autocompletado del registro: un fragmento de HTML
  #                       sin cabecera ni sentido propio.
  #
  # ⚠️ `/verificar` A SECAS SÍ se indexa: alguien busca «verificar una
  # constancia de SIGA» y tiene que encontrar el formulario. Lo que se esconde
  # es la página que ya trae un código.
  RASTROS_QUE_NO_SE_INDEXAN = [ %r{\A/verificar/.+}, %r{\A/planteles} ].freeze

  def esconder_de_los_buscadores?
    return true unless pagina_publica?

    RASTROS_QUE_NO_SE_INDEXAN.any? { |patron| request.path.match?(patron) }
  end

  # La ficha estructurada de la portada.
  #
  # ⚠️ Es lo que permite que un resultado de búsqueda muestre el precio y la
  # valoración en vez de solo un título y dos líneas. Sin esto, SIGA es texto;
  # con esto, es un producto con precio, idioma y país.
  #
  # ⚠️ Los precios salen de `Subscription::PLANES`, igual que la portada y el
  # cobro. Tres copias del mismo número son dos oportunidades de mentir.
  #
  # ⚠️ Va en `<script type="application/ld+json">`, que NO es JavaScript: es un
  # bloque de datos, y por eso la CSP no lo bloquea aunque no lleve nonce.
  def ficha_estructurada
    {
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => "SIGA",
      "alternateName" => "Sistema Integrado de Gestión Académica",
      "applicationCategory" => "EducationalApplication",
      "applicationSubCategory" => "Sistema de gestión académica",
      "operatingSystem" => "Web",
      "inLanguage" => "es-VE",
      "url" => url_canonica,
      "description" => MetadatosHelper.descripcion_base,
      "audience" => {
        "@type" => "EducationalAudience",
        "educationalRole" => "administrator",
        "audienceType" => "Colegios de educación inicial, primaria y media de Venezuela"
      },
      "areaServed" => { "@type" => "Country", "name" => "Venezuela" },
      "offers" => Subscription::PLANES.each_value.map do |datos|
        { "@type" => "Offer",
          "name" => "Plan #{datos[:etiqueta]}",
          "price" => datos[:precio].to_s,
          "priceCurrency" => "USD",
          "description" => "Hasta #{datos[:hasta]} alumnos inscritos",
          "priceSpecification" => {
            "@type" => "UnitPriceSpecification",
            "price" => datos[:precio].to_s,
            "priceCurrency" => "USD",
            "billingIncrement" => 1,
            "unitCode" => "MON"
          } }
      end
    }
  end
end
