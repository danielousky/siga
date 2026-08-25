# La maquinaria de las planillas en blanco que el colegio descarga (MOR-126).
#
# Es la mitad que suele faltar en un importador. Sin ella, "mándenos sus datos
# en Excel" deja a la secretaria adivinando qué columnas poner, y lo que llega
# hay que devolverlo. Con ella, la mayoría de los archivos llegan bien a la
# primera y el mapeo casi no hace falta.
#
# Dos hojas, y las dos importan:
#
#   LOS DATOS      los encabezados y tres filas de ejemplo, para copiar el
#                  formato en vez de leerlo.
#   INSTRUCCIONES  qué significa cada columna, si es obligatoria y cómo se
#                  escribe — que es lo que alguien busca cuando algo no le entra.
#
# Lo que cambia entre una planilla y otra son seis constantes; el libro, los
# estilos, el panel congelado y los anchos son los mismos. Cada subclase declara
# `COLUMNAS`, `EJEMPLOS`, `HOJA`, `PREFIJO`, `INTRO` y `ANTES_DE_ENVIAR`.
class PlantillaDeImportacion
  def initialize(colegio: nil)
    @colegio = colegio
  end

  def to_stream
    libro.to_stream
  end

  def nombre_de_archivo
    base = @colegio&.name.to_s.parameterize.presence || "siga"
    "#{self.class::PREFIJO}-#{base}.xlsx"
  end

  private

  def libro
    Axlsx::Package.new do |paquete|
      estilos(paquete.workbook)
      hoja_de_datos(paquete.workbook)
      hoja_de_instrucciones(paquete.workbook)
    end
  end

  def estilos(libro)
    @titulo = libro.styles.add_style(b: true, bg_color: "1F5C8B", fg_color: "FFFFFF",
                                     alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                     border: { style: :thin, color: "FFFFFF" })
    @obligatorio = libro.styles.add_style(b: true, bg_color: "8F3A1D", fg_color: "FFFFFF",
                                          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                                          border: { style: :thin, color: "FFFFFF" })
    @ejemplo = libro.styles.add_style(i: true, fg_color: "6B7280")
    @cabecera = libro.styles.add_style(b: true, sz: 12)
    @texto = libro.styles.add_style(alignment: { wrap_text: true, vertical: :top })
    @centrado = libro.styles.add_style(alignment: { horizontal: :center, vertical: :top })
  end

  def hoja_de_datos(libro)
    libro.add_worksheet(name: self.class::HOJA) do |hoja|
      columnas = self.class::COLUMNAS::TODAS

      # Las obligatorias van en otro color. Es más rápido de leer que cualquier
      # asterisco, y sobrevive a que alguien imprima la hoja.
      hoja.add_row(columnas.map(&:titulo),
                   style: columnas.map { |c| c.obligatorio? ? @obligatorio : @titulo },
                   height: 34)

      self.class::EJEMPLOS.each { |fila| hoja.add_row(fila, style: @ejemplo) }

      hoja.column_widths(*columnas.map { |c| ancho_de(c) })

      # Que los encabezados se queden a la vista al bajar por 360 filas.
      hoja.sheet_view.pane do |panel|
        panel.top_left_cell = "A2"
        panel.state = :frozen
        panel.y_split = 1
        panel.active_pane = :bottom_left
      end
    end
  end

  def hoja_de_instrucciones(libro)
    libro.add_worksheet(name: "Instrucciones") do |hoja|
      hoja.add_row [ "Cómo llenar esta planilla" ], style: @cabecera
      hoja.add_row []
      hoja.add_row [ self.class::INTRO ], style: @texto
      hoja.add_row []
      hoja.add_row [ "Columna", "¿Obligatoria?", "Cómo se escribe", "Ejemplo", "Detalle" ],
                   style: @titulo, height: 22

      self.class::COLUMNAS::TODAS.each do |c|
        hoja.add_row [ c.titulo, c.obligatorio? ? "Sí" : "No", c.formato, c.ejemplo, c.nota ],
                     style: [ @texto, @centrado, @texto, @texto, @texto ]
      end

      hoja.add_row []
      hoja.add_row [ "Antes de enviar" ], style: @cabecera
      hoja.add_row []
self.class::ANTES_DE_ENVIAR.each { |linea| hoja.add_row [ "•  #{linea}" ], style: @texto }

      hoja.column_widths 34, 13, 26, 24, 62
    end
  end

  def ancho_de(columna)
    [ columna.titulo.length / 2 + 6, columna.ejemplo.to_s.length + 4, 14 ].max
  end
end
