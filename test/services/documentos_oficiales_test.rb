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

  # ⚠️ 6to Grado cierra la primaria y lleva CERTIFICADO; los demás llevan
  # CONSTANCIA DE PROSECUCIÓN. La Educación Primaria venezolana son SEIS grados
  # y lo fija la Ley Orgánica de Educación: un plantel la dicta completa o no la
  # dicta.
  test "6to Grado emite el certificado, que promueve al nivel de media" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 18)
      d = DocumentoDePrimaria.para(enrollment: esc.inscripcion)

      assert_equal "certificado", d["tipo"]
      assert_equal "al 1er Año del Nivel de Educación Media", d["promovido_a"]
    end
  end

  test "cualquier otro grado emite la constancia de prosecución" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      esc.grado.update!(name: "3er Grado")
      libro(esc, 18)
      d = DocumentoDePrimaria.para(enrollment: esc.inscripcion)

      assert_equal "prosecucion", d["tipo"]
      assert_equal "al 4to Grado del Nivel de Educación Primaria", d["promovido_a"]
    end
  end

  # ⚠️ El bug que esto reemplaza: la regla vieja preguntaba «¿existe un grado
  # siguiente en este colegio?», y así un plantel que todavía no cargó 5to y 6to
  # le habría emitido CERTIFICADO DE EDUCACIÓN PRIMARIA a un alumno de 3er Grado.
  # Un documento oficial no puede depender de qué alcanzó a cargar la secretaria.
  test "no depende de qué grados estén cargados en el colegio" do
    esc = escenario_academico(nivel: :primaria)

    con_el_colegio(esc.colegio) do
      esc.grado.update!(name: "3er Grado")
      assert_equal 1, Grade.count, "este colegio solo tiene un grado cargado"
      libro(esc, 18)

      assert_equal "prosecucion", DocumentoDePrimaria.para(enrollment: esc.inscripcion)["tipo"]
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

  # ── lo que la 31059 dice en el papel ──────────────────────────────────────

  # ⚠️ Cada dato de la 31059 va en una casilla de alto fijo, y lo que no cabía
  # se cortaba sin avisar. En Caracas la fecha de expedición salía «LIBERTADOR,
  # DISTRITO CAPITAL 5 DE OCTUBRE DE» — sin el año, en un documento que vale
  # tres años DESDE esa fecha.
  #
  # Estuvo así desde que existe la certificación: el test de arriba solo mira
  # que el archivo pese más de mil bytes. Apareció leyendo el PDF.
  #
  # Los lugares son municipios de verdad, del más corriente al más largo del
  # país, y la fecha es la más larga del calendario.
  test "la fecha de expedición de la 31059 sale con su año, por largo que sea el lugar" do
    esc = escenario_academico(nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      libro(esc, 15)

      travel_to Time.zone.local(2026, 9, 27, 10) do
        [ "Libertador, Distrito Capital", "San Cristóbal, Táchira", "José Felipe Márquez Cañizales, Trujillo",
          "Monseñor José Vicente de Unda, Portuguesa" ].each do |lugar|
          datos  = CertificacionDeCalificaciones.para(student: esc.alumno, expedida_en: lugar)
          textos = textos_de(CertificacionPdf.new(datos).render).map(&:texto)

          assert_includes textos, "#{lugar.upcase} 27 DE SEPTIEMBRE DE 2026",
                          "la fecha salió cortada: #{textos.grep(/SEPTIEMBRE|#{lugar.upcase[0, 8]}/).inspect}"
        end
      end
    end
  end

  private

  def libro(esc, nota, reparacion: nil)
    FinalGradeBook.create!(enrollment: esc.inscripcion, subject: esc.materia,
                           annual_average: nota, final_score: nota,
                           remedial_exam_score: reparacion, origen: :importada)
  end
end
