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

    assert_text "6to Grado"
    assert_no_text @a.grado.name
    assert_selector ".listado-escala-nivel", text: "de Primaria"
  end

  test "volver a «Todos» devuelve todo" do
    visit grades_path
    elegir_nivel "Primaria"
    assert_no_text @a.grado.name

    elegir_nivel "Todos"
    assert_text @a.grado.name
    assert_text "6to Grado"
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

    assert_selector ".contexto-pastilla", text: @a.periodo.name
    assert_selector ".contexto-pastilla", text: "Primaria"
  end

  private

  def elegir_nivel(nombre)
    find(".contexto-pastilla").click
    within ".contexto-panel" do
      click_button nombre
    end
  end
end
