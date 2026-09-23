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
#
# ## ⚠️ Y desde el 22 de septiembre ese camino ni se ofrece
#
# Daniel: *«una mejor UX es que el botón de eliminar esté disabled si tiene
# notas, en lugar de intentar una acción que no va a poder hacer»*. El botón se
# apaga y dice por qué, así que el «Content missing» que originó este archivo ya
# no tiene por dónde ocurrir. La lección se queda escrita: es la misma trampa
# que mordió cuatro veces.
class BorrarDesdeElPlanSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }
  end

  def evaluacion_con_notas(cuantas)
    con_el_colegio(@a.colegio) do
      e = actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen del lapso",
                    mide: @competencia)
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

    # ⚠️ El clic se REINTENTA hasta que la fila desaparezca: Turbo se traga el
    # que cae mientras hidrata, el elemento puede quedar viejo si repinta la
    # fila entre el `find` y el `click`, y en las dos el borrado no ocurre.
    tocar_para_cerrar(".plan-evaluacion-nombre-campo[value='Examen del lapso']") do
      accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click }
    end

    assert_no_text "Content missing"
    assert_selector ".plan-competencia--sin-evaluar"
  end

  # ⚠️ CON NOTAS ya no hay botón que tocar: se apaga y dice por qué.
  #
  # Daniel, 22 de septiembre: *«una mejor UX es que el botón de eliminar esté
  # disabled si tiene notas, en lugar de intentar una acción que no va a poder
  # hacer. Lo que sí tenemos que indicarle es por qué está bloqueada la
  # eliminación»*.
  #
  # Los dos tests que probaban el intento fallido se van con él: probaban que el
  # plan no se rompiera al recibir el rechazo, y ese camino ya no existe desde
  # la pantalla. El modelo sigue impidiéndolo —`restrict_with_error`— y eso se
  # prueba donde vive, en el modelo.
  test "con notas cargadas el botón se apaga, y dice cuántas lo impiden" do
    evaluacion_con_notas(2)
    ir_al_plan

    assert_no_selector ".plan-evaluacion [aria-label='Borrar']"

    apagado = find(".plan-evaluacion button[aria-disabled='true']")
    assert_match(/no se puede borrar/i, apagado["data-tooltip"])
    assert_match "2 notas cargadas", apagado["data-tooltip"]

    # Y tocarlo no hace nada: ni navega, ni abre un confirm, ni rompe el frame.
    apagado.click
    assert_no_text "Content missing"
    assert_selector ".plan-evaluacion-nombre-campo[value='Examen del lapso']"
  end

  # ⚠️ El aviso decía «se borran también las notas cargadas», que era lo
  # contrario de lo que pasaba. Ahora sí se borran cosas —los indicadores— y por
  # eso el aviso tiene que nombrarlas.
  test "sin notas, el aviso dice que los indicadores se van con ella" do
    evaluacion_con_notas(0)
    ir_al_plan

    mensaje = tocando { accept_confirm { find(".plan-evaluacion [aria-label='Borrar']").click } }

    assert_match "Deja de contar en el promedio", mensaje
    assert_match(/Se borran también/, mensaje)
    assert_no_match(/nota cargada/, mensaje)
  end
end
