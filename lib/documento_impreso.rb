# Un documento de SIGA impreso a PDF con Chrome sin ventana, y su copia en la
# carpeta madre, que es donde Daniel guarda lo que se entrega.
#
#     pdf = DocumentoImpreso.desde_html(html, Rails.root.join("docs/comercial/publicado/contrato.pdf"))
#     DocumentoImpreso.copiar_a_la_carpeta_madre(pdf, "CONTRATO DE PRESTACIÓN DE SERVICIOS.pdf")
#
# Es lo mismo que hace `docs/manual/a_pdf.sh`: Chrome imprime el HTML que se
# publica, y no hay una segunda versión que mantener.
#
# ⚠️ La UNA verdad vive en el repo y la carpeta madre recibe COPIAS (13 de
# octubre de 2026). Hasta ese día el contrato, «Aliados» y los diagramas ER
# vivían solo allá, sin nada que los mirara, y los cuatro se quedaron en los
# precios y el modelo de otros meses.
module DocumentoImpreso
  CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome".freeze

  # `/…/SIGA/APPS/siga` → `/…/SIGA`.
  CARPETA_MADRE = Rails.root.parent.parent

  module_function

  # `espera`: lo que Chrome le da a la página antes de imprimir, en
  # milisegundos. El diagrama ER lo dibuja Mermaid DESPUÉS de cargar, y sin
  # margen sale el texto crudo.
  def desde_html(html, destino, espera: 3_000)
    raise "No está Chrome en #{CHROME}: hace falta para imprimir el PDF." unless File.executable?(CHROME)

    destino = Pathname(destino)
    FileUtils.mkdir_p(destino.dirname)

    Tempfile.create([ "siga-documento", ".html" ]) do |pagina|
      pagina.write(html)
      pagina.flush
      exito = system(CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                     "--virtual-time-budget=#{espera}", "--timeout=#{espera + 60_000}",
                     "--print-to-pdf=#{destino}", "file://#{pagina.path}",
                     out: File::NULL, err: File::NULL)
      raise "Chrome no pudo imprimir #{destino.basename}" unless exito && destino.exist?
    end

    destino
  end

  # Copia el archivo a la carpeta madre —y a una subcarpeta, si se pide— solo si
  # existe: en el servidor y en el CI no hay carpeta madre, y no es un error.
  def copiar_a_la_carpeta_madre(archivo, nombre, subcarpeta: nil)
    carpeta = subcarpeta ? CARPETA_MADRE.join(subcarpeta) : CARPETA_MADRE
    return unless carpeta.directory? && CARPETA_MADRE.join("APPS").directory?

    destino = carpeta.join(nombre)
    FileUtils.cp(archivo, destino)
    destino
  end
end
