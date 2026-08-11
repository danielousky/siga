require "test_helper"

# El cable entre cargar una nota y que el promedio cambie.
#
# Antes de MOR-96 `GradeCalculator` funcionaba y no lo llamaba nadie:
# `moment_grades` y `final_grade_books` existían como tablas y nunca se llenaban.
class RecalculoDeNotasTest < ActiveJob::TestCase
  setup do
    @esc = escenario_academico(pesos: [30, 30, 40], alumnos: 2)
  end

  test "guardar una nota escribe la calificación del lapso y la anual" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100, descripcion: "Examen")

      assert_difference -> { MomentGrade.count }, 1 do
        assert_difference -> { FinalGradeBook.count }, 1 do
          nota(examen, @esc.alumno, 18)
        end
      end

      assert_equal 18, MomentGrade.sole.final_moment_score
      assert_equal 18, FinalGradeBook.sole.final_score
    end
  end

  test "editar una nota mueve el promedio" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      registro = nota(examen, @esc.alumno, 18)

      registro.update!(score: 10)

      assert_equal 10, MomentGrade.sole.final_moment_score
      assert_equal 10, FinalGradeBook.sole.final_score
    end
  end

  test "borrar la última nota BORRA la calificación del lapso, no la deja vieja" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      registro = nota(examen, @esc.alumno, 18)
      assert_equal 1, MomentGrade.count

      registro.destroy

      # Una calificación de lapso sin notas que la respalden seguiría contando en
      # el promedio anual para siempre.
      assert_equal 0, MomentGrade.count
      assert_equal 0, FinalGradeBook.count
    end
  end

  test "borrar una nota de dos deja el promedio de la que queda" do
    con_el_colegio(@esc.colegio) do
      a = actividad(@esc, lapso: @esc.lapso(1), peso: 50, descripcion: "A")
      b = actividad(@esc, lapso: @esc.lapso(1), peso: 50, descripcion: "B")
      nota(a, @esc.alumno, 20)
      segunda = nota(b, @esc.alumno, 10)

      assert_equal 15, MomentGrade.sole.final_moment_score

      segunda.destroy

      assert_equal 20, MomentGrade.sole.final_moment_score, "queda solo la de 20, sobre su propio peso"
    end
  end

  test "la reparación sobrevive a que se borren todas las notas" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 100)
      registro = nota(examen, @esc.alumno, 8)

      FinalGradeBook.sole.update!(remedial_exam_score: 14)
      registro.destroy

      libro = FinalGradeBook.sole
      assert_nil libro.annual_average, "el anual ya no tiene respaldo"
      assert_equal 14, libro.remedial_exam_score, "pero la reparación la escribió una persona"
      assert_equal 14, libro.final_score
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El recálculo masivo
  # ══════════════════════════════════════════════════════════════════════════

  test "cambiar la ponderación encola el recálculo de la sección entera" do
    con_el_colegio(@esc.colegio) do
      a = actividad(@esc, lapso: @esc.lapso(1), peso: 50, descripcion: "A")
      actividad(@esc, lapso: @esc.lapso(1), peso: 50, descripcion: "B")

      assert_enqueued_with(job: RecalcularSeccionJob, args: [@esc.seccion, @esc.materia]) do
        a.update!(weight_percentage: 40)
      end
    end
  end

  test "cambiar la descripción NO encola nada: no mueve ningún promedio" do
    con_el_colegio(@esc.colegio) do
      a = actividad(@esc, lapso: @esc.lapso(1), peso: 50)

      assert_no_enqueued_jobs(only: RecalcularSeccionJob) do
        a.update!(description: "Otro nombre")
      end
    end
  end

  test "el job recalcula a TODOS los alumnos de la sección con la ponderación nueva" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @esc.lapso(1), peso: 60, descripcion: "Examen")
      taller = actividad(@esc, lapso: @esc.lapso(1), peso: 40, descripcion: "Taller")

      @esc.alumnos.each do |alumno|
        nota(examen, alumno, 20)
        nota(taller, alumno, 10)
      end

      # 20×60 + 10×40 = 1600 / 100 = 16
      assert_equal [16, 16], MomentGrade.order(:id).pluck(:final_moment_score).map(&:to_i)

      # Se invierte la ponderación sin tocar ninguna nota.
      taller.update!(weight_percentage: 20)
      examen.update!(weight_percentage: 80)
      perform_enqueued_jobs

      # 20×80 + 10×20 = 1800 / 100 = 18
      assert_equal [18, 18], MomentGrade.order(:id).pluck(:final_moment_score).map(&:to_i)
    end
  end

  test "el job lleva el colegio en el payload y no recorre otros" do
    ajeno = escenario_academico(nombre: "Colegio Ajeno")

    con_el_colegio(ajeno.colegio) do
      examen = actividad(ajeno, lapso: ajeno.lapso(1), peso: 100)
      nota(examen, ajeno.alumno, 20)
    end

    con_el_colegio(@esc.colegio) do
      a = actividad(@esc, lapso: @esc.lapso(1), peso: 50)
      actividad(@esc, lapso: @esc.lapso(1), peso: 50, descripcion: "B")
      nota(a, @esc.alumno, 12)

      a.update!(weight_percentage: 40)
    end

    # El job se ejecuta sin contexto, como un worker de verdad: el colegio tiene
    # que salir del payload (MOR-88).
    Current.reset
    perform_enqueued_jobs

    ajena = Current.sin_aislamiento do
      MomentGrade.unscoped.find_by(enrollment_id: ajeno.inscripcion.id)
    end
    assert_equal 20, ajena.final_moment_score, "la nota del otro colegio quedó intacta"
  end
end
