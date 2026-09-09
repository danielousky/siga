require "application_system_test_case"

# El plan de evaluación, en un navegador de verdad (MOR-136).
#
# ## Qué se prueba acá y no en un test de integración
#
# Que el campo de indicadores CREZCA. Es un controlador de Stimulus, y en este
# proyecto Stimulus ya falló dos veces **en silencio** —un target fuera del
# elemento del controlador, y un `pin` que faltaba en el importmap—: el marcado
# sale perfecto, el `data-controller` está puesto, y no pasa nada.
#
# ⚠️ Y acá se registran A MANO en `controllers/index.js`. Olvidar esa línea deja
# el campo con alto fijo y a la maestra sin ver lo que escribió.
class PlanDeEvaluacionSystemTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos(nivel: :primaria)
    entrar_como(@a.profesor)
  end

  test "el campo de indicadores crece con lo que se escribe" do
    visit new_competency_path(asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                              lapso: @a.escenario.lapso(1).id)

    campo = find("textarea[name='competency[indicadores]']")
    alto_inicial = campo.evaluate_script("this.offsetHeight")

    campo.fill_in with: (1..6).map { |i| "Indicador número #{i}" }.join("\n")

    assert_operator campo.evaluate_script("this.offsetHeight"), :>, alto_inicial,
                    "el campo no creció: el controlador de Stimulus no conectó"
  end

  # ⚠️ Y al EDITAR llega con las líneas ya puestas desde el servidor. Sin
  # ajustar al conectar, el campo aparece recortado y la maestra cree que perdió
  # indicadores.
  test "al editar, el campo abre mostrando todos los indicadores" do
    competencia = con_el_colegio(@a.colegio) do
      c = Competency.create!(section: @a.seccion, subject: @a.escenario.materia,
                             evaluation_moment: @a.escenario.lapso(1),
                             descripcion: "Resuelve problemas de adición")
      5.times { |i| c.indicators.create!(descripcion: "Indicador número #{i + 1}", orden: i) }
      c
    end

    visit edit_competency_path(competencia, asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                                            lapso: @a.escenario.lapso(1).id)

    campo = find("textarea[name='competency[indicadores]']")
    # Cinco líneas no caben en el alto por defecto de tres.
    assert_operator campo.evaluate_script("this.offsetHeight"), :>=,
                    campo.evaluate_script("this.scrollHeight"),
                    "el campo abrió recortado: se ven menos indicadores de los que hay"
  end

  # Lo que el issue promete, de punta a punta y con el navegador.
  test "escribe una competencia con sus indicadores y la ve en el plan" do
    visit new_competency_path(asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                              lapso: @a.escenario.lapso(1).id)

    fill_in "competency[descripcion]", with: "Resuelve problemas de proporcionalidad directa"
    fill_in "competency[indicadores]", with: "Calcula porcentajes\nInterpreta una tabla"
    click_on "Crear"

    # ⚠️ Con margen: crear redirige al plan DENTRO del frame, y desde que la
    # fila se edita en su sitio esa pantalla monta tres formularios y un
    # calendario por evaluación. Se puso intermitente al pasar de 2 s.
    assert_text "Resuelve problemas de proporcionalidad directa", wait: 6
    assert_text "Calcula porcentajes"
    assert_text "Interpreta una tabla"
  end

  # ── Conectar evaluaciones desde el plan (MOR-136, el enganche) ─────────────
  #
  # ⚠️ Se prueba en un navegador de verdad porque el panel es un `<details>`, y
  # este proyecto ya se tropezó TRES veces con lo mismo: un `<details>` cerrado
  # **no** esconde a un hijo con `position: absolute`. El marcado sale perfecto,
  # el panel «cerrado» y sus casillas encima de la pantalla.
  test "conecta una evaluación con una competencia desde el plan" do
    # ⚠️ Se reusa la evaluación del escenario y no se crea otra: el lapso ya
    # tiene el 100 % de la ponderación repartido, y una segunda al 100 % la
    # rechaza el modelo — que es justo lo que tiene que hacer.
    evaluacion  = @a.actividad
    competencia = con_el_colegio(@a.colegio) do
      Competency.create!(section: @a.seccion, subject: @a.escenario.materia,
                         evaluation_moment: @a.escenario.lapso(1),
                         descripcion: "Resuelve problemas de adición")
    end

    visit competencies_path(asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                            lapso: @a.escenario.lapso(1).id)

    assert_selector ".plan-competencia--sin-evaluar"

    # El panel viene cerrado: la casilla no se puede tocar hasta abrirlo.
    assert_no_selector "#conectar-#{competencia.id}-#{evaluacion.id}", visible: true

    find(".plan-conectar-abrir").click
    check "conectar-#{competencia.id}-#{evaluacion.id}"
    click_on "Guardar"

    assert_text "Listo: 1 evaluación mide esta competencia."
    # Enganchada, la evaluación pasa a colgar DENTRO de la competencia y el
    # aviso de la boleta desaparece: es el mismo hecho contado en un solo sitio.
    assert_selector ".plan-competencia .plan-evaluacion-nombre-campo[value='#{evaluacion.description}']"
    assert_no_selector ".plan-competencia--sin-evaluar"
  end
end
