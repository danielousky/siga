require "test_helper"

# Los documentos oficiales del MPPE (MOR-99).
#
# Lo que más se prueba acá es **cuál documento corresponde**: emitirle a un
# alumno el papel de otro nivel educativo le pone un plan de estudio que no
# cursó, y eso es exactamente lo que hace que la zona educativa lo rechace.
class DocumentosOficialesTest < ActiveSupport::TestCase
  # ── la 31059, que es de MEDIA GENERAL ─────────────────────────────────────

  test "la certificación 31059 se emite para bachillerato" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      assert CertificacionDeCalificaciones.new(student: esc.alumno).emitible?
    end
  end

  # ⚠️ Primaria se certifica con otra forma. Emitir una 31059 con las notas de
  # 5to Grado le pone al papel un plan de estudio que ese alumno no cursó.
  test "la certificación 31059 NO se emite para primaria" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      armador = CertificacionDeCalificaciones.new(student: esc.alumno)

      assert_not armador.emitible?
      assert_equal [ "6to Grado · 2025-2026" ], armador.anos_fuera_del_plan
    end
  end

  test "la calificación va en número y en letras, no en literal" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 11)
      area = CertificacionDeCalificaciones.para(student: esc.alumno)
                                          .dig("anos", 0, "areas", 0)

      assert_equal 11, area["numero"]
      assert_equal "ONCE", area["letras"], "es el número escrito, no el literal A–E"
      assert_equal "F", area["te"]
    end
  end

  # Art. 112: la nota de la segunda oportunidad es la definitiva, y el formato
  # la marca con `R`.
  test "una materia reparada se marca con R" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 12, reparacion: 12)
      area = CertificacionDeCalificaciones.para(student: esc.alumno).dig("anos", 0, "areas", 0)

      assert_equal "R", area["te"]
    end
  end

  # ⚠️ El ordinal sale del GRADO, no de la posición: quien repite tercer año
  # tiene dos recuadros y los dos dicen TERCER AÑO, no «SEXTO».
  test "el ordinal del año sale del grado" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 15)

      assert_equal "PRIMER AÑO", CertificacionDeCalificaciones.para(student: esc.alumno)
                                                              .dig("anos", 0, "ordinal")
    end
  end

  # ── los documentos de PRIMARIA ────────────────────────────────────────────

  # ⚠️ El último grado de primaria promueve al nivel siguiente y lleva
  # CERTIFICADO; los demás llevan CONSTANCIA DE PROSECUCIÓN.
  test "el último grado de primaria emite el certificado" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 18)
      d = DocumentoDePrimaria.para(enrollment: esc.inscripcion)

      assert_equal "certificado", d["tipo"]
      assert_equal "al 1er Año del Nivel de Educación Media", d["promovido_a"]
    end
  end

  test "un grado con siguiente emite la constancia de prosecución" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      # El escenario trae «6to Grado»; se agrega el 7mo para que tenga a dónde
      # promover, que es lo que decide cuál documento va.
      Grade.create!(school: esc.colegio, name: "7mo Grado", level: :primaria)
      libro(esc, 18)
      d = DocumentoDePrimaria.para(enrollment: esc.inscripcion)

      assert_equal "prosecucion", d["tipo"]
      assert_equal "al 7mo Grado del Nivel de Educación Primaria", d["promovido_a"]
    end
  end

  # ⚠️ Certifican el LITERAL, no el número: es la escala A–E de primaria.
  test "el documento de primaria certifica el literal del año" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 19)

      assert_equal "A", DocumentoDePrimaria.para(enrollment: esc.inscripcion)["literal"]
    end
  end

  test "un alumno de bachillerato no recibe el documento de primaria" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      assert_not DocumentoDePrimaria.new(enrollment: esc.inscripcion).emitible?
    end
  end

  # ── los dos formatos de la 31059 ──────────────────────────────────────────

  test "la 31059 sale en PDF y en Excel, con los mismos datos" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 15)
      datos = CertificacionDeCalificaciones.para(student: esc.alumno)

      assert_operator CertificacionPdf.new(datos).render.bytesize, :>, 1000
      assert_operator CertificacionXlsx.new(datos).to_stream.size, :>, 1000
      assert_match(/certificacion-31059/, CertificacionXlsx.new(datos).nombre_de_archivo)
    end
  end

  private

  def libro(esc, nota, reparacion: nil)
    FinalGradeBook.create!(enrollment: esc.inscripcion, subject: esc.materia,
                           annual_average: nota, final_score: nota,
                           remedial_exam_score: reparacion, origen: :importada)
  end
end
