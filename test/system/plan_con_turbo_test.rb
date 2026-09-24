require "application_system_test_case"

# El formulario del plan se levanta EN la sección, sin recargar (etapa ③).
#
# Daniel: *«vamos a cargar el formulario de las competencias en la misma
# sección. Cuando la persona haga clic en Registrar competencia, con Turbo te
# traes el form y lo levantas ahí mismo»* — y antes: *«vamos a explotar la
# velocidad y ligereza de Stimulus»*.
#
# ## Por qué esto necesita un navegador de verdad
#
# Un test de integración pide `/competencias/new` y encuentra el formulario:
# pasaría igual con Turbo apagado, con el frame mal nombrado o con la página
# recargándose entera. Lo que hay que comprobar es que **no se navega**, y eso
# solo se ve con un documento vivo.
class PlanConTurboSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @area = @a.escenario.materia
    @lapso = @a.escenario.lapso(1)
    entrar_como @a.profesor
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
  end

  test "el formulario aparece dentro de la pestaña, sin cambiar de página" do
    assert_selector ".pestana.activa", text: "Plan de Evaluación"

    tocar_para_ver("textarea[name='competency[descripcion]']") { click_on "Agregar competencia" }

    # ⚠️ La URL NO cambia: es la prueba de que el frame hizo su trabajo. Con
    # Turbo apagado el navegador iría a `/competencias/new`.
    assert_current_path planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    assert_selector "textarea[name='competency[descripcion]']"
    # Y sigo en la sección: la pestaña y el título están donde estaban.
    assert_selector ".pestana.activa", text: "Plan de Evaluación"
  end

  # ⚠️ El alta desde el plan ya no es esta pantalla: desde el 9 de septiembre se
  # despliega un panel debajo del botón y pide solo la descripción —los
  # indicadores se escriben después, uno por uno—. Lo cubre entero
  # `alta_en_linea_test`; acá quedaría probando un formulario que ese camino no
  # muestra.

  # ⚠️ Cancelar devuelve la lista, no navega a `/competencias`. Es el mismo
  # frame: se pide el plan y reemplaza al formulario.
  test "cancelar devuelve la lista sin salir de la sección" do
    tocar_para_ver(".alta-en-linea") { click_on "Agregar competencia" }
    tocar_para_cerrar(".alta-en-linea") { click_on "Cancelar" }

    assert_current_path planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    assert_no_selector ".form-actions"
  end

  # ── Y lo mismo con las EVALUACIONES ───────────────────────────────────────
  #
  # ⚠️ Con la libreta VACÍA lo que se ofrece es el paso previo —planificar— y no
  # un alta suelta: una evaluación nace colgada de una competencia, y creada
  # desde la libreta nacería sin medir ninguna. El botón de la cabecera se
  # retiró el 9 de septiembre; Daniel: «este botón no va, ya quedaría todo en la
  # pestaña de planificación».
  test "la libreta vacía enseña el paso previo" do
    visit section_path(@a.seccion, area: @area.id, lapso: @a.escenario.lapso(2).id)

    assert_text "Antes hace falta"
    assert_no_selector "a", text: "Agregar evaluación"

    tocar_para_ir_a(planificar_section_path(@a.seccion)) { click_on "Ir a planificar" }

    assert_selector ".pestana.activa", text: "Plan de Evaluación"
  end

  # ⚠️ Al guardar, el frame se reemplaza por la LIBRETA con su columna nueva.
  # Redirigiendo a la ficha de la evaluación —que era lo que hacía— el frame se
  # habría llenado con una pantalla que no es la libreta.
  test "al guardar, la columna aparece en la libreta" do
    lapso = @a.escenario.lapso(2)
    con_el_colegio(@a.colegio) { competencia_con(0, "Resuelve problemas", lapso: lapso) }
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: lapso.id)
    tocar_para_ver(".plan-evaluacion--naciendo") { all("a", text: "Agregar evaluación").first.click }

    # ⚠️ La fila nace SIN indicadores, y es a propósito: un indicador cuelga de
    # la evaluación que lo mide, y esa evaluación todavía no existe. Se agregan
    # sobre la fila ya guardada, en su bloque «Indicadores que mide».
    within(".plan-evaluacion--naciendo") do
      fill_in "evaluation_activity[description]", with: "Prueba corta"
      find("button[type='submit']").click
    end
    visit section_path(@a.seccion, area: @area.id, lapso: lapso.id)

    assert_selector ".libreta-columna-nombre", text: "Prueba corta"
    assert_no_selector "input[name='evaluation_activity[description]']"
  end

  # ── Deslizar el peso (23 de septiembre) ───────────────────────────────────
  #
  # Daniel: *«en el porcentaje podemos agregar un rango en la misma línea,
  # pequeño… que la persona deslice en lugar de escribir»*.
  #
  # ⚠️ En un navegador de verdad, porque son tres piezas hablándose y ninguna
  # se ve desde un test de integración: el rango escribe en el número,
  # `reparto` recalcula la barra con el `input` que el rango finge, y
  # `edicion-en-linea` guarda con el `change` de soltar. Con el controlador sin
  # conectar, el HTML sigue siendo correcto y no pasa nada — que en este
  # proyecto ya ocurrió dos veces, en silencio.
  #
  # ⚠️ Con flechas y no arrastrando: el teclado mueve el rango de `step` en
  # `step` y dispara los MISMOS dos eventos que el ratón, sin depender de dónde
  # caiga el píxel.
  test "deslizar el peso escribe el número y lo guarda" do
    # ⚠️ El lapso 2 y no el 1: el 1 ya trae una actividad de peso 100, así que
    # el tope de cualquier otra sería su propio valor y la flecha no movería
    # nada — el test pasaría verde sin probar el deslizador.
    lapso = @a.escenario.lapso(2)
    evaluacion = con_el_colegio(@a.colegio) do
      c = competencia_con(0, "Resuelve problemas", lapso: lapso)
      e = actividad(@a.escenario, lapso: lapso, peso: 40, descripcion: "Examen del lapso")
      e.competencies = [ c ]
      e
    end
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: lapso.id)

    within(".plan-evaluacion") do
      find("input[type=range]").send_keys(:arrow_right)
      # El número acompaña en el acto: es el mismo dato visto dos veces.
      assert_field "evaluation_activity[weight_percentage]", with: "41"
    end

    # Y soltar guarda: el `change` del rango entra por el mismo `salir` que usa
    # el campo de texto, así que no hay un segundo camino de guardado.
    assert_selector ".plan-evaluacion--guardada"
    assert_equal 41, evaluacion.reload.weight_percentage
  end

  # ── Salir del formulario sin guardar ──────────────────────────────────────
  #
  # Daniel, 9 de septiembre: *«al cancelar la evaluación o clic en atrás no
  # retorna a la anterior»* — y lo que quedaba era «Content missing».
  #
  # «Cancelar» apuntaba a `/evaluaciones`, el listado, que no tiene ni el frame
  # «plan» ni el «libreta». Cancelar desde la pestaña se llevaba la pantalla.
  test "cancelar el alta de una evaluación devuelve el plan" do
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    # ⚠️ `all(...).first`: hay un «Agregar evaluación» por competencia y otro al
    # pie para las que no miden ninguna. Con el plan vacío había uno solo.
    tocar_para_ver(".plan-evaluacion--naciendo") { all("a", text: "Agregar evaluación").first.click }
    assert_selector "input[name='evaluation_activity[description]']"

    tocar_para_cerrar(".plan-evaluacion--naciendo") do
      find(".plan-evaluacion--naciendo a[aria-label='Descartar']").click
    end

    assert_no_text "Content missing"
    # ⚠️ Por la CLASE, no por el `name`: desde que la fila se edita en su sitio,
    # su campo y el del formulario se llaman igual —los dos salen de
    # `form_with model: evaluacion`— y el selector por nombre encuentra los dos.
    assert_no_selector ".form-acciones"
    assert_selector ".plan-ponderacion"
  end

  test "cancelar el alta devuelve el plan" do
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    tocar_para_ver(".plan-evaluacion--naciendo") { all("a", text: "Agregar evaluación").first.click }

    tocar_para_cerrar(".plan-evaluacion--naciendo") do
      find(".plan-evaluacion--naciendo a[aria-label='Descartar']").click
    end

    assert_no_text "Content missing"
    assert_selector ".pestana.activa", text: "Plan de Evaluación"
  end

  # ⚠️ Y el botón ATRÁS del navegador, que es la otra mitad de lo mismo: dentro
  # de un frame la URL no cambia, así que «atrás» rebobina la página entera —
  # con su frame restaurado del snapshot, no recargado.
  test "el botón atrás del navegador deja la pantalla entera" do
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    all("a", text: "Agregar evaluación").first.click
    assert_selector "input[name='evaluation_activity[description]']"

    page.go_back

    assert_no_text "Content missing"
  end
end
