require "application_system_test_case"

# Elegir el nivel desde el panel de contexto de la barra (MOR-223).
#
# ## Por qué esto necesita un navegador de verdad
#
# El panel es un `<details>`: sus botones existen en el HTML pero **no se pueden
# tocar hasta que se abre**. Un test de integración haría el POST a mano y
# pasaría con el panel roto — que es exactamente lo que ya pasó dos veces en
# este proyecto con Stimulus: el marcado sale perfecto y no pasa nada al tocar.
#
# ⚠️ Y prueba además la decisión que hizo al control ser un `<details>` nativo:
# abre, cierra y envía **sin depender de JavaScript**. El controlador solo
# agrega Escape y el clic afuera.
class NivelEnLaBarraTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    con_el_colegio(@a.colegio) { Grade.create!(school: @a.colegio, name: "6to Grado") }
    entrar_como(@a.director)
  end

  test "elegir un nivel desde el panel recarga la pantalla filtrada" do
    visit grades_path
    assert_text @a.grado.name
    assert_text "6to Grado"

    elegir_nivel "Primaria"

    tocando do
      assert_text "6to Grado"
      assert_no_text @a.grado.name
      assert_selector ".listado-escala-nivel", text: "de #{GradoOficial.etiqueta(:primaria)}"
    end
  end

  test "volver a «Todos» devuelve todo" do
    visit grades_path
    elegir_nivel "Primaria"
    tocando { assert_no_text @a.grado.name }

    elegir_nivel "Todos"
    tocando do
      assert_text @a.grado.name
      assert_text "6to Grado"
    end
  end

  # ⚠️ El panel se cierra con Escape, y el foco vuelve a la pastilla: cerrarlo
  # y quedarse sin foco deja a quien navega con teclado al principio del
  # documento.
  test "el panel se cierra con Escape" do
    visit grades_path
    find(".contexto-pastilla").click
    assert_selector ".contexto-panel", visible: true

    find("body").send_keys :escape

    assert_no_selector ".contexto-panel", visible: true
  end

  # La pastilla dice el estado completo en una frase, sin abrir nada: es lo que
  # reemplazó a los dos selectores con sus etiquetas.
  test "la pastilla dice el año y el nivel de un vistazo" do
    visit grades_path
    elegir_nivel "Primaria"

    tocando do
      assert_selector ".contexto-pastilla", text: @a.periodo.name
      assert_selector ".contexto-pastilla", text: GradoOficial.etiqueta(:primaria, corto: true)
    end
  end

  private

  # ⚠️ Esperar a que el panel esté ABIERTO antes de tocar lo de adentro.
  #
  # Sin esto el test falla de forma intermitente y con un mensaje que no dice
  # nada: «element click intercepted at point (-35, 134)». Los botones del panel
  # existen en el HTML desde el primer momento —es un `<details>`— así que
  # Capybara los encuentra y les hace clic **antes de que el panel se despliegue**,
  # cuando todavía están en una posición que no es la suya.
  #
  # `assert_selector` con `visible: true` es lo que convierte «existe» en «se
  # puede tocar», y es la diferencia entre un test que prueba el panel y uno que
  # prueba el HTML.
  def elegir_nivel(nombre)
    tocando { find(".contexto-pastilla").click }
    assert_selector ".contexto-panel", visible: true

    # ⚠️ SIN `within`, y esa es la corrección que lo estabilizó.
    #
    # `within(".contexto-panel") { click_button … }` deja a Capybara con el
    # scope apuntando al panel, y el clic NAVEGA: al salir del bloque, Capybara
    # va a validar un nodo que el navegador ya tiró. El error sale con un
    # mensaje que no menciona nada de esto —«Node with given id does not belong
    # to the document»— y aparece una vez de cada diez.
    #
    # Un selector completo hace lo mismo sin dejar scope colgando.
    tocando { find(".contexto-panel button", text: nombre, exact_text: true).click }
    esperando_la_pagina

    # ⚠️ Y NO se espera nada acá. Cada test espera lo suyo, que es más fuerte.
    #
    # Se probaron dos esperas en este punto y las dos fallaban de forma
    # intermitente, porque las dos consultan nodos MIENTRAS la página se está
    # yendo: Capybara los encuentra, el navegador los tira, y el reintento
    # revienta con «Node with given id does not belong to the document».
    #
    # Lo que sigue a esta llamada en cada test —`assert_no_text`,
    # `assert_selector ".contexto-pastilla", text: …`— ya espera a la página
    # nueva, y además comprueba algo que importa. Una espera genérica acá era
    # una espera de más que no probaba nada.
  end
end
