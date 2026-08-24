# La planilla en blanco que el colegio descarga para llenar (MOR-126).
#
# Es la mitad que suele faltar en un importador. Sin ella, "mándenos su
# matrícula en Excel" deja a la secretaria adivinando qué columnas poner, y lo
# que llega hay que devolverlo. Con ella, la mayoría de los archivos llegan bien
# a la primera y el mapeo casi no hace falta.
#
# Dos hojas, y las dos importan:
#
#   MATRÍCULA      los encabezados y tres filas de ejemplo, para copiar el
#                  formato en vez de leerlo.
#   INSTRUCCIONES  qué significa cada columna, si es obligatoria y cómo se
#                  escribe — que es lo que alguien busca cuando algo no le entra.
class PlantillaDeMatricula
  # Los ejemplos no son de adorno: cada uno enseña algo que el texto solo no
  # transmite bien.
  EJEMPLOS = [
    # Un alumno de primaria: sin cédula de identidad, con escolar. Es el caso
    # más común y el que más dudas genera.
    [ "DE LA CRUZ MARÍN JOSÉ LUIS", "V20140000123", "", "12/03/2014", "M", "", "1er Año A",
      "MARÍN GONZÁLEZ MARÍA", "V-12.345.678", "maria.marin@gmail.com", "0414-1234567", "Madre" ],
    # Su hermana: MISMA representante, misma cédula. Enseña que no hay que
    # inventarle una fila aparte al representante.
    [ "DE LA CRUZ MARÍN ANA SOFÍA", "V20160000456", "", "22/11/2016", "F", "", "1er Año A",
      "MARÍN GONZÁLEZ MARÍA", "V-12.345.678", "maria.marin@gmail.com", "0414-1234567", "Madre" ],
    # Un bachiller: ya tiene cédula, y su representante NO tiene correo.
    # Enseña que la fila entra igual.
    [ "BLANCO NIEVES PEDRO ANTONIO", "", "V-31.222.333", "05/07/2009", "M", "25-104", "5to Año B",
      "NIEVES ROJAS CARMEN", "V-10.987.654", "", "0424-9876543", "Madre" ]
  ].freeze

  def initialize(colegio: nil)
    @colegio = colegio
  end

  def to_stream
    libro.to_stream
  end

  def nombre_de_archivo
    base = @colegio&.name.to_s.parameterize.presence || "siga"
    "matricula-#{base}.xlsx"
  end

  private

  def libro
    Axlsx::Package.new do |paquete|
      estilos(paquete.workbook)
      hoja_de_matricula(paquete.workbook)
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

  def hoja_de_matricula(libro)
    libro.add_worksheet(name: "Matrícula") do |hoja|
      columnas = ColumnasDeMatricula::TODAS

      # Las obligatorias van en otro color. Es más rápido de leer que cualquier
      # asterisco, y sobrevive a que alguien imprima la hoja.
      hoja.add_row(columnas.map(&:titulo),
                   style: columnas.map { |c| c.obligatorio? ? @obligatorio : @titulo },
                   height: 34)

      EJEMPLOS.each { |fila| hoja.add_row(fila, style: @ejemplo) }

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
      hoja.add_row [
        "Borre las tres filas de ejemplo de la hoja «Matrícula» y escriba sus alumnos, " \
        "uno por fila. Las columnas en rojo son obligatorias. Puede agregar columnas " \
        "suyas: las que SIGA no reconozca simplemente se ignoran."
      ], style: @texto
      hoja.add_row []
      hoja.add_row [ "Columna", "¿Obligatoria?", "Cómo se escribe", "Ejemplo", "Detalle" ],
                   style: @titulo, height: 22

      ColumnasDeMatricula::TODAS.each do |c|
        hoja.add_row [ c.titulo, c.obligatorio? ? "Sí" : "No", c.formato, c.ejemplo, c.nota ],
                     style: [ @texto, @centrado, @texto, @texto, @texto ]
      end

      hoja.add_row []
      hoja.add_row [ "Antes de enviar" ], style: @cabecera
      hoja.add_row []
      [
        "Las secciones («1er Año A») tienen que existir ya en SIGA. Si alguna no existe, " \
        "el sistema se lo va a mostrar ANTES de cargar nada y le ofrece crearla ahí mismo.",
        "Si un alumno repite en dos filas, se carga una sola vez: se reconoce por su cédula.",
        "Un representante sin correo se carga igual, pero no va a poder consultar las notas " \
        "hasta que se lo carguen. Al terminar sale la lista de quiénes quedaron así.",
        "No hace falta borrar los subtotales ni el membrete: el sistema los ignora y le dice " \
        "cuáles filas dejó fuera."
      ].each { |linea| hoja.add_row [ "•  #{linea}" ], style: @texto }

      hoja.column_widths 34, 13, 26, 24, 62
    end
  end

  def ancho_de(columna)
    [ columna.titulo.length / 2 + 6, columna.ejemplo.to_s.length + 4, 14 ].max
  end
end
