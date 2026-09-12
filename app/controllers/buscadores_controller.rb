# Lo que leen los buscadores: `robots.txt` y `sitemap.xml`.
#
# ## ⚠️ Por qué son un controller y no dos archivos en `public/`
#
# `robots.txt` tiene que decir dónde está el sitemap, y esa línea lleva el HOST
# completo. El host de SIGA no es una constante: es `SIGA_HOST`, una variable de
# entorno, porque el mismo código corre en desarrollo, en el servidor de prueba
# y en producción. Un `public/robots.txt` escrito a mano apuntaría para siempre
# al host de quien lo escribió.
#
# El sitemap, además, va a crecer: hoy son cuatro URL fijas, y el día que se
# publique el directorio de planteles son miles que salen de la base.
#
# ⚠️ Y por eso se BORRÓ `public/robots.txt`. Rails sirve lo estático ANTES de
# consultar las rutas, así que mientras ese archivo existiera —el de plantilla,
# con un comentario y nada más— la ruta no se alcanzaba nunca. No fallaba: la
# petición devolvía 200 con el archivo vacío de siempre.
class BuscadoresController < ApplicationController
  skip_before_action :authenticate_user!

  # ⚠️ Lo que se PROHÍBE no es «lo que pide login» —ahí Google no entra igual—
  # sino lo que responde 200 sin cuenta y no debe aparecer en un resultado:
  #
  #     /verificar/CÓDIGO   es el documento de una persona
  #     /planteles          es el autocompletado del registro, un fragmento
  #     /salud · /up        son sondas de monitoreo
  #
  # Y `Disallow:` con el prefijo alcanza a `/verificar/ABC123` sin tocar
  # `/verificar` a secas, que SÍ conviene indexar: alguien busca «verificar una
  # constancia de SIGA» y tiene que encontrar el formulario.
  def robots
    render plain: <<~TXT, content_type: "text/plain"
      User-agent: *
      Allow: /
      Disallow: /verificar/
      Disallow: /planteles
      Disallow: /users/
      Disallow: /siga
      Disallow: /salud
      Disallow: /up

      Sitemap: #{url_de("/sitemap.xml")}
    TXT
  end

  # ⚠️ Acá NO va ni una pantalla del panel, y no es solo porque pidan login: un
  # sitemap con `/alumnos`, `/boletines` y `/importaciones` le regala a
  # cualquiera el mapa exacto de la aplicación.
  def mapa
    render xml: <<~XML, content_type: "application/xml"
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{PUBLICAS.map { |ruta, prioridad| entrada(ruta, prioridad) }.join("\n")}
      </urlset>
    XML
  end

  private

  # Las públicas de verdad, con su prioridad relativa. El registro va tan alto
  # como la portada a propósito: es la conversión que se busca.
  PUBLICAS = {
    "/" => "1.0",
    "/registrarse" => "1.0",
    "/demo_requests/new" => "0.8",
    "/verificar" => "0.5"
  }.freeze

  def entrada(ruta, prioridad)
    "  <url><loc>#{url_de(ruta)}</loc><priority>#{prioridad}</priority></url>"
  end

  # ⚠️ Sale de `SIGA_HOST` y no de `request.host`: si mañana el mismo contenido
  # responde en dos dominios —el de SIGA y el propio de un colegio del plan
  # dedicado— el sitemap tiene que nombrar UNO, o son dos sitios con el mismo
  # texto compitiendo entre ellos.
  def url_de(ruta)
    host = ENV.fetch("SIGA_HOST", request.host_with_port)
    protocolo = host.start_with?("localhost", "127.0.0.1") ? "http" : "https"
    "#{protocolo}://#{host}#{ruta}"
  end
end
