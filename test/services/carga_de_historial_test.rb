require "test_helper"

# Lo que el importador de historial escribe de verdad (MOR-126, tanda 3).
#
# La aserción que justifica toda la tanda es la última: que las notas
# **sobrevivan a un recálculo**. Sin eso, importar el historial de un colegio y
# borrarlo eran la misma operación.
class CargaDeHistorialTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico
    @viejo = ano_escolar_viejo(@esc)
  end

  ENCABEZADOS = [ "APELLIDOS Y NOMBRES", "CEDULA ESCOLAR", "C.I.", "AÑO ESCOLAR",
                  "AÑO/SECC", "MATERIA", "LAPSO 1", "LAPSO 2", "LAPSO 3",
                  "DEFINITIVA", "REPARACIÓN" ].freeze

  test "de una fila salen el alumno, su inscripción, los lapsos y la definitiva" do
    r = cargar([ "PÉREZ GÓMEZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
                 "Matemática", "15", "14", "16", "15", "" ])

    assert_equal 1, r.alumnos_creados
    assert_equal 1, r.inscripciones
    assert_equal 3, r.notas_de_lapso
    assert_equal 1, r.definitivas
    assert_empty r.fallidas

    con_el_colegio(@esc.colegio) do
      persona = User.find_by(cedula_escolar: "V20140000123")
      assert_equal "Ana Pérez Gómez", persona.nombre_completo

      inscripcion = Enrollment.find_by(student: Student.find_by(user: persona))
      assert_equal @viejo, inscripcion.section.academic_period
      assert_equal Date.new(2023, 9, 15), inscripcion.enrollment_date, "la fecha es la del año, no la de hoy"

      assert_equal [ 15, 14, 16 ], MomentGrade.where(enrollment: inscripcion).order(:evaluation_moment_id).map { |n| n.final_moment_score.to_i }
      assert_equal 15, FinalGradeBook.find_by(enrollment: inscripcion).annual_average.to_i
    end
  end

  # ⚠️ LA aserción de toda la tanda 3.
  test "las notas importadas sobreviven a un recálculo completo" do
    cargar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
             "Matemática", "15", "14", "16", "15", "" ])

    con_el_colegio(@esc.colegio) do
      inscripcion = Enrollment.joins(section: :academic_period).find_by(academic_periods: { id: @viejo.id })

      GradeCalculator.calculate_all_for_enrollment(inscripcion)

      assert_equal 3, MomentGrade.where(enrollment: inscripcion).count, "el recálculo las borró"
      assert_equal 15, FinalGradeBook.find_by(enrollment: inscripcion).annual_average.to_i
    end
  end

  test "todo lo que escribe queda marcado como importado" do
    cargar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
             "Matemática", "15", "", "", "15", "" ])

    con_el_colegio(@esc.colegio) do
      assert MomentGrade.all.all?(&:importada?)
      assert FinalGradeBook.all.all?(&:importada?)
    end
  end

  # La definitiva del colegio es la que está impresa en el boletín que ya
  # entregó, y puede no coincidir con el promedio por mil razones.
  test "la definitiva de la planilla manda sobre el promedio de los lapsos" do
    cargar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
             "Matemática", "10", "10", "10", "14", "" ])

    con_el_colegio(@esc.colegio) do
      assert_equal 14, FinalGradeBook.first.annual_average.to_i, "el promedio habría dado 10"
    end
  end

  # Art. 111: promedio simple, sin ponderar, sobre los enteros.
  test "sin definitiva se calcula el promedio de los lapsos que vinieron" do
    cargar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
             "Matemática", "10", "10", "9", "", "" ])

    con_el_colegio(@esc.colegio) do
      assert_equal 10, FinalGradeBook.first.annual_average.to_i, "(10+10+9)/3 = 9,67 → 10"
    end
  end

  # Art. 112: la nota de la segunda oportunidad es la definitiva.
  test "la reparación se guarda y decide la nota final" do
    cargar([ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A",
             "Matemática", "8", "9", "8", "8", "12" ])

    con_el_colegio(@esc.colegio) do
      libro = FinalGradeBook.first
      assert_equal 8, libro.annual_average.to_i
      assert_equal 12, libro.remedial_exam_score.to_i
      assert_equal 12, libro.final_score.to_i
    end
  end

  # Un alumno con nueve materias es UNA persona y UNA inscripción.
  test "el mismo alumno en varias materias no se duplica" do
    r = cargar(
      [ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A", "Matemática", "15", "", "", "15", "" ],
      [ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A", "MAT", "18", "", "", "18", "" ]
    )

    assert_equal 1, r.alumnos_creados
    assert_equal 1, r.inscripciones
    con_el_colegio(@esc.colegio) { assert_equal 1, Student.where.not(id: @esc.alumnos.map(&:id)).count }
  end

  # Reimportar es el caso normal: el colegio corrige cuatro filas y vuelve.
  test "reimportar la misma planilla no duplica nada" do
    fila = [ "PÉREZ ANA", "V20140000123", "", "2023-2024", "1er Año A", "Matemática", "15", "14", "16", "15", "" ]
    cargar(fila)

    assert_no_difference [ -> { con_el_colegio(@esc.colegio) { MomentGrade.count } },
                           -> { con_el_colegio(@esc.colegio) { Enrollment.count } } ] do
      cargar(fila)
    end
  end

  # Un alumno que ya está en SIGA por la matrícula es la misma persona: se le
  # agrega la inscripción vieja, no se lo duplica.
  test "un alumno que ya existe se reutiliza" do
    existente = @esc.alumno.user
    con_el_colegio(@esc.colegio) { existente.update!(cedula_escolar: "V20140000999") }

    r = cargar([ "PRUEBA ALUMNO1", "V20140000999", "", "2023-2024", "1er Año A",
                 "Matemática", "15", "", "", "15", "" ])

    assert_equal 0, r.alumnos_creados
    assert_equal 1, r.alumnos_reutilizados
    assert_equal 1, Current.sin_aislamiento { User.where(cedula_escolar: "V20140000999").count }
  end

  private

  def cargar(*filas)
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
      historial = HistorialInterpretado.new(planilla: hoja, mapeo: mapeo, colegio: @esc.colegio)
      CargaDeHistorial.new(historial: historial, colegio: @esc.colegio).ejecutar
    end
  end

  teardown { Array(@temporales).each { |a| a.unlink rescue nil } }
end
