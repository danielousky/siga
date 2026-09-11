require "test_helper"

# Una calificación es un NÚMERO o una VALORACIÓN, nunca las dos.
#
#     INICIAL     descripcion = "Se integró al grupo…"   final_moment_score = —
#     PRIMARIA    descripcion = —                        final_moment_score = 17
#     MEDIA       descripcion = —                        final_moment_score = 17
#
# ⚠️ Y la regla vive en las DOS capas. El `CHECK` de PostgreSQL no sobra: el
# importador de historial y `GradeCalculator` escriben sin pasar por acá, y una
# fila con las dos cosas dejaría a la boleta eligiendo cuál mostrar.
class CalificacionDescriptivaTest < ActiveSupport::TestCase
  # ── Inicial: se describe ──────────────────────────────────────────────────

  test "en Inicial la valoración se guarda sin número" do
    esc = escenario_academico(nombre: "Jardín", nivel: :preescolar)

    con_el_colegio(esc.colegio) do
      nota = MomentGrade.new(enrollment: esc.inscripcion, subject: esc.materia,
                             evaluation_moment: esc.lapso(1),
                             descripcion: "Comparte sus juegos y espera su turno.")

      assert nota.save, nota.errors.full_messages.to_sentence
      assert_nil nota.final_moment_score
    end
  end

  test "en Inicial una valoración vacía no vale" do
    esc = escenario_academico(nombre: "Jardín", nivel: :preescolar)

    con_el_colegio(esc.colegio) do
      nota = MomentGrade.new(enrollment: esc.inscripcion, subject: esc.materia,
                             evaluation_moment: esc.lapso(1))

      assert_not nota.valid?
      assert_includes nota.errors.full_messages.to_sentence, "la valoración"
    end
  end

  # ── Primaria y Media: se califica ─────────────────────────────────────────

  test "fuera de Inicial la nota sigue siendo obligatoria" do
    esc = escenario_academico(nombre: "Liceo", nivel: :secundaria)

    con_el_colegio(esc.colegio) do
      nota = MomentGrade.new(enrollment: esc.inscripcion, subject: esc.materia,
                             evaluation_moment: esc.lapso(1),
                             descripcion: "Un texto donde va un número.")

      assert_not nota.valid?, "bachillerato califica del 1 al 20"
    end
  end

  # ── La exclusión, en las dos capas ────────────────────────────────────────

  test "nunca las dos cosas a la vez" do
    esc = escenario_academico(nombre: "Escuela", nivel: :primaria)

    con_el_colegio(esc.colegio) do
      nota = MomentGrade.new(enrollment: esc.inscripcion, subject: esc.materia,
                             evaluation_moment: esc.lapso(1),
                             final_moment_score: 17, descripcion: "Y además un texto.")

      assert_not nota.valid?
      assert_includes nota.errors.full_messages.to_sentence, "no las dos"
    end
  end

  # ⚠️ Sin pasar por el modelo: es el camino del importador y del calculador.
  test "la base tampoco admite las dos" do
    esc = escenario_academico(nombre: "Escuela", nivel: :primaria)

    con_el_colegio(esc.colegio) do
      error = assert_raises(ActiveRecord::StatementInvalid) do
        MomentGrade.insert_all!([ {
          enrollment_id: esc.inscripcion.id, subject_id: esc.materia.id,
          evaluation_moment_id: esc.lapso(1).id, school_id: esc.colegio.id,
          final_moment_score: 17, descripcion: "Y además un texto.",
          created_at: Time.current, updated_at: Time.current
        } ])
      end

      assert_match(/moment_grades_numero_o_texto/, error.message)
    end
  end
end
