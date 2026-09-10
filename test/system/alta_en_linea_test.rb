require "application_system_test_case"

# Agregar sin salir del plan (QA del 9 de septiembre).
#
# Daniel: *«el "+ agregar evaluación" no debe ir a otra vista, puede agregarse
# ahí mismo desplazando hacia abajo un panel con los campos faltantes: título,
# % y fecha. No hace falta perderse a otra vista totalmente independiente»* — y
# lo mismo para las competencias.
class AltaEnLineaSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @competencia = con_el_colegio(@a.colegio) do
      c = competencia_con(0, "El niño debe graficar funciones", lapso: @lapso)
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen").competencies = [ c ]
      c
    end
    entrar_como @a.profesor
    ir_al_plan
  end

  def ir_al_plan
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  def panel = find(".alta-en-linea")

  test "el formulario se despliega en el sitio, sin cambiar de página" do
    all("a", text: "Agregar evaluación").first.click

    assert_selector ".alta-en-linea"
    assert_current_path(/planificar/)
    # ⚠️ El plan sigue ahí: no es otra pantalla, es un panel debajo del botón.
    assert_selector ".plan-competencia-descripcion-campo"
    assert_selector ".plan-ponderacion"
  end

  # ⚠️ Los campos FALTANTES y solo esos: la sección, el área, el lapso y la
  # competencia ya están elegidos. Volver a preguntarlos daría además la
  # oportunidad de crear la evaluación en otra sección sin darse cuenta.
  test "solo pregunta título, peso y fecha" do
    all("a", text: "Agregar evaluación").first.click

    within(".alta-en-linea") do
      assert_selector "input[name='evaluation_activity[description]']"
      assert_selector "input[name='evaluation_activity[weight_percentage]']"
      assert_selector "input[name='evaluation_activity[date_scheduled]']"
      assert_no_selector "select[name='evaluation_activity[asignacion]']"
      assert_no_selector "select[name='evaluation_activity[evaluation_moment_id]']"
    end
  end

  test "el peso nace con lo que falta para cerrar el lapso" do
    all("a", text: "Agregar evaluación").first.click

    assert_equal "60", panel.find("input[name='evaluation_activity[weight_percentage]']").value,
                 "el examen vale 40: quedan 60"
  end

  # ⚠️ Nacía en `Date.current`, y en septiembre de 2026 eso cae FUERA del año
  # 2025-2026 —que terminó el 31 de julio—: el campo la rechazaba con «el valor
  # debe ser igual o anterior a 31/07/2026» y el alta no se podía guardar sin
  # tocar la fecha primero.
  test "la fecha nace dentro del año escolar, aunque hoy quede fuera" do
    all("a", text: "Agregar evaluación").first.click

    fecha = Date.parse(panel.find("input[name='evaluation_activity[date_scheduled]']").value)
    periodo = con_el_colegio(@a.colegio) { @a.seccion.academic_period }
    assert_includes (periodo.start_date..periodo.end_date), fecha
  end

  test "al guardar, la evaluación aparece en su competencia y el panel se va" do
    all("a", text: "Agregar evaluación").first.click
    within(".alta-en-linea") do
      fill_in "evaluation_activity[description]", with: "Prueba corta"
      click_on "Agregar"
    end

    assert_no_text "Content missing"
    assert_selector ".plan-competencia .plan-evaluacion-nombre-campo[value='Prueba corta']", wait: 5
    assert_no_selector ".alta-en-linea"
    # Y la barra la cuenta: 40 del examen + 60 de la nueva.
    assert_selector ".plan-ponderacion-cuenta", text: "100 %"
  end

  # ⚠️ Turbo manda en `Turbo-Frame` el frame CONTENEDOR del formulario, no el de
  # destino que dice `data-turbo-frame`. Comparando con `"plan"` a secas, la
  # vuelta se iba a la LIBRETA y dejaba el plan entero en «Content missing».
  test "la vuelta es al plan, no a la libreta" do
    all("a", text: "Agregar evaluación").first.click
    within(".alta-en-linea") do
      fill_in "evaluation_activity[description]", with: "Prueba corta"
      click_on "Agregar"
    end

    assert_selector ".pestana.activa", text: "Planificar"
  end

  test "cancelar cierra el panel y deja el plan como estaba" do
    all("a", text: "Agregar evaluación").first.click
    within(".alta-en-linea") { click_on "Cancelar" }

    assert_no_selector ".alta-en-linea"
    assert_no_text "Content missing"
    assert_selector ".plan-ponderacion"
  end

  # ── Y la competencia ─────────────────────────────────────────────────────
  test "una competencia nueva se agrega ahí mismo" do
    click_on "Agregar competencia"
    within(".alta-en-linea") do
      # ⚠️ Los indicadores NO están en el alta: se escriben uno por uno en la
      # competencia ya creada. Pedirlos acá obligaría a tenerlos pensados antes
      # de escribir la competencia, que es al revés de como se planifica.
      assert_no_selector "textarea[name='competency[indicadores]']"
      fill_in "competency[descripcion]", with: "Interpreta gráficos de barras"
      click_on "Agregar"
    end

    assert_no_text "Content missing"
    assert_selector ".plan-competencia", count: 2, wait: 5
    assert_includes all(".plan-competencia-descripcion-campo").map(&:value),
                    "Interpreta gráficos de barras"
  end

  # ⚠️ Un `<details>` nativo NO se cierra al hacer clic fuera, y como su panel es
  # `position: absolute` quedaba flotando sobre la fila de abajo. Daniel: «clic
  # fuera del elemento destruye la acción».
  test "el menú de competencias se cierra al hacer clic fuera" do
    con_el_colegio(@a.colegio) { competencia_con(0, "Otra competencia", lapso: @lapso) }
    ir_al_plan

    find(".plan-evaluacion-mas-abrir", match: :first).click
    assert_selector ".plan-evaluacion-mas-opcion", visible: true

    find(".plan-rotulo", text: "COMPETENCIAS", match: :first).click

    assert_no_selector ".plan-evaluacion-mas-opcion", visible: true
  end
end
