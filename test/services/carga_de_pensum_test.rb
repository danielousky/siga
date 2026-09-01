require "test_helper"

# Lo que el importador de pensum escribe de verdad (MOR-126, tanda 2).
#
# De una fila salen cuatro cosas —materia, pensum, profesor y asignación— y las
# cuatro se buscan antes de crearse. Lo que más se prueba acá es que REIMPORTAR
# no duplique: es el caso normal, no el excepcional.
class CargaDePensumTest < ActiveSupport::TestCase
  setup do
    @escenario = escenario_academico
    @colegio = @escenario.colegio
    @seccion_b = con_el_colegio(@colegio) do
      Section.create!(grade: @escenario.grado, academic_period: @escenario.periodo,
                      name: "B", capacity: 30)
    end
  end

  ENCABEZADOS = [ "SECCIÓN", "MATERIA", "CÓDIGO", "DEPARTAMENTO",
                  "PROFESOR", "CEDULA PROFESOR", "CORREO PROFESOR" ].freeze

  test "de una fila salen la materia, el pensum, el profesor y la asignación" do
    r = cargar([ "1er Año A", "BIOLOGÍA", "BIO", "Ciencias",
                 "GARCÍA PÉREZ CARLOS", "V-31.222.333", "carlos@bolivar.edu" ])

    assert_equal 1, r.materias_creadas
    assert_equal 1, r.profesores_creados
    assert_equal 1, r.pensum
    assert_equal 1, r.asignaciones
    assert_empty r.fallidas

    con_el_colegio(@colegio) do
      materia = Subject.find_by!(code: "BIO")
      assert_equal "BIOLOGÍA", materia.name
      assert_equal "Ciencias", materia.department.name
      assert GradeSubject.exists?(grade: @escenario.grado, subject: materia)

      asignacion = TeacherSection.find_by!(section: @escenario.seccion, subject: materia)
      assert_equal "Carlos García Pérez", asignacion.teacher.user.nombre_completo
      assert_equal "carlos@bolivar.edu", asignacion.teacher.user.email
    end
  end

  # El caso NORMAL: el colegio ve el reporte, corrige cuatro filas y vuelve a
  # mandar la planilla entera.
  test "reimportar la misma planilla no duplica nada" do
    fila = [ "1er Año A", "BIOLOGÍA", "BIO", "Ciencias", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]

    cargar(fila)
    r = cargar(fila)

    assert_equal 0, r.materias_creadas
    assert_equal 1, r.materias_reutilizadas
    assert_equal 0, r.profesores_creados
    assert_equal 1, r.profesores_reutilizados
    assert_equal 0, r.pensum
    assert_equal 0, r.asignaciones

    con_el_colegio(@colegio) do
      assert_equal 1, Subject.where(code: "BIO").count
      assert_equal 1, TeacherSection.where(subject: Subject.find_by(code: "BIO")).count
    end
  end

  # Una materia en dos secciones son dos filas y UNA materia: dos asignaciones,
  # un solo registro de pensum, porque las dos secciones son del mismo grado.
  test "la misma materia en dos secciones es una materia y dos asignaciones" do
    r = cargar(
      [ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año B", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]
    )

    assert_equal 1, r.materias_creadas
    assert_equal 1, r.pensum
    assert_equal 2, r.asignaciones
    assert_equal [ "1er Año A", "1er Año B" ], r.secciones_tocadas.to_a.sort
  end

  test "un profesor con tres materias es una sola persona" do
    r = cargar(
      [ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Física", "FIS", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Química", "QUI", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ]
    )

    assert_equal 3, r.materias_creadas
    assert_equal 1, r.profesores_creados
    assert_equal 3, r.asignaciones

    con_el_colegio(@colegio) { assert_equal 1, Teacher.where(school: @colegio).count }
  end

  # ⚠️ `teacher_sections` valida un profesor por materia y sección. La segunda
  # fila no puede guardarse, y el colegio tiene que ver POR QUÉ.
  test "dos profesores para la misma materia y sección se reporta, no revienta" do
    r = cargar(
      [ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "BIOLOGÍA", "BIO", "", "SILVA LUIS", "V-84111222", "l@b.edu" ]
    )

    assert_equal 1, r.asignaciones
    assert_equal 1, r.fallidas.size
    # 3 y no 2: es el número de fila DEL ARCHIVO, que es lo único que le sirve a
    # quien tiene que ir a corregirla. La 1 es el encabezado.
    assert_equal 3, r.fallidas.first["fila"]
    assert_match(/ya está asignada a Carlos García/, r.fallidas.first["motivo"])
  end

  # Una persona es de la plataforma, no de un colegio: el profesor que da clase
  # en dos planteles de SIGA es el mismo ser humano.
  test "un profesor que ya existe en otro colegio se reutiliza" do
    otro = escenario_academico(nombre: "Otro Colegio")
    persona = con_el_colegio(otro.colegio) do
      usuario = User.create!(first_name: "CARLOS", last_name: "GARCÍA", document: "31222333",
                             document_type: :cedula_v, email: "carlos@otro.edu", password: "123123")
      Teacher.create!(user: usuario, school: otro.colegio)
      usuario
    end

    r = cargar([ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ])

    assert_equal 1, r.profesores_creados, "el ROL en este colegio sí es nuevo"
    assert_equal 1, Current.sin_aislamiento { User.where(document: "31222333").count }
    assert_equal 2, Current.sin_aislamiento { Teacher.unscoped.where(user: persona).count }

    # La planilla de un colegio no le pisa el correo a la ficha que otro mantiene.
    assert_equal "carlos@otro.edu", persona.reload.email
  end

  # El profesor que ya da clase acá SÍ se actualiza: la planilla de su propio
  # colegio es la fuente de verdad.
  test "el profesor de este colegio se actualiza con lo que trae la planilla" do
    persona = con_el_colegio(@colegio) do
      usuario = User.create!(first_name: "CARLOS", last_name: "GARCIA", document: "31222333",
                             document_type: :cedula_v, email: "viejo@bolivar.edu", password: "123123")
      Teacher.create!(user: usuario, school: @colegio)
      usuario
    end

    cargar([ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA PÉREZ CARLOS", "V-31222333", "nuevo@bolivar.edu" ])

    assert_equal "nuevo@bolivar.edu", persona.reload.email
    assert_equal "PÉREZ", persona.second_last_name
  end

  # Solo se cargan las filas que la previsualización marcó como cargables.
  test "las filas rechazadas no se escriben" do
    r = cargar(
      [ "1er Año A", "BIOLOGÍA", "BIO", "", "GARCÍA CARLOS", "V-31222333", "c@b.edu" ],
      [ "1er Año A", "Física", "FIS", "", "SILVA LUIS", "V-84111222", "" ]
    )

    assert_equal 1, r.asignaciones
    con_el_colegio(@colegio) { assert_nil Subject.find_by(code: "FIS") }
  end

  private

  def cargar(*filas)
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
      pensum = PensumInterpretado.new(planilla: hoja, mapeo: mapeo, colegio: @colegio,
                                      periodo: @escenario.periodo)
      CargaDePensum.new(pensum: pensum, colegio: @colegio).ejecutar
    end
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
