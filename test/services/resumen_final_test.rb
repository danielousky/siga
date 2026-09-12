require "test_helper"

# El RESUMEN FINAL DEL RENDIMIENTO ESTUDIANTIL, formato `RR-DEA-04-03`.
#
# Es el acta que el colegio le manda a la zona educativa al cerrar el año, y es
# el documento de fin de año de Educación Media — el hermano del certificado de
# primaria y de la certificación de Inicial.
#
# ## ⚠️ Es de la SECCIÓN, no de un alumno
#
# Los otros tres certifican a una persona; éste resume al curso entero: una fila
# por alumno, una columna por asignatura, y al pie quién dictó cada una.
class ResumenFinalTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(nombre: "Liceo", alumnos: 3, nivel: :secundaria)
  end

  def datos
    con_el_colegio(@esc.colegio) { ResumenFinalDeLaSeccion.para(seccion: @esc.seccion) }
  end

  # ── Quién lo recibe ───────────────────────────────────────────────────────

  # ⚠️ El encabezado del formato dice «Régimen Regular» de bachillerato.
  # Primaria e Inicial tienen sus propios documentos, por alumno.
  test "es de Educación Media, y solo de ahí" do
    con_el_colegio(@esc.colegio) do
      assert ResumenFinalDeLaSeccion.new(seccion: @esc.seccion).emitible?
    end

    escuela = escenario_academico(nombre: "Escuela", nivel: :primaria)
    con_el_colegio(escuela.colegio) do
      assert_not ResumenFinalDeLaSeccion.new(seccion: escuela.seccion).emitible?
    end
  end

  # ── Lo que lleva ──────────────────────────────────────────────────────────

  test "una fila por alumno, numeradas y con su cédula" do
    d = datos

    assert_equal 3, d["total_de_alumnos"]
    assert_equal 3, d["filas"].size
    assert_equal %w[01 02 03], d["filas"].map { |f| f["numero"] }
    assert d["filas"].all? { |f| f["cedula"].present? }
  end

  # ⚠️ Sin esto la tabla es ilegible: son columnas numeradas 01 a 15 y nada dice
  # cuál es Matemática. Y la firma del profesor es lo que convierte el acta en un
  # documento: la zona educativa la exige.
  test "dice qué asignatura es cada número, y quién la dictó" do
    d = datos
    materia = d["asignaturas"].first

    assert_equal "01", materia["codigo"]
    assert_equal @esc.materia.name, materia["nombre"]
    assert_nil materia["profesor"], "sin asignación no se inventa un profesor"
  end

  test "el profesor sale de la asignación de ESA sección" do
    con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "CARLOS", last_name: "GARCÍA",
                             email: "garcia.#{@esc.colegio.id}@liceo.test", password: "123123",
                             document: "V-#{@esc.colegio.id}33", document_type: :cedula_v)
      docente = Teacher.create!(user: usuario, school: @esc.colegio)
      TeacherSection.create!(teacher: docente, section: @esc.seccion, subject: @esc.materia)
    end

    assert_equal "García, Carlos", datos["asignaturas"].first.dig("profesor", "nombre")
  end

  # ⚠️ La DEFINITIVA, que es la que manda el Artículo 112: si hubo reparación,
  # es esa. No el promedio anual.
  test "lleva la nota definitiva de cada alumno en cada asignatura" do
    con_el_colegio(@esc.colegio) do
      FinalGradeBook.create!(enrollment: @esc.inscripcion(1), subject: @esc.materia,
                             annual_average: 9, remedial_exam_score: 14, final_score: 14)
    end

    assert_equal 14, datos["filas"].first["notas"].first
  end

  test "un alumno sin nota queda en blanco, no en cero" do
    # ⚠️ «Sin nota» no es un cero: es que no hay definitiva cargada todavía.
    assert_nil datos["filas"].first["notas"].first
  end

  # ── Lo que queda en blanco, a propósito ───────────────────────────────────

  # ⚠️ Plan de Estudio, Mención y Educación para el Trabajo: SIGA no los modela,
  # y por eso el documento sale también en Excel — con solo el PDF el colegio
  # quedaría esperando que nosotros los modelemos para entregar su acta.
  # Decisión de Daniel, 11 de septiembre de 2026.
  test "no inventa el plan de estudio ni la mención" do
    d = datos

    assert_not d.key?("plan_de_estudio")
    assert_not d.key?("mencion")
  end

  # ⚠️ El formato tiene quince columnas y un pensum más largo no entra en la
  # cuadrícula del ministerio. Se corta y se avisa, en vez de dibujar una tabla
  # que se sale de la hoja.
  test "avisa si el pensum no cabe en las quince columnas" do
    con_el_colegio(@esc.colegio) do
      departamento = Department.create!(school: @esc.colegio, name: "Varios")
      16.times do |i|
        materia = Subject.create!(department: departamento, code: "M#{i}", name: "Materia #{i}")
        GradeSubject.create!(grade: @esc.grado, subject: materia)
      end
    end

    d = datos

    assert d["se_cortaron_asignaturas"]
    assert_equal ResumenFinalDeLaSeccion::COLUMNAS_DE_ASIGNATURA, d["asignaturas"].size
  end

  # ── Los dos formatos salen ────────────────────────────────────────────────

  test "el PDF y el Excel se dibujan, con los mismos datos" do
    d = datos

    pdf = ResumenFinalPdf.new(d).render
    assert pdf.start_with?("%PDF")
    assert_operator pdf.bytesize, :>, 1_000

    hoja = ResumenFinalXlsx.new(d)
    assert_operator hoja.to_stream.read.bytesize, :>, 1_000
    assert_match(/\Aresumen-final-.*\.xlsx\z/, hoja.nombre_de_archivo)
  end
end
