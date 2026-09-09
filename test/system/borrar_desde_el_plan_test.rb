require "application_system_test_case"

# Borrar una evaluación desde la pestaña Planificar (QA del 8 de septiembre).
#
# Daniel, con una captura de la planificación entera reemplazada por dos
# palabras: *«cuando intenté borrar una evaluación desde el panel»* →
# **Content missing**.
#
# ## Qué pasaba
#
# Una evaluación CON NOTAS no se borra (`restrict_with_error`), y el error
# redirigía a la ficha de la evaluación — una pantalla que no tiene el frame
# «plan». Turbo pedía «plan», recibía una respuesta sin él, y escribía el hueco
# donde estaba el plan.
#
#     [🗑] ──► DELETE (frame «plan») ──► falla ──► redirect al `show`
#                                                  el `show` no tiene «plan»
#                                                        ▼
#                                                  «Content missing»
#
# ⚠️ Se prueba en un navegador de verdad y no con `assert_redirected_to`: la
# falla NO está en el redirect —que era correcto para una petición normal— sino
# en lo que Turbo hace al recibirlo dentro de un frame. Un test de integración
# habría pasado en verde con la pantalla rota.
class BorrarDesdeElPlanSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }
  end

  def evaluacion_con_notas(cuantas)
    con_el_colegio(@a.colegio) do
      e = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen del lapso")
      e.competencies = [ @competencia ]
      @a.seccion.enrollments.first(cuantas).each do |inscripcion|
        ActivityGrade.create!(evaluation_activity: e, student: inscripcion.student, score: 15)
      end
      e
    end
  end

  def ir_al_plan
    entrar_como @a.profesor
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  test "sin notas cargadas, se borra y el plan queda en su sitio" do
    evaluacion_con_notas(0)
    ir_al_plan

    accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click }

    assert_no_text "Content missing"
    assert_no_selector ".plan-evaluacion-nombre-campo[value='Examen del lapso']"
    assert_selector ".plan-competencia--sin-evaluar"
  end

  test "con notas cargadas no se borra, y el plan NO se rompe" do
    evaluacion_con_notas(2)
    ir_al_plan

    accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click }

    assert_no_text "Content missing"
    # Sigue ahí, y se dice por qué: el mensaje se pinta DENTRO del frame.
    # ⚠️ El nombre ya no es texto de la página sino el `value` de un campo,
    # desde que la fila se edita en su sitio.
    assert_selector ".plan-evaluacion-nombre-campo[value='Examen del lapso']"
    assert_text(/no se puede eliminar|Notas de la evaluación/i)
  end

  # ⚠️ El aviso decía «se borran también las notas cargadas», que es lo
  # contrario de lo que pasa. Quien lo lee acepta creyendo otra cosa.
  test "el aviso de confirmación dice la verdad" do
    evaluacion_con_notas(2)
    ir_al_plan

    mensaje = accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click }

    assert_match "2 notas cargadas", mensaje
    assert_match "no se puede borrar", mensaje
  end

  test "sin notas, el aviso no habla de notas" do
    evaluacion_con_notas(0)
    ir_al_plan

    mensaje = accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click }

    assert_match "Deja de contar en el promedio", mensaje
    assert_no_match(/nota/, mensaje)
  end
end
