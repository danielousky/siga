# Las piezas con las que se escribe un correo de SIGA.
#
# Daniel, 5 de octubre de 2026, con el de «recuperar contraseña» abierto en
# Gmail: *«Esto no parece para nada un correo institucional de SIGA. Parece
# cualquier cosa.»* Siete de los ocho correos salían sin cabecera ni pie.
#
# ## Por qué son helpers y no estilos escritos en cada plantilla
#
# Un correo necesita los estilos EN LÍNEA —Gmail descarta buena parte de un
# `<style>` y Outlook dibuja con el motor de Word— así que cada botón son seis
# líneas de tabla. Escritas en ocho plantillas, se separan solas.
#
# ⚠️ Y hay dos plantillas que NO pueden llevar un `style=`: las de Devise viven
# en `devise/mailer/`, fuera de la excepción de `sistema_de_diseno_test`. Con el
# botón y la nota como helpers, esas plantillas quedan en contenido puro.
#
# ## Los colores y las letras son los del sitio
#
# Spec: `docs/specs/correos-con-identidad.md`.
module CorreoHelper
  TINTA = "#07142f".freeze   # cabecera y pie · `--ink`, el azul de la portada
  MARCA = "#1e4a7a".freeze   # títulos y botones · `--brand-primary`
  CIELO = "#7cc0ff".freeze   # la franja y los enlaces sobre oscuro · `--cielo`
  FONDO = "#e8eef5".freeze   # donde va el mensaje · `--brand-subtle`
  PAPEL = "#faf8f5".freeze   # lo que rodea al correo · `--surface-canvas`
  SUAVE = "#a9c4de".freeze   # el texto secundario sobre oscuro

  # ⚠️ Las pilas de la APP (`--font-serif`, `--font-sans`), sin descargar nada.
  # Gmail ignora las tipografías web, y Outlook clásico, al no encontrarlas, cae
  # en Times New Roman: con la pila del sistema el correo se ve igual en todos.
  # Helvetica y Arial van al final para Outlook, que no conoce las de Apple.
  SERIF = "'Iowan Old Style','Palatino Linotype',Palatino,Georgia,'Times New Roman',serif".freeze
  SANS  = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif".freeze

  # El lado de un logo dentro de su ficha blanca, en píxeles.
  LADO_DEL_LOGO = 48

  # La miniatura del escudo: el doble de lo que se muestra, para que no salga
  # borrosa en una pantalla de alta densidad.
  MINIATURA = { resize_to_limit: [ 128, 128 ], format: :png }.freeze

  # ── Lo que escribe una plantilla ─────────────────────────────────────────

  def titulo_de_correo(texto)
    content_tag :h1, texto,
                style: "margin:0 0 18px; font-family:#{SERIF}; font-size:24px; line-height:1.25; " \
                       "font-weight:700; color:#{MARCA};"
  end

  def boton_de_correo(texto, url)
    render "layouts/mailer/boton", texto: texto, url: url
  end

  # Lo que se dice en voz baja: «si no fue usted, ignore este correo».
  def nota_de_correo(&bloque)
    render "layouts/mailer/nota", contenido: capture(&bloque)
  end

  # ── Las imágenes ─────────────────────────────────────────────────────────
  #
  # ⚠️ Direcciones PERMANENTES. Un correo vive años en una bandeja: una imagen
  # con la huella de un despliegue en el nombre (`logo-3f9a….png`) desaparece
  # con el siguiente, y el correo viejo queda con un recuadro roto. Por eso el
  # logo de SIGA está en `public/correo/` y no pasa por los assets.

  def logo_de_siga_para_correo = "#{root_url}correo/siga.png"

  # La dirección de la miniatura del escudo, o `nil` si el colegio no tiene.
  #
  # ⚠️ Solo se ARMA la dirección. La miniatura la procesa Active Storage la
  # primera vez que alguien la pide, en su propio controlador y fuera de la
  # transacción de la petición. Pedirle acá `.processed` es el `IOError: closed
  # stream` de «Descargar las listas»: una variante nueva se guarda al confirmar
  # la transacción, y en SIGA la transacción es la petición entera
  # (`CLAUDE.md § 1`).
  def escudo_para_correo(colegio)
    return nil unless colegio&.logo&.attached?

    rails_storage_proxy_url(colegio.logo.variant(MINIATURA))
  rescue StandardError
    nil   # Un escudo que no se puede servir no tumba un correo: sale el nombre.
  end

  # Cuánto mide el escudo dentro de su ficha, sin deformarlo.
  #
  # Un escudo no es cuadrado —casi todos son más altos que anchos— y Outlook
  # necesita el ancho y el alto escritos: sin ellos dibuja la imagen a su tamaño
  # real. Salen de las medidas que Active Storage guarda al analizar el archivo.
  #
  # ⚠️ Si no se pueden saber, cuadrado: un escudo algo apretado es mejor que
  # ninguno, y mucho mejor que un correo que no sale.
  def medidas_del_escudo(colegio, caja = LADO_DEL_LOGO)
    blob = colegio.logo.blob
    blob.analyze unless blob.analyzed?

    ancho, alto = blob.metadata.values_at("width", "height").map(&:to_f)
    return [ caja, caja ] unless ancho.positive? && alto.positive?

    escala = caja / [ ancho, alto ].max
    [ (ancho * escala).round, (alto * escala).round ]
  rescue StandardError, LoadError
    [ caja, caja ]
  end

  # Un logo sobre su ficha blanca.
  #
  # ⚠️ La ficha no es adorno: un escudo puede venir como JPG, con su rectángulo
  # blanco alrededor, o como PNG con letras oscuras. Sobre el azul de la
  # cabecera, el primero se vería como un parche y el segundo no se leería.
  def ficha_de_logo(direccion, alt, ancho: LADO_DEL_LOGO, alto: LADO_DEL_LOGO)
    render "layouts/mailer/ficha", direccion: direccion, alt: alt, ancho: ancho, alto: alto
  end

  # ── Los datos del colegio ────────────────────────────────────────────────

  # Lo que va bajo el nombre, en la cabecera: como en un boletín.
  def datos_del_colegio(colegio)
    [ colegio.location, (("DEA #{colegio.dea_code}") if colegio.dea_code.present?) ].compact_blank.join(" · ")
  end

  # Lo que va en el pie: cómo ubicarlo.
  def contacto_del_colegio(colegio)
    [ colegio.direccion, colegio.telefono ].compact_blank.join(" · ")
  end

  # ── El enlace de avisos ──────────────────────────────────────────────────
  #
  # ElasticEmail le agrega a TODO correo su enlace de baja, también por SMTP; en
  # los transaccionales lo rotula «MANAGE NOTIFICATIONS», en inglés y centrado
  # al pie. No se apaga desde el código. Lo que sí respeta: si el cuerpo ya trae
  # su etiqueta `{unsubscribe}`, usa ese enlace y no agrega el suyo.
  #
  # ⚠️ Solo cuando el correo sale por ElasticEmail. Con otro proveedor nadie
  # reemplaza la etiqueta, y el enlace llevaría a «{unsubscribe}», tal cual.
  def sale_por_elastic_email? = ENV["SMTP_ADDRESS"].to_s.include?("elasticemail")

  def enlace_de_avisos(estilo: nil)
    return nil unless sale_por_elastic_email?

    link_to "Administrar avisos", "{unsubscribe}", style: estilo
  end
end
