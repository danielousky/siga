require "test_helper"

# El lector de planillas (MOR-126).
#
# Todo lo que prueba acá salió de mirar cómo son las planillas de un colegio de
# verdad, no de imaginar casos: el membrete arriba, el subtotal en el medio, la
# columna sin nombre, la columna repetida.
class PlanillaTest < ActiveSupport::TestCase
  # ── ubicar el encabezado ──────────────────────────────────────────────────

  # ⚠️ El caso que rompe la versión ingenua. Asumir que el encabezado es la
  # fila 1 deja al colegio con una columna llamada "U.E. COLEGIO SAN JOSÉ" y
  # tres filas de basura como si fueran alumnos.
  test "encuentra el encabezado debajo del membrete" do
    hoja = planilla_csv([
      [ "U.E. COLEGIO SAN JOSÉ" ],
      [ "MATRÍCULA 2025-2026" ],
      [],
      [ "Nº", "APELLIDOS Y NOMBRES", "C.I.", "AÑO/SECC" ],
      [ "1", "PÉREZ GÓMEZ ANA", "V-31222333", "1er Año A" ]
    ])

    assert_equal 4, hoja.fila_de_encabezado
    assert_equal [ "Nº", "APELLIDOS Y NOMBRES", "C.I.", "AÑO/SECC" ], hoja.encabezados
    assert_equal 1, hoja.filas.size
  end

  test "una planilla que sí empieza en la fila 1 también funciona" do
    hoja = planilla_csv([
      [ "NOMBRE", "CÉDULA", "SECCIÓN" ],
      [ "Ana Pérez", "31222333", "1er A" ]
    ])

    assert_equal 1, hoja.fila_de_encabezado
  end

  # El membrete cumple "parece encabezado" pero no tiene datos debajo con la
  # misma forma. Las dos mitades de la heurística hacen falta.
  test "no confunde un título largo con el encabezado" do
    hoja = planilla_csv([
      [ "COLEGIO", "SAN JOSÉ", "MATRÍCULA 2025" ],
      [],
      [ "NOMBRE", "CÉDULA", "SECCIÓN" ],
      [ "Ana Pérez", "31222333", "1er A" ],
      [ "Luis Gómez", "31222334", "1er A" ]
    ])

    assert_equal 3, hoja.fila_de_encabezado
  end

  test "avisa cuando no hay ninguna fila de encabezados" do
    error = assert_raises(Planilla::NoSePuedeLeer) do
      planilla_csv([ [ "1" ], [ "2" ], [ "3" ] ])
    end

    assert_match(/encabezados/, error.message)
  end

  # ── la basura del medio ───────────────────────────────────────────────────

  # ⚠️ Y los números de fila que devuelve son los ORIGINALES del archivo. Es lo
  # único que le sirve a quien tiene que ir a corregirlo: "la fila 8", no "el
  # registro 4".
  test "descarta los subtotales del medio y dice cuáles fueron" do
    hoja = planilla_csv([
      [ "NOMBRE", "CÉDULA", "SECCIÓN" ],
      [ "Ana Pérez", "31222333", "1er A" ],
      [ "", "SUBTOTAL 1er AÑO", "" ],
      [ "Luis Gómez", "31222334", "2do A" ]
    ])

    assert_equal [ 2, 4 ], hoja.filas.map(&:numero)
    assert_equal [ 3 ], hoja.descartadas.map(&:numero)
    assert_equal "SUBTOTAL 1er AÑO", hoja.descartadas.first.datos["CÉDULA"]
  end

  # ⚠️ Una fila de datos NO viene tan llena como el encabezado, y exigirlo
  # rechazaba planillas de verdad.
  #
  # Una matrícula real trae huecos por todos lados: el alumno sin cédula
  # todavía, el representante sin correo, la columna de observaciones vacía en
  # casi todas. Con doce columnas, la primera fila traía diez llenas — y la
  # versión que pedía «una menos que el encabezado» rechazaba el archivo entero.
  test "una fila con huecos sigue siendo una fila de datos" do
    hoja = planilla_csv([
      [ "U.E. COLEGIO SAN JOSÉ" ],
      [],
      [ "Nº", "APELLIDOS Y NOMBRES", "C.I.", "CÉDULA ESCOLAR", "F. NACIM.",
        "SEXO", "AÑO/SECC", "REPRESENTANTE", "CÉDULA REP.", "CORREO", "TELÉFONO", "OBSERVACIONES" ],
      [ "1", "DE LA CRUZ MARÍN JOSÉ", "", "V20140000123", "12/03/2014",
        "M", "1er Año A", "MARÍN MARÍA", "V-12345678", "m@m.com", "0414-1234567", "" ]
    ])

    assert_equal 3, hoja.fila_de_encabezado
    assert_equal 1, hoja.filas.size
  end

  test "descarta las filas vacías del final" do
    hoja = planilla_csv([
      [ "NOMBRE", "CÉDULA", "SECCIÓN" ],
      [ "Ana Pérez", "31222333", "1er A" ],
      [ "", "", "" ],
      [ "", "", "" ]
    ])

    assert_equal 1, hoja.filas.size
  end

  # ── los encabezados como claves ───────────────────────────────────────────

  # ⚠️ Los encabezados son las claves del hash de cada fila. Dos columnas
  # "OBSERVACIONES" es normal en una planilla de colegio, y sin desambiguar la
  # segunda se come a la primera en silencio.
  test "desambigua columnas con el mismo nombre" do
    hoja = planilla_csv([
      [ "NOMBRE", "OBSERVACIONES", "CÉDULA", "OBSERVACIONES" ],
      [ "Ana", "repitió", "31222333", "beca" ]
    ])

    assert_equal [ "NOMBRE", "OBSERVACIONES", "CÉDULA", "OBSERVACIONES (2)" ], hoja.encabezados
    assert_equal "repitió", hoja.filas.first["OBSERVACIONES"]
    assert_equal "beca", hoja.filas.first["OBSERVACIONES (2)"]
  end

  test "le pone nombre a la columna que no lo trae" do
    hoja = planilla_csv([
      [ "NOMBRE", "", "CÉDULA" ],
      [ "Ana", "x", "31222333" ]
    ])

    assert_equal "Columna 2", hoja.encabezados[1]
  end

  test "normaliza los espacios de más en el encabezado" do
    hoja = planilla_csv([
      [ "  APELLIDOS   Y  NOMBRES ", "CÉDULA", "SECCIÓN" ],
      [ "Ana Pérez", "31222333", "1er A" ]
    ])

    assert_equal "APELLIDOS Y NOMBRES", hoja.encabezados.first
  end

  # ── formatos ──────────────────────────────────────────────────────────────

  # El .xls de Excel 97-2003 no es un caso exótico: el sistema que usan hoy la
  # mayoría de los colegios venezolanos es de escritorio y con 25 años encima.
  test "lee un .xlsx igual que un .csv" do
    ruta = archivo_temporal(".xlsx") do |ruta|
      libro = Axlsx::Package.new
      libro.workbook.add_worksheet(name: "Matrícula") do |h|
        h.add_row [ "U.E. COLEGIO SAN JOSÉ" ]
        h.add_row []
        h.add_row [ "Nº", "APELLIDOS Y NOMBRES", "C.I.", "AÑO/SECC" ]
        h.add_row [ 1, "PÉREZ GÓMEZ ANA", "V-31222333", "1er Año A" ]
        h.add_row [ 2, "SILVA TORRES LUIS", "31222334", "1er Año A" ]
      end
      libro.serialize(ruta)
    end

    hoja = Planilla.new(ruta)

    assert_equal 3, hoja.fila_de_encabezado
    assert_equal [ "Nº", "APELLIDOS Y NOMBRES", "C.I.", "AÑO/SECC" ], hoja.encabezados
    assert_equal 2, hoja.filas.size
    assert_equal "PÉREZ GÓMEZ ANA", hoja.filas.first["APELLIDOS Y NOMBRES"]
  end

  test "rechaza un formato que no sabe leer" do
    error = assert_raises(Planilla::NoSePuedeLeer) do
      Planilla.new("matricula.pdf")
    end

    assert_match(/\.pdf/, error.message)
  end

  # Quien sube un archivo dañado necesita saber que no se pudo leer, no el
  # nombre de la excepción de roo.
  test "un archivo dañado da un mensaje entendible" do
    ruta = archivo_temporal(".xlsx") { |r| File.write(r, "esto no es una planilla") }

    error = assert_raises(Planilla::NoSePuedeLeer) { Planilla.new(ruta) }

    assert_match(/no se pudo leer/i, error.message)
  end

  # ── los dialectos de CSV que manda un colegio ─────────────────────────────
  #
  # ⚠️ Un CSV no dice con qué está separado, y Excel NO usa coma.
  #
  # Un Excel configurado en español guarda con punto y coma —la coma ya es el
  # separador decimal—, Numbers exporta con tabulaciones, y un Excel de Windows
  # escribe en Windows-1252 con BOM y saltos `\r\n`. Asumiendo coma, el archivo
  # entero se lee como UNA columna y el colegio recibe «no encontré la fila de
  # encabezados» sobre un archivo que está perfectamente bien.
  #
  # No es un caso de borde: es lo que sale de abrir un CSV en Excel y volver a
  # guardarlo, que es exactamente lo que hace una secretaria antes de mandarlo.

  test "lee un CSV separado por punto y coma, como lo guarda un Excel en español" do
    hoja = leer_csv(";")

    assert_equal 3, hoja.encabezados.size
    assert_equal %w[NOMBRE CEDULA SECCION], hoja.encabezados
    assert_equal "PÉREZ ANA", hoja.filas.first["NOMBRE"]
  end

  test "lee un CSV separado por tabulaciones" do
    hoja = leer_csv("\t")

    assert_equal %w[NOMBRE CEDULA SECCION], hoja.encabezados
  end

  # Windows-1252 y no ISO-8859-1: es lo que escribe Excel en Windows.
  test "lee un CSV en la codificación de Windows sin comerse los acentos" do
    hoja = leer_csv(";", codificacion: "Windows-1252")

    assert_equal "PÉREZ ANA", hoja.filas.first["NOMBRE"]
  end

  # ⚠️ El BOM y el `\r\n` van juntos porque juntos vienen, y el `\r` costó una
  # hora: al cortar la muestra justo antes del último `\n` quedaba un `\r` suelto
  # y `CSV` fallaba con TODOS los separadores por igual — así que ganaba la coma
  # por ser la primera de la lista, y el archivo se leía como una sola columna.
  test "lee un CSV con BOM y saltos de línea de Windows" do
    hoja = leer_csv(";", bom: true, salto: "\r\n")

    assert_equal %w[NOMBRE CEDULA SECCION], hoja.encabezados
    assert_equal 2, hoja.filas.size
  end

  # Una coma DENTRO de una celda entrecomillada no separa nada. Contar cuántas
  # veces aparece cada carácter elegiría mal; lo que decide es el ancho que sale.
  test "una coma dentro de una celda no confunde al detector" do
    hoja = leer_csv(";", nombre: "GARCÍA PÉREZ, CARLOS")

    assert_equal 3, hoja.encabezados.size
    assert_equal "GARCÍA PÉREZ, CARLOS", hoja.filas.first["NOMBRE"]
  end

  # ⚠️ Un BOM pegado al primer encabezado lo vuelve irreconocible para el mapeo,
  # y falla en esa columna nada más — que es peor que fallar entero, porque no se
  # nota. Pasa cuando el archivo trae marca de UTF-8 y contenido que no lo es.
  test "un BOM no se le pega al primer encabezado" do
    # Los bytes del BOM a mano: `\uFEFF` no EXISTE en Windows-1252, y eso es
    # justamente lo que hace al archivo una quimera — marca de UTF-8 delante de
    # contenido que no lo es.
    ruta = archivo_temporal(".csv") do |r|
      File.binwrite(r, "\xEF\xBB\xBF".b +
                       "NOMBRE;CEDULA;SECCION\r\nPÉREZ ANA;V-1;1er Año A\r\n".encode("Windows-1252").b)
    end

    assert_equal "NOMBRE", Planilla.new(ruta).encabezados.first
  end

  # Y el caso normal no se rompe por soportar los otros.
  test "sigue leyendo el CSV separado por comas de toda la vida" do
    hoja = leer_csv(",")

    assert_equal %w[NOMBRE CEDULA SECCION], hoja.encabezados
  end

  # El mensaje tiene que dejar diagnosticar: «leí 1 columna» es la pista de que
  # el separador no era el que se creía.
  test "cuando no encuentra encabezados dice cuántas columnas leyó" do
    ruta = archivo_temporal(".csv") { |r| File.write(r, "una sola celda\n" * 3) }

    error = assert_raises(Planilla::NoSePuedeLeer) { Planilla.new(ruta) }
    assert_match(/Leí 1 columna/, error.message)
  end

  private

  # Arma un CSV con el separador, la codificación y el salto de línea que se
  # pidan, para probar cómo llega de verdad.
  def leer_csv(separador, codificacion: "UTF-8", bom: false, salto: "\n", nombre: "PÉREZ ANA")
    filas = [ %w[NOMBRE CEDULA SECCION],
              [ nombre, "V-12345678", "1er Año A" ],
              [ "SILVA LUIS", "V-23456789", "1er Año A" ] ]

    texto = filas.map { |f| f.map { |c| c.include?(separador) || c.include?(",") ? "\"#{c}\"" : c }.join(separador) }
                 .join(salto) + salto
    texto = "\uFEFF#{texto}" if bom

    Planilla.new(archivo_temporal(".csv") { |ruta| File.binwrite(ruta, texto.encode(codificacion)) })
  end


  def planilla_csv(filas)
    ruta = archivo_temporal(".csv") do |r|
      CSV.open(r, "w") { |csv| filas.each { |f| csv << f } }
    end
    Planilla.new(ruta)
  end

  def archivo_temporal(extension)
    archivo = Tempfile.new([ "planilla", extension ])
    archivo.close
    yield archivo.path
    @temporales ||= []
    @temporales << archivo
    archivo.path
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
