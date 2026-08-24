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

  private

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
