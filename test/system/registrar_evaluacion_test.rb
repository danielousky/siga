require "application_system_test_case"

# El formulario de registrar evaluación, en un navegador de verdad
# (QA del 7 de septiembre).
#
# ## Qué se prueba acá y no en un test de integración
#
# Que el DESLIZADOR y el número se muevan juntos. Son dos controles sobre el
# mismo valor, sincronizados por Stimulus, y en este proyecto Stimulus ya falló
# dos veces en silencio: el marcado sale perfecto y no pasa nada.
#
# ⚠️ Y que el botón [+] de «nueva competencia» apunte a algún lado. Su `href` lo
# escribe el controlador con la sección y el lapso elegidos, así que en el HTML
# del servidor no existe: un test de integración no puede verlo.
class RegistrarEvaluacionSystemTest < ApplicationSystemTestCase
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @asignacion = "#{@a.seccion.id}:#{@a.escenario.materia.id}"
    @lapso = @a.escenario.lapso(2)   # el 1 ya tiene una actividad de peso 100
    entrar_como(@a.profesor)
  end

  test "arrastrar el deslizador mueve el número" do
    visit new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    rango  = find(".campo-rango-barra")
    numero = find(".campo-rango-valor")

    # Nace en 100: es lo que queda libre en un lapso sin evaluaciones, y SIGA
    # propone lo que falta en vez de pedir una resta que ya tiene hecha.
    assert_equal "100", numero.value
    assert_equal "100", rango.value

    # Las flechas del teclado son la forma fiable de mover un `range` con
    # Selenium: arrastrarlo depende de píxeles.
    rango.send_keys(:arrow_left, :arrow_left, :arrow_left)

    assert_equal "97", numero.value
  end

  # ⚠️ Al revés NO se toca el número: escribir «33,33» se volvería «33» debajo
  # de los dedos. El deslizador se recorta al entero; el campo conserva lo suyo.
  test "escribir un decimal mueve el deslizador y respeta el número" do
    visit new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    numero = find(".campo-rango-valor")
    numero.fill_in with: "33.33"

    assert_equal "33.33", numero.value
    assert_equal "33", find(".campo-rango-barra").value
  end

  test "el botón de nueva competencia lleva la sección y el lapso puestos" do
    visit new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    destino = find("[data-que-evalua-target='nueva']")[:href]

    assert_includes destino, "/competencias/new"
    assert_includes destino, CGI.escape(@asignacion)
    assert_includes destino, "lapso=#{@lapso.id}"
  end

  # Sin sección elegida no hay plan al que agregarle nada: el [+] queda apagado
  # y sin `href`. Un `<a>` no tiene `disabled`.
  test "sin sección elegida, el botón de nueva competencia no navega" do
    visit new_evaluation_activity_path

    boton = find("[data-que-evalua-target='nueva']")

    assert_nil boton[:href]
    assert_equal "true", boton["aria-disabled"]
  end

  # ⚠️ La competencia que trajo el enlace llega MARCADA. Si llegara vacía, el
  # profesor tendría que buscarla en una lista donde ya sabe cuál es — y si se
  # olvida, la evaluación no mide nada.
  test "la competencia del enlace llega marcada en la lista" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(1, lapso: @lapso) }

    visit new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id,
                                       competencia: competencia.id)

    assert_selector ".que-evalua-item", text: competencia.descripcion
    assert find(".que-evalua-competencia input[type=checkbox]").checked?,
           "la competencia que trajo el enlace tiene que llegar marcada"
  end

  # ── El formulario completo NO reparte indicadores (23 de septiembre) ──────
  #
  # Daniel, viendo el alta al lado de la edición: *«¿te parece bien que haya 2
  # maneras distintas de hacer lo mismo? Cuando agregas una evaluación nueva,
  # vas agregando los indicadores en un bloque de textarea separados por Enter,
  # mientras que cuando estás editándolos, los agregas uno a uno con su propio
  # input por línea… parece que fueran desarrollos distintos»*.
  #
  # Quedó UNA sola manera —la del plan, un campo por indicador sobre la
  # evaluación ya guardada— y este formulario volvió a hacer lo suyo: decir QUÉ
  # COMPETENCIA mide. Los dos tests que probaban el reparto acá se retiraron
  # con la función; este cuida que no vuelva por la ventana.
  #
  # ⚠️ En un navegador de verdad porque la lista la dibuja Stimulus: el plan
  # viaja embebido en el formulario y `que-evalua` lo pinta al elegir la sección
  # y el lapso. Un test de integración ve el JSON y pasaría igual con el
  # controlador sin conectar — que en este proyecto ya pasó dos veces, en
  # silencio.
  test "la lista ofrece competencias y ningún indicador que repartir" do
    competencia = con_el_colegio(@a.colegio) { competencia_con(2, lapso: @lapso) }

    visit new_evaluation_activity_path(asignacion: @asignacion, lapso: @lapso.id)

    find(".que-evalua-competencia input[type=checkbox]").check

    assert_selector ".que-evalua-competencia input[type=checkbox]:checked"
    assert_no_selector ".que-evalua-indicador"
    assert_no_selector "textarea[name='evaluation_activity[indicadores_nuevos][#{competencia.id}]']"
  end
end
