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
      # ⚠️ DOS indicadores: el «Examen» se lleva uno —desde `MOR-136` toda
      # evaluación de primaria mide alguno— y el otro queda libre para que el
      # alta tenga qué ofrecer.
      c = competencia_con(2, "El niño debe graficar funciones", lapso: @lapso)
      actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Examen", mide: c)
      c
    end
    entrar_como @a.profesor
    ir_al_plan
  end

  def ir_al_plan
    visit planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  # ⚠️ El alta de una evaluación es AHORA LA MISMA FILA de la edición.
  #
  # Daniel, 23 de septiembre: *«¿te parece bien que haya 2 maneras distintas de
  # hacer lo mismo?… parece que fueran desarrollos distintos. Me apunto más
  # porque el crear la evaluación sea como el de editarla»*. Era un panel con
  # sus propios campos —«Qué se evalúa», un textarea de indicadores «uno por
  # línea», la lista tachada de los que ya mide otra— frente a una fila que se
  # edita en su sitio.
  #
  # `.alta-en-linea` se queda para la COMPETENCIA, que sí es un panel: no tiene
  # una fila equivalente a la que parecerse.
  def fila_nueva = find(".plan-evaluacion--naciendo")

  def abrir_el_alta
    tocar_para_ver(".plan-evaluacion--naciendo") { all("a", text: "Agregar evaluación").first.click }
  end

  test "la fila nueva se despliega en el sitio, sin cambiar de página" do
    abrir_el_alta

    assert_selector ".plan-evaluacion--naciendo"
    assert_current_path(/planificar/)
    # ⚠️ El plan sigue ahí: no es otra pantalla, es una fila más en la lista.
    assert_selector ".plan-competencia-descripcion-campo"
    assert_selector ".plan-ponderacion"
  end

  # ⚠️ Y el BOTÓN desaparece mientras está abierta. Daniel: *«al hacer clic en
  # "Agregar evaluación" desaparece el botón»*. Con los dos a la vez, la
  # pantalla ofrece empezar una segunda antes de terminar la primera.
  test "mientras la fila está abierta, el botón no está" do
    assert_selector "a", text: "Agregar evaluación"

    abrir_el_alta

    assert_no_selector "a", text: "Agregar evaluación"
  end

  # ⚠️ Los campos FALTANTES y solo esos: la sección, el área, el lapso y la
  # competencia ya están elegidos. Volver a preguntarlos daría además la
  # oportunidad de crear la evaluación en otra sección sin darse cuenta.
  #
  # ⚠️ Y los INDICADORES no están: la evaluación todavía no existe, así que no
  # hay a qué asociarlos. Se escriben después, en su propia fila.
  test "pregunta título, peso y fecha — los indicadores van después" do
    abrir_el_alta

    within(".plan-evaluacion--naciendo") do
      assert_selector "input[name='evaluation_activity[description]']"
      assert_selector "input[name='evaluation_activity[weight_percentage]']"
      assert_selector "input[name='evaluation_activity[date_scheduled]']", visible: false
      assert_no_selector "textarea"
      assert_no_selector "select[name='evaluation_activity[asignacion]']"
    end
  end

  test "el peso nace con lo que falta para cerrar el lapso" do
    abrir_el_alta

    assert_equal "60", fila_nueva.find("input[name='evaluation_activity[weight_percentage]']").value,
                 "el examen vale 40: quedan 60"
  end

  # ⚠️ Nacía en `Date.current`, y en septiembre de 2026 eso cae FUERA del año
  # 2025-2026 —que terminó el 31 de julio—: el campo la rechazaba y el alta no
  # se podía guardar sin tocar la fecha primero.
  test "la fecha nace dentro del año escolar, aunque hoy quede fuera" do
    abrir_el_alta

    campo = fila_nueva.find("input[name='evaluation_activity[date_scheduled]']", visible: false)
    periodo = con_el_colegio(@a.colegio) { @a.seccion.academic_period }
    assert_includes (periodo.start_date..periodo.end_date), Date.parse(campo.value)
  end

  # ⚠️ Y al guardar aparece con su bloque de indicadores VACÍO y listo: es el
  # orden del trabajo que pidió Daniel —«pon solo el form de la eva y luego
  # agregas sobre el guardado la posibilidad de agregar indicadores»—.
  test "al guardar, la evaluación aparece en su competencia lista para sus indicadores" do
    abrir_el_alta
    fila_nueva.find("input[name='evaluation_activity[description]']").set("Prueba corta")
    tocar_para_cerrar(".plan-evaluacion--naciendo") do
      find(".plan-evaluacion--naciendo button[type=submit]").click
    end

    assert_no_text "Content missing"
    assert_selector ".plan-competencia .plan-evaluacion-nombre-campo[value='Prueba corta']", wait: 5
    # La barra la cuenta: 40 del examen + 60 de la nueva.
    assert_selector ".plan-ponderacion-cuenta", text: "100 %"
    # Y el botón vuelve, porque el frame quedó vacío.
    assert_selector "a", text: "Agregar evaluación"
  end

  # ⚠️ Turbo manda en `Turbo-Frame` el frame CONTENEDOR del formulario, no el de
  # destino que dice `data-turbo-frame`. Comparando con `"plan"` a secas, la
  # vuelta se iba a la LIBRETA y dejaba el plan entero en «Content missing».
  test "la vuelta es al plan, no a la libreta" do
    abrir_el_alta
    fila_nueva.find("input[name='evaluation_activity[description]']").set("Prueba corta")
    tocar_para_cerrar(".plan-evaluacion--naciendo") do
      find(".plan-evaluacion--naciendo button[type=submit]").click
    end

    assert_selector ".pestana.activa", text: "Plan de Evaluación"
  end

  # ⚠️ La ✗ va donde va el basurero de las otras filas: es lo que dice que esta
  # fila es de la misma familia, y que todavía no está creada.
  test "descartar cierra la fila y deja el plan como estaba" do
    abrir_el_alta
    tocar_para_cerrar(".plan-evaluacion--naciendo") do
      find(".plan-evaluacion--naciendo a[aria-label='Descartar']").click
    end

    assert_no_selector ".plan-evaluacion--naciendo"
    assert_no_text "Content missing"
    assert_selector ".plan-ponderacion"
    assert_selector "a", text: "Agregar evaluación"
  end

  # ── Y la competencia ─────────────────────────────────────────────────────
  test "una competencia nueva se agrega ahí mismo" do
    tocar_para_ver(".alta-en-linea") { click_on "Agregar competencia" }
    within(".alta-en-linea") do
      # ⚠️ Los indicadores NO están en el alta: se escriben uno por uno en la
      # competencia ya creada. Pedirlos acá obligaría a tenerlos pensados antes
      # de escribir la competencia, que es al revés de como se planifica.
      assert_no_selector "textarea[name='competency[indicadores]']"
      fill_in "competency[descripcion]", with: "Interpreta gráficos de barras"
    end
    # ⚠️ El envío también se reintenta: es el mismo clic dentro de un frame.
    #
    # ⚠️ Y SIN `within`: ése resuelve el panel a un nodo, Turbo lo reemplaza al
    # guardar, y el reintento se encuentra con «Obsolete Element» — buscando el
    # botón dentro de un elemento que ya no existe. El selector se resuelve
    # entero en cada intento.
    tocar_para_cerrar(".alta-en-linea") { find(".alta-en-linea input[type=submit]").click }

    assert_no_text "Content missing"
    assert_selector ".plan-competencia", count: 2, wait: 5
    assert_includes all(".plan-competencia-descripcion-campo").map(&:value),
                    "Interpreta gráficos de barras"
  end

  # ⚠️ El test del MENÚ FLOTANTE se retiró con los chips (21 de septiembre).
  #
  # Probaba que un `<details>` se cierre al hacer clic fuera —Daniel: «clic
  # fuera del elemento destruye la acción»— y su único uso era el menú [+] de la
  # fila, que ofrecía engancharle a una evaluación cualquier competencia del
  # plan. Se retiró porque contradice la jerarquía anidada.
  #
  # El controlador `menu-flotante` se queda registrado: es genérico —un
  # `<details>` que se cierra al hacer clic fuera— y el día que haga falta otro
  # menú, la lección de las tres veces que este proyecto se tropezó con el
  # `position: absolute` de un `<details>` cerrado ya está aprendida.
end
