require "test_helper"

# La planilla de materias y profesores, ya entendida (MOR-126, tanda 2).
#
# Lo que más se prueba acá es lo que la separa de la matrícula: el CORREO del
# profesor es obligatorio —sin él no puede entrar a cargar notas, que es lo
# único que viene a hacer— y el CÓDIGO de la materia es lo que decide si se
# reutiliza o se duplica.
class PensumInterpretadoTest < ActiveSupport::TestCase
  setup do
    @escenario = escenario_academico
    @colegio = @escenario.colegio
    con_el_colegio(@colegio) do
      Section.create!(grade: @escenario.grado, academic_period: @escenario.periodo,
                      name: "B", capacity: 30)
    end
  end

  ENCABEZADOS = [ "SECCIÓN", "MATERIA", "CÓDIGO", "DEPARTAMENTO",
                  "PROFESOR", "CEDULA PROFESOR", "CORREO PROFESOR" ].freeze

  # ── lo que se carga bien ──────────────────────────────────────────────────

  test "una fila completa queda lista, sin errores ni avisos" do
    fila = interpretar([ "1er Año A", "Biología", "BIO", "Ciencias",
                         "GARCÍA PÉREZ CARLOS", "V-31.222.333", "carlos@bolivar.edu" ]).filas.first

    assert fila.limpia?, "quedó con #{(fila.errores + fila.avisos).to_sentence}"
    assert_equal @escenario.seccion, fila.seccion
    assert_equal "Biología", fila.materia
    assert_equal "BIO", fila.codigo
    assert_not fila.codigo_generado
    assert_equal "Ciencias", fila.departamento
    assert_equal "CARLOS", fila.profesor[:first_name]
    assert_equal "GARCÍA", fila.profesor[:last_name]
    assert_equal "31222333", fila.profesor[:document]
    assert_equal "carlos@bolivar.edu", fila.profesor[:email]
  end

  # El colegio que no maneja departamentos deja la columna fuera: es un agrupador
  # de listados, no un dato académico.
  test "sin departamento, la materia va a General" do
    fila = interpretar([ "1er Año A", "Biología", "BIO", "",
                         "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert fila.limpia?
    assert_equal "General", fila.departamento
  end

  # La planilla del colegio viene en MAYÚSCULA; los datos sembrados están en Tipo
  # Título. Guardar lo que llegó dejaría el listado desparejo.
  test "el nombre de la materia se guarda en Tipo Título" do
    fila = interpretar([ "1er Año A", "EDUCACIÓN FÍSICA", "", "DEPORTES",
                         "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert_equal "Educación Física", fila.materia
    assert_equal "Deportes", fila.departamento
  end

  # ── el código de la materia ───────────────────────────────────────────────

  test "el código que trae la planilla manda sobre el que SIGA inventaría" do
    fila = interpretar([ "1er Año A", "Castellano y Literatura", "LEN", "",
                         "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert_equal "LEN", fila.codigo
    assert_not fila.codigo_generado
  end

  test "sin código, lo arma con las tres primeras letras y las iniciales" do
    p = interpretar(
      [ "1er Año A", "Biología", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Educación Física", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Educación para la Salud", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]
    )

    assert_equal %w[BIO EDUF EDUS], p.filas.map(&:codigo)
    assert p.filas.all?(&:codigo_generado)
  end

  # Reimportar es el caso NORMAL: el colegio corrige cuatro filas y vuelve a
  # mandar. Si la materia que ya existe recibiera un código nuevo, cada
  # importación duplicaría el pensum entero.
  test "una materia que ya existe conserva su código en vez de recibir otro" do
    fila = interpretar([ "1er Año A", "Matemática", "", "",
                         "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert_equal "MAT", fila.codigo, "el escenario ya tiene MAT = Matemática"
  end

  # `subjects.code` es único dentro del colegio: sin esto, la segunda materia
  # fallaría al guardar con un error de base de datos en vez de un aviso.
  test "dos nombres distintos no se quedan con el mismo código" do
    fila = interpretar([ "1er Año A", "Matemáticas", "", "",
                         "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert_equal "MAT2", fila.codigo
    assert_includes interpretar([ "1er Año A", "Matemáticas", "", "", "GARCÍA CARLOS",
                                  "V-31222333", "c@b.edu" ]).codigos_generados,
                    [ "Matemáticas", "MAT2" ]
  end

  # La misma materia en cinco secciones son cinco filas y UNA materia. Si cada
  # fila generara su propio código, la quinta sería `MAT5`.
  test "la misma materia en dos secciones da el mismo código" do
    p = interpretar(
      [ "1er Año A", "Biología", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año B", "Biología", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]
    )

    assert_equal [ "BIO", "BIO" ], p.filas.map(&:codigo)
    assert_equal 1, p.materias_distintas
  end

  # ── ERRORES: la fila no se carga ──────────────────────────────────────────

  # ⚠️ Acá está la diferencia con la matrícula, y es del modelo: a un
  # representante sin correo se le carga igual, a un profesor NO. `EntraAlSistema`
  # lo exige, y sin entrar no puede cargar notas.
  test "un profesor sin correo NO se carga" do
    fila = interpretar([ "1er Año A", "Biología", "", "",
                         "GARCÍA CARLOS", "V-31222333", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no tiene correo/, fila.errores.first)
  end

  test "un correo que no es un correo tampoco se carga" do
    fila = interpretar([ "1er Año A", "Biología", "", "",
                         "GARCÍA CARLOS", "V-31222333", "n/a" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no es válido/, fila.errores.first)
  end

  test "sin cédula el profesor no se carga" do
    fila = interpretar([ "1er Año A", "Biología", "", "",
                         "GARCÍA CARLOS", "", "c@b.edu" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no trae cédula/, fila.errores.first)
  end

  test "sin profesor no se carga" do
    fila = interpretar([ "1er Año A", "Biología", "", "", "", "V-31222333", "c@b.edu" ]).filas.first

    assert_not fila.cargable?
    assert_includes fila.errores, "Sin profesor"
  end

  test "sin materia no se carga" do
    fila = interpretar([ "1er Año A", "", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert_not fila.cargable?
    assert_includes fila.errores, "Sin materia"
  end

  # Las secciones NO se crean solas: la previsualización las lista con su conteo
  # y ofrece crearlas de a una.
  test "una sección que no existe se rechaza y se lista aparte" do
    p = interpretar([ "3er Año C", "Biología", "", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ])

    assert_not p.filas.first.cargable?
    assert_empty p.cargables
    assert_equal [ "3er Año C" ], p.secciones_que_faltan.map { |s| s[:texto] }
  end

  # ── AVISOS: se carga, pero alguien tiene que enterarse ────────────────────

  # Pasó de verdad y le borró el nombre a un profesor: la planilla traía otra
  # persona con una cédula ya registrada, y el importador la sobrescribió.
  test "avisa si la cédula ya es de alguien que se llama muy distinto" do
    otro = con_el_colegio(@colegio) do
      User.create!(first_name: "CARLOS", last_name: "GARCÍA", document: "31222333",
                   document_type: :cedula_v, email: "carlos.viejo@bolivar.edu", password: "123123")
    end

    fila = interpretar([ "1er Año A", "Biología", "", "",
                         "MARÍN GONZÁLEZ MARÍA", "V-31.222.333", "maria@b.edu" ]).filas.first

    assert fila.cargable?, "el aviso no puede bloquear la carga"
    assert_match(/#{otro.nombre_completo}/, fila.avisos.first)
  end

  test "no avisa si es la misma persona escrita distinto" do
    con_el_colegio(@colegio) do
      User.create!(first_name: "CARLOS ALBERTO", last_name: "GARCÍA", document: "31222333",
                   document_type: :cedula_v, email: "carlos.viejo@bolivar.edu", password: "123123")
    end

    fila = interpretar([ "1er Año A", "Biología", "", "",
                         "GARCÍA PÉREZ CARLOS", "V-31222333", "c@b.edu" ]).filas.first

    assert fila.limpia?, "quedó con #{fila.avisos.to_sentence}"
  end

  # ── los resúmenes ─────────────────────────────────────────────────────────

  test "cuenta materias y profesores distintos, no filas" do
    p = interpretar(
      [ "1er Año A", "Biología", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año B", "Biología", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Física", "FIS", "", "SILVA LUIS", "V-84111222", "l@b.edu" ],
      [ "1er Año A", "Química", "QUI", "", "SILVA LUIS", "V-84111222", "" ]
    )

    assert_equal 3, p.cargables.size
    assert_equal 1, p.rechazadas.size
    assert_equal 2, p.materias_distintas
    assert_equal 2, p.profesores_distintos
    assert_empty p.codigos_generados
  end

  private

  def interpretar(*filas)
    archivo = Tempfile.new([ "pensum", ".csv" ])
    archivo.close
    CSV.open(archivo.path, "w") do |csv|
      csv << ENCABEZADOS
      filas.each { |f| csv << f }
    end
    @temporales ||= []
    @temporales << archivo

    hoja = Planilla.new(archivo.path)
    mapeo = hoja.encabezados.index_with { |e| ColumnasDePensum.para(e)&.clave&.to_s }.compact

    con_el_colegio(@colegio) do
      PensumInterpretado.new(planilla: hoja, mapeo: mapeo, colegio: @colegio,
                             periodo: @escenario.periodo)
    end
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
