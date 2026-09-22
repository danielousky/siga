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

  # ⚠️ El campo que crece es el del INDICADOR, dentro de su evaluación.
  #
  # Era el textarea de «uno por línea» del formulario de la competencia, y ese
  # campo se retiró el 21 de septiembre: un indicador cuelga de la evaluación
  # que lo mide. Lo que se prueba es lo mismo y donde ahora vive — que el
  # controlador de Stimulus conecte, porque en este proyecto ya falló dos veces
  # EN SILENCIO y el síntoma es un campo de alto fijo que esconde lo escrito.
  test "el campo del indicador crece con lo que se escribe" do
    lapso = @a.escenario.lapso(2)
    con_el_colegio(@a.colegio) do
      c = competencia_con(0, "Resuelve problemas de adición", lapso: lapso)
      actividad(@a.escenario, lapso: lapso, peso: 40, descripcion: "Examen", mide: c)
    end

    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: lapso.id)

    campo = first(".plan-indicador-texto")
    alto_inicial = campo.evaluate_script("this.offsetHeight")

    campo.set((1..6).map { |i| "una frase larga número #{i}" }.join(" "))

    assert_operator campo.evaluate_script("this.offsetHeight"), :>, alto_inicial,
                    "el campo no creció: el controlador de Stimulus no conectó"
  end

  # Lo que el issue promete, de punta a punta y con el navegador.
  test "escribe una competencia y la ve en el plan" do
    visit new_competency_path(asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}",
                              lapso: @a.escenario.lapso(1).id)

    fill_in "competency[descripcion]", with: "Resuelve problemas de proporcionalidad directa"
    click_on "Crear"

    # ⚠️ Con margen: crear redirige al plan DENTRO del frame, y desde que la
    # fila se edita en su sitio esa pantalla monta tres formularios y un
    # calendario por evaluación. Se puso intermitente al pasar de 2 s.
    # ⚠️ Por el `value` de sus campos: desde el 9 de septiembre la competencia y
    # sus indicadores se editan en su sitio, así que su texto ya no está en la
    # página — está dentro de un `<input>`.
    assert_selector ".plan-competencia-descripcion-campo", wait: 6
    # ⚠️ Entre TODAS: el plan ya trae la competencia que mide la evaluación del
    # escenario, así que `find` singular es ambiguo desde `MOR-136`.
    assert_includes all(".plan-competencia-descripcion-campo").map(&:value),
                    "Resuelve problemas de proporcionalidad directa"
    # ⚠️ Nace SIN indicadores, y eso es lo correcto: cuelgan de la evaluación
    # que los mide, y esta competencia todavía no tiene ninguna.
    assert_selector ".plan-competencia--sin-evaluar"
  end

  # ── Los chips se retiraron el 21 de septiembre ────────────────────────────
  #
  # Eran el menú [+] de la fila: le ofrecían a una evaluación CUALQUIER
  # competencia del plan. Daniel, viendo el menú abierto bajo una evaluación de
  # «Reconoce figuras geométricas» que le ofrecía «Resuelve problemas de
  # adición»: *«¿por qué me está permitiendo agregar indicadores de otra
  # competencia?»*.
  #
  # Con el plan anidado —componente ▸ evaluación ▸ indicadores— el chip
  # contradecía lo que la pantalla enseña. Su test de navegador se va con él; el
  # `<details>` que sí quedó se prueba en `alta_en_linea_test`.
end
