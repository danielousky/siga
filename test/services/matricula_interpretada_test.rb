require "test_helper"

# La planilla ya entendida: quién es cada alumno y qué le falta (MOR-126).
#
# Lo que más se prueba acá es la distinción entre ERROR y AVISO, porque
# confundirlas es lo que hace inservible a un importador: si todo es error, un
# colegio con 45 representantes sin correo no puede importar nada; si todo es
# aviso, se cargan alumnos sin nombre.
class MatriculaInterpretadaTest < ActiveSupport::TestCase
  setup do
    @escenario = escenario_academico
    @colegio = @escenario.colegio
    con_el_colegio(@colegio) do
      Section.create!(grade: @escenario.grado, academic_period: @escenario.periodo,
                      name: "B", capacity: 30)
    end
  end

  ENCABEZADOS = [ "APELLIDOS Y NOMBRES", "C.I.", "CEDULA ESCOLAR", "F. NACIM.", "SEXO",
                  "AÑO/SECC", "REPRESENTANTE", "CEDULA REPRESENTANTE",
                  "CORREO REPRESENTANTE", "PARENTESCO" ].freeze

  # ── lo que se carga bien ──────────────────────────────────────────────────

  test "una fila completa queda lista, sin errores ni avisos" do
    fila = interpretar([ "DE LA CRUZ MARÍN JOSÉ LUIS", "", "V20140000123", "12/03/2014", "M",
                         "1er Año A", "MARÍN GONZÁLEZ MARÍA", "V-12.345.678",
                         "maria@gmail.com", "Madre" ]).filas.first

    assert fila.limpia?, "quedó con #{(fila.errores + fila.avisos).to_sentence}"
    assert_equal "JOSÉ LUIS", fila.alumno[:first_name]
    assert_equal "DE LA CRUZ", fila.alumno[:last_name]
    assert_equal "MARÍN", fila.alumno[:second_last_name]
    assert_equal "V20140000123", fila.alumno[:cedula_escolar]
    assert_equal Date.new(2014, 3, 12), fila.alumno[:birth_date]
    assert_equal :male, fila.alumno[:sex]
    assert_equal "12345678", fila.representante[:document]
    assert_equal :madre, fila.parentesco
  end

  # El tipo sale del propio número. Pedir una columna aparte sería pedir un dato
  # que ya está escrito.
  test "deduce si la cédula es venezolana o de extranjero" do
    m = interpretar(
      [ "PÉREZ ANA", "V-31.222.333", "", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "E-84.111.222", "", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal :cedula_v, m.filas.first.alumno[:document_type]
    assert_equal :cedula_e, m.filas.second.alumno[:document_type]
    assert_equal "84111222", m.filas.second.alumno[:document]
  end

  test "sin parentesco escrito, queda como representante" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert_equal :representante, fila.parentesco
  end

  # ── ERRORES: la fila no se carga ──────────────────────────────────────────

  test "sin nombre no se carga" do
    fila = interpretar([ "", "V-31222333", "", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_includes fila.errores, "Sin nombre"
  end

  # El modelo no deja crear a nadie sin identificador, y con razón: nadie sin
  # uno puede aparecer en una planilla del MPPE.
  test "sin cédula ni cédula escolar no se carga" do
    fila = interpretar([ "PÉREZ ANA", "", "", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/Sin cédula/, fila.errores.first)
  end

  test "sin representante no se carga" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_includes fila.errores, "Sin representante"
  end

  test "un representante sin cédula no se carga" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARÍN MARÍA", "", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/no trae cédula/, fila.errores.first)
  end

  test "una sección que no existe no se carga" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año Z",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert_not fila.cargable?
    assert_match(/«1er Año Z» no existe/, fila.errores.first)
  end

  test "un grado que no existe lo dice distinto" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "9no Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert_match(/ningún grado/, fila.errores.first)
  end

  # ── AVISOS: la fila se carga igual ────────────────────────────────────────

  # ⚠️ Es la decisión de MOR-142: sin correo la fila entra, pero el colegio
  # tiene que salir sabiendo a quién le falta.
  test "un representante sin correo se carga, con aviso" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert fila.cargable?
    assert_match(/no tiene correo/, fila.avisos.first)
  end

  test "un correo inválido se descarta y se avisa, pero la fila entra" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "correo-malo", "" ]).filas.first

    assert fila.cargable?
    assert_nil fila.representante[:email]
    assert_match(/no es válido/, fila.avisos.first)
  end

  test "un nombre de cinco palabras se carga, pero pide revisión" do
    fila = interpretar([ "RODRÍGUEZ LÓPEZ CARLOS ANDRÉS JOSÉ", "", "V20140000001", "", "",
                         "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert fila.cargable?
    assert_match(/revise dónde termina el apellido/, fila.avisos.first)
  end

  test "una fecha que no existe se avisa y el alumno entra sin ella" do
    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "31/02/2014", "", "1er Año A",
                         "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

    assert fila.cargable?
    assert_nil fila.alumno[:birth_date]
    assert_match(/Fecha de nacimiento/, fila.avisos.first)
  end

  # ── la cédula que ya es de otra persona ───────────────────────────────────

  # ⚠️ Pasó de verdad, importando en desarrollo: la planilla traía a «MARÍN
  # GONZÁLEZ MARÍA» con una cédula que en SIGA era la del profesor Carlos
  # García. El importador la encontró —hace bien, se busca por cédula— y le
  # sobrescribió el nombre. El profesor dejó de llamarse como se llama.
  #
  # Buscar por cédula no se toca: es lo que hace que una madre con hijos en dos
  # colegios sea una sola persona. Lo que faltaba era NOTARLO.
  test "avisa cuando la cédula ya es de alguien con otro nombre" do
    con_el_colegio(@colegio) do
      User.create!(first_name: "CARLOS", last_name: "GARCÍA",
                   document: "12345678", document_type: :cedula_v,
                   email: "prof.garcia@colegio.test", password: "123123")
    end

    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARÍN GONZÁLEZ MARÍA", "V-12.345.678", "", "" ]).filas.first

    assert fila.cargable?, "no bloquea: puede ser legítimo"
    assert_match(/Carlos García/, fila.avisos.to_sentence)
    assert_match(/Confirme que es la misma persona/, fila.avisos.to_sentence)
  end

  # Un apellido mal escrito o abreviado NO es una colisión: es la misma persona
  # y el aviso sería ruido en 360 filas.
  test "no avisa cuando es claramente la misma persona" do
    con_el_colegio(@colegio) do
      User.create!(first_name: "MARÍA", last_name: "MARÍN", second_last_name: "GONZÁLEZ",
                   document: "12345678", document_type: :cedula_v,
                   email: "maria@familia.test")
    end

    fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A",
                         "MARIN GONZALEZ MARIA", "V-12.345.678", "", "" ]).filas.first

    assert_no_match(/misma persona/, fila.avisos.to_sentence)
  end

  test "también avisa cuando la cédula del ALUMNO es de otro" do
    con_el_colegio(@colegio) do
      User.create!(first_name: "PEDRO", last_name: "BLANCO",
                   document: "31222333", document_type: :cedula_v,
                   cedula_escolar: "V20090000111")
    end

    fila = interpretar([ "SILVA TORRES LUIS", "V-31.222.333", "", "", "", "1er Año A",
                         "MARÍN MARÍA", "V-99887766", "", "" ]).filas.first

    assert_match(/Pedro Blanco/, fila.avisos.to_sentence)
  end

  # ── el conteo por sección ─────────────────────────────────────────────────

  # ⚠️ El conteo es lo que delata el error de tipeo: «1er Año C · 20 alumnos» es
  # una sección, «1er Año K · 1 alumno» es un dedazo. Verlos juntos lo hace
  # obvio antes de crear basura.
  test "agrupa las secciones con su conteo" do
    m = interpretar(
      *3.times.map { |i| [ "PÉREZ ANA#{i}", "", "V2014000000#{i}", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ] },
      [ "SILVA LUIS", "", "V20140000009", "", "", "1er Año Z", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    a = m.secciones_de_la_planilla.find { |s| s[:texto] == "1er Año A" }
    z = m.secciones_de_la_planilla.find { |s| s[:texto] == "1er Año Z" }

    assert_equal 3, a[:cuantas]
    assert_not_nil a[:seccion]

    assert_equal 1, z[:cuantas]
    assert_nil z[:seccion]
    assert_equal "Z", z[:nombre_de_seccion]
    assert_equal @escenario.grado, z[:grado], "el grado sí existe: falta solo la sección"
  end

  # ⚠️ `1er Año A` y `1er Año Á` son la MISMA sección: `partir` compara sin
  # acentos, así que el dedazo se resuelve solo.
  #
  # Agrupando por el texto crudo salían como dos, con dos botones «Crear 1er Año
  # A» que hacen lo mismo — y el segundo, después de apretar el primero, ya no
  # hacía nada. Se agrupan por la sección a la que APUNTAN, y las variantes de
  # escritura se listan para que el colegio las corrija.
  test "dos formas de escribir la misma sección son una sola" do
    m = interpretar(
      [ "ROJAS EVA", "", "V20140000003", "", "", "1ER AÑO / A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "", "", "1er Año Á", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "DÍAZ SOL", "", "V20140000004", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal 1, m.secciones_de_la_planilla.size
    seccion = m.secciones_de_la_planilla.first

    assert_equal 4, seccion[:cuantas]
    assert_equal "1er Año A", seccion[:texto], "manda la escritura que más se repite"
    assert_equal [ "1ER AÑO / A", "1er Año Á" ], seccion[:tambien]
    assert_equal @escenario.seccion, seccion[:seccion]
  end

  # Sin grado reconocible no hay identidad que compartir: si se agruparan igual,
  # dos textos que no son nada quedarían sumados en una misma fila inexistente.
  test "lo que no se parece a ningún grado no se agrupa entre sí" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "", "", "Preescolar B", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "", "", "SIN ASIGNAR", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal 2, m.secciones_de_la_planilla.size
    assert_equal [ "Preescolar B", "SIN ASIGNAR" ], m.secciones_de_la_planilla.map { |s| s[:texto] }
  end

  test "las secciones que faltan se listan aparte" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "", "", "1er Año Z", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal [ "1er Año Z" ], m.secciones_que_faltan.map { |s| s[:texto] }
  end

  # `1er Año A`, `1erAño-A` y `1ER AÑO / A` son la misma sección escrita por
  # tres secretarias distintas.
  test "entiende la sección escrita de varias formas" do
    [ "1er Año A", "1ER AÑO A", "1erAño-A", "1er año / A", "  1er  Año  a  " ].each do |escrito|
      fila = interpretar([ "PÉREZ ANA", "", "V20140000001", "", "", escrito,
                           "MARÍN MARÍA", "V-12345678", "", "" ]).filas.first

      assert fila.cargable?, "«#{escrito}» debería resolverse: #{fila.errores.to_sentence}"
    end
  end

  # ── las fechas ambiguas ───────────────────────────────────────────────────

  # ⚠️ No es un error: es una pregunta. Si la planilla salió de un Excel en
  # inglés, TODAS las fechas con día y mes ≤ 12 quedan cambiadas y nadie se
  # entera.
  test "cuenta las fechas que se leerían al revés en un Excel en inglés" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "03/12/2014", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "22/11/2014", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal 1, m.fechas_ambiguas, "solo la primera: no existe el mes 22"
  end

  # ── el sexo, con la columna entera ────────────────────────────────────────

  # `H` es femenino junto a `V` y masculino junto a `M`. Leyendo celda por
  # celda, un colegio que use hombre/mujer queda con todo invertido.
  test "el sexo se decide con la columna entera" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "", "H", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "", "M", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal :male,   m.filas.first.alumno[:sex],  "con M al lado, H es hombre"
    assert_equal :female, m.filas.second.alumno[:sex]
  end

  test "con V al lado, la H es hembra" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "", "H", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ],
      [ "SILVA LUIS", "", "V20140000002", "", "V", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal :female, m.filas.first.alumno[:sex]
    assert_equal :male,   m.filas.second.alumno[:sex]
  end

  # ── los resúmenes ─────────────────────────────────────────────────────────

  test "separa las que se cargan de las que no" do
    m = interpretar(
      [ "PÉREZ ANA", "", "V20140000001", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "m@m.com", "" ],
      [ "", "", "V20140000002", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "m@m.com", "" ],
      [ "SILVA LUIS", "", "V20140000003", "", "", "1er Año A", "MARÍN MARÍA", "V-12345678", "", "" ]
    )

    assert_equal 2, m.cargables.size
    assert_equal 1, m.rechazadas.size
    assert_equal 1, m.con_avisos.size
    assert_equal 1, m.representantes_sin_correo
  end

  private

  # Arma una planilla con `ENCABEZADOS` y las filas dadas, la mapea sola y la
  # interpreta contra el colegio del escenario.
  def interpretar(*filas)
    archivo = Tempfile.new([ "matricula", ".csv" ])
    archivo.close
    CSV.open(archivo.path, "w") do |csv|
      csv << ENCABEZADOS
      filas.each { |f| csv << f }
    end
    @temporales ||= []
    @temporales << archivo

    hoja = Planilla.new(archivo.path)
    mapeo = hoja.encabezados.index_with { |e| ColumnasDeMatricula.para(e)&.clave&.to_s }.compact

    con_el_colegio(@colegio) do
      MatriculaInterpretada.new(planilla: hoja, mapeo: mapeo, colegio: @colegio)
    end
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
