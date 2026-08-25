require "test_helper"

# Una calificación importada no la recalcula ni la borra nadie (MOR-126, tanda 3).
#
# ## Por qué hace falta decirlo
#
# Un colegio que llega a SIGA trae «Matemática · 1er lapso 15» de años
# anteriores. Lo que NO trae son las cinco evaluaciones que produjeron ese 15:
# están en papel, o se perdieron.
#
# Y `GradeCalculator` borra exactamente eso — con razón: una calificación de
# lapso sin actividades que la respalden contaría en el promedio anual para
# siempre. La regla está bien. Lo que faltaba era distinguir **sin respaldo** de
# **con un respaldo que no está acá**.
#
# Medido antes de escribir la solución: la nota histórica no sobrevivía a UN solo
# recálculo.
class NotasImportadasTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico
  end

  # ── lo que se protege ─────────────────────────────────────────────────────

  test "una nota de lapso importada sobrevive al recálculo" do
    con_el_colegio(@esc.colegio) do
      nota = importar_lapso(1, 17)

      GradeCalculator.calculate_moment_grade(
        enrollment: @esc.inscripcion, subject: @esc.materia, evaluation_moment: @esc.lapso(1)
      )

      assert MomentGrade.exists?(nota.id), "la borró el recálculo"
      assert_equal 17, nota.reload.final_moment_score.to_i
    end
  end

  # `notas:recalcular` existe para reparar inconsistencias y recorre todo. Es
  # justo el comando que un colegio correría después de importar.
  test "sobrevive al recálculo completo de la inscripción" do
    con_el_colegio(@esc.colegio) do
      importar_lapso(1, 17)

      GradeCalculator.calculate_all_for_enrollment(@esc.inscripcion)

      assert_equal 1, MomentGrade.count
    end
  end

  # El anual importado manda sobre el promedio de los lapsos: es la definitiva
  # certificada, la que está impresa en el boletín que el colegio ya entregó.
  test "un libro anual importado no se recalcula" do
    con_el_colegio(@esc.colegio) do
      importar_lapso(1, 10)
      libro = FinalGradeBook.create!(enrollment: @esc.inscripcion, subject: @esc.materia,
                                     annual_average: 15, final_score: 15, origen: :importada)

      GradeCalculator.calculate_final_grade(enrollment: @esc.inscripcion, subject: @esc.materia)

      assert_equal 15, libro.reload.annual_average.to_i, "el promedio de lapsos habría dado 10"
    end
  end

  # ── lo que NO se protege, y es a propósito ────────────────────────────────

  # Una nota calculada sin respaldo se sigue borrando: esa regla no se aflojó.
  test "una nota calculada sin actividades se sigue borrando" do
    con_el_colegio(@esc.colegio) do
      MomentGrade.create!(enrollment: @esc.inscripcion, subject: @esc.materia,
                          evaluation_moment: @esc.lapso(1), final_moment_score: 17)

      GradeCalculator.calculate_moment_grade(
        enrollment: @esc.inscripcion, subject: @esc.materia, evaluation_moment: @esc.lapso(1)
      )

      assert_equal 0, MomentGrade.count
    end
  end

  # ⚠️ Si el colegio decide cargar las evaluaciones de verdad, esas ganan.
  #
  # Es una acción explícita de una persona y tiene que poder ganarle a un import:
  # si no, un lapso importado quedaría congelado para siempre y el profesor no
  # entendería por qué sus notas no hacen nada.
  test "cargar actividades de verdad convierte la nota en calculada" do
    con_el_colegio(@esc.colegio) do
      nota = importar_lapso(1, 17)

      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      nota(examen, @esc.alumno, 12)

      assert_equal 12, nota.reload.final_moment_score.to_i
      assert nota.calculada?, "quedó marcada como importada y ya no lo es"
    end
  end

  # Y el default protege lo que ya existe: todo lo que hay en la base lo produjo
  # el cálculo, así que una fila sin decir nada es calculada.
  test "una nota nueva es calculada salvo que se diga lo contrario" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      nota(examen, @esc.alumno, 14)

      assert MomentGrade.first.calculada?
    end
  end

  private

  def importar_lapso(numero, puntaje)
    MomentGrade.create!(enrollment: @esc.inscripcion, subject: @esc.materia,
                        evaluation_moment: @esc.lapso(numero),
                        final_moment_score: puntaje, origen: :importada)
  end
end
