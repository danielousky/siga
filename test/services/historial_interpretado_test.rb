require "test_helper"

# La planilla de notas de años anteriores, ya entendida (MOR-126, tanda 3).
#
# Lo que más se prueba acá es lo que separa a esta planilla de las otras dos:
# **cada fila puede ser de un año escolar distinto**, y «3er Año A» significa una
# sección diferente en cada uno.
class HistorialInterpretadoTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico
    @viejo = ano_escolar_viejo(@esc)
  end

  ENCABEZADOS = [ "APELLIDOS Y NOMBRES", "CEDULA ESCOLAR", "C.I.", "AÑO ESCOLAR",
                  "AÑO/SECC", "MATERIA", "LAPSO 1", "LAPSO 2", "LAPSO 3",
                  "DEFINITIVA", "REPARACIÓN" ].freeze

  # ── lo que se carga bien ──────────────────────────────────────────────────

  test "una fila completa queda lista" do
    fila = interpretar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
                         "Matemática", "15", "14", "16", "15", "" ]).filas.first

    assert fila.limpia?, "quedó con #{(fila.errores + fila.avisos).to_sentence}"
    assert_equal @viejo, fila.periodo
    assert_equal @esc.materia, fila.materia
    assert_equal({ 1 => 15, 2 => 14, 3 => 16 }, fila.lapsos)
    assert_equal 15, fila.definitiva
  end

  # ⚠️ La diferencia con las otras dos planillas: «1er Año A» es una sección
  # DISTINTA en cada año escolar.
  test "resuelve la sección dentro del año de cada fila" do
    h = interpretar(
      [ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A", "Matemática", "15", "", "", "", "" ],
      [ "PÉREZ ANA", "V20140000001", "", "2025-2026", "1er Año A", "Matemática", "18", "", "", "", "" ]
    )

    assert_equal @viejo, h.filas.first.periodo
    assert_equal @esc.periodo, h.filas.second.periodo
    assert_not_equal h.filas.first.seccion, h.filas.second.seccion,
                     "el mismo nombre, dos secciones distintas"
  end

  test "la materia se reconoce por su código además de por su nombre" do
    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                         "MAT", "15", "", "", "", "" ]).filas.first

    assert_equal @esc.materia, fila.materia
  end

  # ── las notas en letra ────────────────────────────────────────────────────

  # El historial de primaria viene en letras: es lo único que se imprimió.
  test "acepta el literal A–E y guarda el extremo inferior del rango" do
    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                         "Matemática", "B", "A", "", "B", "" ]).filas.first

    assert fila.cargable?
    assert_equal({ 1 => 17, 2 => 19 }, fila.lapsos)
    assert_equal 17, fila.definitiva
  end

  test "cuenta cuántas filas vinieron en letra, para poder avisarlo" do
    h = interpretar(
      [ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A", "Matemática", "B", "", "", "", "" ],
      [ "SILVA LUIS", "V20140000002", "", "2023-2024", "1er Año A", "Matemática", "15", "", "", "", "" ]
    )

    assert_equal 1, h.en_literal
  end

  # ── ERRORES: la fila no se carga ──────────────────────────────────────────

  # ⚠️ El nombre no alcanza: en una matrícula de 360 hay apellidos repetidos, y
  # una nota cargada al alumno equivocado es peor que no cargarla.
  test "sin cédula ni cédula escolar no se carga" do
    fila = interpretar([ "PÉREZ ANA", "", "", "2023-2024", "1er Año A",
                         "Matemática", "15", "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no se sabe de quién es/, fila.errores.first)
  end

  test "un año escolar que no existe se rechaza y se lista aparte" do
    h = interpretar([ "PÉREZ ANA", "V20140000001", "", "2019-2020", "1er Año A",
                      "Matemática", "15", "", "", "", "" ])

    assert_not h.filas.first.cargable?
    assert_equal [ "2019-2020" ], h.anos_que_faltan.map { |a| a[:nombre] }
    assert_equal 1, h.anos_que_faltan.first[:cuantas]
  end

  # La sección puede existir en OTRO año y aun así faltar en este.
  test "la sección tiene que existir en ese año, no en cualquiera" do
    otro = con_el_colegio(@esc.colegio) do
      AcademicPeriod.create!(school: @esc.colegio, name: "2022-2023",
                             start_date: Date.new(2022, 9, 15), end_date: Date.new(2023, 7, 31))
    end
    assert otro.persisted?

    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2022-2023", "1er Año A",
                         "Matemática", "15", "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no existe en 2022-2023/, fila.errores.first)
  end

  test "una materia que el colegio no tiene se rechaza" do
    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                         "Astrofísica", "15", "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no existe en el colegio/, fila.errores.first)
  end

  test "una fila sin ninguna nota no se carga" do
    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                         "Matemática", "", "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_includes fila.errores, "La fila no trae ninguna calificación"
  end

  test "una nota fuera de la escala se rechaza" do
    fila = interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                         "Matemática", "45", "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no es una calificación del 1 al 20/, fila.errores.first)
  end

  # ── los resúmenes ─────────────────────────────────────────────────────────

  # ⚠️ Alumnos DISTINTOS, no filas: uno con nueve materias es una persona.
  test "cuenta alumnos y años distintos, no filas" do
    h = interpretar(
      [ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A", "Matemática", "15", "", "", "", "" ],
      [ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A", "MAT", "18", "", "", "", "" ],
      [ "SILVA LUIS", "V20140000002", "", "2025-2026", "1er Año A", "Matemática", "12", "", "", "", "" ]
    )

    assert_equal 3, h.cargables.size
    assert_equal 2, h.alumnos_distintos
    assert_equal 2, h.anos_distintos
  end

  # Sale de las COLUMNAS mapeadas, no de una pregunta: si la planilla trae LAPSO
  # 1 y LAPSO 2, ese colegio tenía dos.
  test "deduce cuántos lapsos trae el archivo" do
    assert_equal 3, interpretar([ "PÉREZ ANA", "V20140000001", "", "2023-2024", "1er Año A",
                                  "Matemática", "15", "", "", "", "" ]).lapsos_de_la_planilla
  end

  private

  def interpretar(*filas)
    archivo = Tempfile.new([ "historial", ".csv" ])
    archivo.close
    CSV.open(archivo.path, "w") do |csv|
      csv << ENCABEZADOS
      filas.each { |f| csv << f }
    end
    @temporales ||= []
    @temporales << archivo

    hoja = Planilla.new(archivo.path)
    mapeo = hoja.encabezados.index_with { |e| ColumnasDeHistorial.para(e)&.clave&.to_s }.compact

    con_el_colegio(@esc.colegio) do
      HistorialInterpretado.new(planilla: hoja, mapeo: mapeo, colegio: @esc.colegio)
    end
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
