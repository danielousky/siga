require "test_helper"

# El boletín de un grado que califica por literal (MOR-129).
#
# Dos cosas que solo se rompen acá, y que `EscalaLiteralTest` no puede cubrir:
#
#   1. que la escala quede CONGELADA en el snapshot, y
#   2. que el literal vaya en la nota del AÑO y no en la del lapso.
#
# Se prueba contra `ReportCardPdf.filas_anuales` y no contra el PDF renderizado
# porque **el texto de un PDF de Prawn no se puede leer desde afuera**: la fuente
# va embebida como subconjunto y los caracteres quedan mapeados a glifos.
# Verificado: buscar "A (" en los 32 KB del PDF no encuentra nada.
class BoletinConLiteralTest < ActiveSupport::TestCase
  setup do
    @escenario = escenario_academico

    # Una nota de 19 al 100 % del primer lapso. Con tres lapsos y solo uno
    # cargado, el anual y la definitiva también dan 19 (Art. 111: promedio de
    # los lapsos QUE TIENEN nota; los vacíos no cuentan como cero).
    con_el_colegio(@escenario.colegio) do
      act = actividad(@escenario, lapso: @escenario.lapso(1), peso: 100, descripcion: "Examen")
      nota(act, @escenario.alumno, 19)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El snapshot es el archivo
  # ══════════════════════════════════════════════════════════════════════════

  test "el snapshot guarda con qué escala se emitió" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)

      datos = ReportCardData.para(enrollment: @escenario.inscripcion)

      assert_equal "literal", datos.dig("seccion", "escala")
    end
  end

  # La razón por la que la escala va en el snapshot y no se lee de la base al
  # imprimir: el boletín que la familia tiene en la mano y la verificación
  # pública tienen que decir lo mismo, para siempre. Si el colegio cambia la
  # escala en marzo, el papel de diciembre no puede cambiar con él.
  test "cambiar la escala del grado no altera un boletín ya emitido" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)
      datos = ReportCardData.para(enrollment: @escenario.inscripcion)

      @escenario.grado.update!(escala: :numerica)

      assert_equal "literal", datos.dig("seccion", "escala"),
                   "el snapshot dejó de ser un archivo: siguió a la base"
      assert_includes filas_planas(datos), "19 (A)",
                      "el boletín emitido tiene que seguir imprimiéndose como se emitió"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El literal va en el AÑO, no en el lapso
  # ══════════════════════════════════════════════════════════════════════════
  #
  # "Los literales son la nota final del año escolar" —Cyndi—. Durante los
  # lapsos primaria evalúa con competencias e indicadores y una rúbrica de cinco
  # niveles, que es MOR-136 y no existe todavía. Ponerle una letra al lapso sería
  # inventar una escala que la maestra no usa.

  # Tres lugares, y los tres son del año: ANUAL, DEFINITIVA y el PROMEDIO
  # GENERAL. El tercero importa más de lo que parece: es el que el Certificado de
  # Educación Primaria pide cuando dice *"cursó el 6to Grado correspondiéndole el
  # literal: ___"*. Un literal por grado, y ese es.
  test "las notas del año llevan literal y número" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)

      filas = ReportCardPdf.filas_anuales(ReportCardData.para(enrollment: @escenario.inscripcion))

      materia = filas.find { |f| f.first == @escenario.materia.name }
      assert_equal "19 (A)", materia[-3], "la columna ANUAL"
      assert_equal "19 (A)", materia[-1], "la columna DEFINITIVA"

      promedio = filas.find { |f| f.first == "PROMEDIO GENERAL" }
      assert_equal "19 (A)", promedio[-1], "el literal del grado, que es lo que pide el certificado"
    end
  end

  test "la columna del lapso sigue en número aunque el grado sea por literal" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)
      datos = ReportCardData.para(enrollment: @escenario.inscripcion)

      # La fila de la materia con nota: MATERIA | L1 | L2 | L3 | ANUAL | REPAR | DEFINIT
      fila = ReportCardPdf.filas_anuales(datos).find { |f| f.include?("19 (A)") }

      assert_equal "19", fila[1], "la nota del primer lapso tiene que ir en número pelado"
      assert_not_includes fila[1], "A", "el lapso no se califica con letras: eso es MOR-136"
    end
  end

  # La reparación es el resultado de UN examen, no la calificación del año.
  test "la reparación queda en número" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)
      libro = FinalGradeBook.find_by(enrollment_id: @escenario.inscripcion.id,
                                     subject_id: @escenario.materia.id)
      libro.update!(remedial_exam_score: 12)

      fila = ReportCardPdf.filas_anuales(ReportCardData.para(enrollment: @escenario.inscripcion))
                          .find { |f| f.first == @escenario.materia.name }

      assert_equal "12", fila[-2], "la reparación es un examen, no la nota del año"
    end
  end

  test "un grado de media general no muestra ninguna letra" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :numerica)

      celdas = filas_planas(ReportCardData.para(enrollment: @escenario.inscripcion))

      assert_includes celdas, "19"
      assert_empty celdas.grep(/\A\d+ \([A-E]\)\z/), "media general no lleva literal"
    end
  end

  # Sin nota no es cero y tampoco es E. En el papel tiene que leerse en letras,
  # nunca como una calificación.
  test "una materia sin corregir dice “Sin nota”, no E" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)

      celdas = filas_planas(ReportCardData.para(enrollment: @escenario.inscripcion))

      assert_includes celdas, "Sin nota"
      assert_empty celdas.grep(/\A0 \(E\)\z/), "una materia sin corregir no está reprobada"
    end
  end

  # El PDF sigue generándose: la costura no puede haber roto el dibujo.
  test "el boletín por literal se sigue imprimiendo" do
    con_el_colegio(@escenario.colegio) do
      @escenario.grado.update!(escala: :literal)
      emisor = User.create!(name: "Dir", last_name: "Emisor", password: "123123",
                            email: "dir.emisor@literal.test")
      Admin.create!(user: emisor, school: @escenario.colegio, role: :director)

      boletin = ReportCard.create!(
        enrollment: @escenario.inscripcion, evaluation_moment: nil, issued_by: emisor,
        snapshot: ReportCardData.para(enrollment: @escenario.inscripcion)
      )

      bytes = ReportCardPdf.new(boletin).render

      assert bytes.start_with?("%PDF"), "tiene que salir un PDF de verdad"
    end
  end

  private

  def filas_planas(datos)
    ReportCardPdf.filas_anuales(datos).flatten
  end
end
