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
    assert_selector ".pestana.activa", text: "Planificar"

    click_on "Agregar competencia"

    # ⚠️ La URL NO cambia: es la prueba de que el frame hizo su trabajo. Con
    # Turbo apagado el navegador iría a `/competencias/new`.
    assert_current_path planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    assert_selector "textarea[name='competency[descripcion]']"
    # Y sigo en la sección: la pestaña y el título están donde estaban.
    assert_selector ".pestana.activa", text: "Planificar"
  end

  # ⚠️ El alta desde el plan ya no es esta pantalla: desde el 9 de septiembre se
  # despliega un panel debajo del botón y pide solo la descripción —los
  # indicadores se escriben después, uno por uno—. Lo cubre entero
  # `alta_en_linea_test`; acá quedaría probando un formulario que ese camino no
  # muestra.

  # ⚠️ Cancelar devuelve la lista, no navega a `/competencias`. Es el mismo
  # frame: se pide el plan y reemplaza al formulario.
  test "cancelar devuelve la lista sin salir de la sección" do
    click_on "Agregar competencia"
    click_on "Cancelar"

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

    click_on "Ir a planificar"

    assert_selector ".pestana.activa", text: "Planificar"
  end

  # ⚠️ Al guardar, el frame se reemplaza por la LIBRETA con su columna nueva.
  # Redirigiendo a la ficha de la evaluación —que era lo que hacía— el frame se
  # habría llenado con una pantalla que no es la libreta.
  test "al guardar, la columna aparece en la libreta" do
    lapso = @a.escenario.lapso(2)
    plan = con_el_colegio(@a.colegio) { competencia_con(0, "Resuelve problemas", lapso: lapso) }
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: lapso.id)
    all("a", text: "Agregar evaluación").first.click

    within(".alta-en-linea") do
      fill_in "evaluation_activity[description]", with: "Prueba corta"
      # ⚠️ La competencia todavía no tiene indicadores, así que se escriben en
      # el mismo panel: es la otra mitad de lo que pidió Daniel —«asignarle
      # competencias ya creadas y a su vez agregar también otros indicadores»—
      # y sin uno la evaluación no se guarda.
      fill_in "evaluation_activity[indicadores_nuevos][#{plan.id}]", with: "Suma con reagrupación"
      click_on "Agregar"
    end
    visit section_path(@a.seccion, area: @area.id, lapso: lapso.id)

    assert_selector ".libreta-columna-nombre", text: "Prueba corta"
    assert_no_selector "input[name='evaluation_activity[description]']"
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
    all("a", text: "Agregar evaluación").first.click
    assert_selector "input[name='evaluation_activity[description]']"

    click_on "Cancelar"

    assert_no_text "Content missing"
    # ⚠️ Por la CLASE, no por el `name`: desde que la fila se edita en su sitio,
    # su campo y el del formulario se llaman igual —los dos salen de
    # `form_with model: evaluacion`— y el selector por nombre encuentra los dos.
    assert_no_selector ".form-acciones"
    assert_selector ".plan-ponderacion"
  end

  test "cancelar el alta devuelve el plan" do
    visit planificar_section_path(@a.seccion, area: @area.id, lapso: @lapso.id)
    all("a", text: "Agregar evaluación").first.click

    within(".alta-en-linea") { click_on "Cancelar" }

    assert_no_text "Content missing"
    assert_selector ".pestana.activa", text: "Planificar"
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
