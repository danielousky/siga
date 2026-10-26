require "application_system_test_case"

# Armar en el navegador (spec `horarios`, tanda 2): tocar el área y la casilla
# cambia solo el marco «horario» y el mensaje cuenta lo que pasó.
#
# ⚠️ Esto solo lo prueba un navegador: un test de integración ve el HTML
# correcto aunque Turbo no cambie el marco y la pantalla quede en blanco
# («Content missing», la trampa de § «Dentro de un turbo_frame»).
class ArmarElHorarioTest < ApplicationSystemTestCase
  # Un lunes de clases del año de los escenarios: un año terminado no se arma.
  setup do
    travel_to Time.zone.local(2026, 3, 2, 10, 0)
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
    visit horarios_path
  end

  test "tocar una casilla libre ubica el bloque de 80 minutos, y la × lo devuelve a «por ubicar»" do
    click_on "Armar"
    # El título va en mayúsculas por CSS, y el navegador lee lo que se VE.
    assert_selector ".horario-armar-titulo", text: /por ubicar/i

    within(".horario-rejilla") { first(".horario-libre").click }
    assert_selector ".horario-mensaje--ok", text: "Listo: Matemática el lunes de 7:10 a 8:30. Van 2 de 4."
    assert_selector ".horario-rejilla .horario-clase", count: 1

    within(".horario-rejilla") { find(".horario-quitar").click }
    assert_selector ".horario-mensaje--ok", text: "Se quitó Matemática del lunes (7:10 – 8:30)."
    assert_selector ".horario-rejilla .horario-clase", count: 0
  end

  # Daniel, el 26 de octubre de 2026: el lápiz convierte ESA casilla en el
  # formulario, sin un cuadro aparte y sin botones, como el texto de Linear
  # (decisión 30). El foco, las teclas y «salir» son del navegador: un test de
  # integración no ve ninguno.
  test "corregir una hora en su casilla: Escape la deja, Enter guarda, y salir de ella también" do
    click_on "Armar"
    assert_selector ".horario-armar-titulo", text: /por ubicar/i

    find(".horario-hora--editable", text: "10:20 – 11:00").click
    assert_selector "form.horario-hora--editando", count: 1
    assert_selector ".horario-mensaje--info", text: "Corrija la 5ta hora en su casilla"
    # El foco ya está en «desde»: se escribe sin ir a buscar el campo.
    assert_equal "time_slot[desde]", page.evaluate_script("document.activeElement.name")

    find("form.horario-hora--editando input[name='time_slot[desde]']").send_keys(:escape)
    assert_no_selector "form.horario-hora--editando"
    assert_selector ".horario-hora--editable", text: "10:20 – 11:00"

    find(".horario-hora--editable", text: "10:20 – 11:00").click
    desde = find("form.horario-hora--editando input[name='time_slot[desde]']")
    desde.set(Time.zone.local(2026, 3, 2, 10, 25))
    desde.send_keys(:enter)
    assert_selector ".horario-mensaje--ok", text: "La 5ta hora ahora va de 10:25 a 11:00."
    assert_no_selector "form.horario-hora--editando"
    assert_selector ".horario-hora--editable", text: "10:25 – 11:00"

    # Pasar de «desde» a «hasta» no guarda: guardaría la mitad.
    find(".horario-hora--editable", text: "10:25 – 11:00").click
    hasta = find("form.horario-hora--editando input[name='time_slot[hasta]']")
    hasta.set(Time.zone.local(2026, 3, 2, 10, 55))
    hasta.click
    assert_selector "form.horario-hora--editando", count: 1
    assert_selector ".horario-mensaje--info", text: "Corrija la 5ta hora en su casilla"

    # Salir de la casilla sí.
    find("h1").click
    assert_selector ".horario-mensaje--ok", text: "La 5ta hora ahora va de 10:25 a 10:55."
    assert_no_selector "form.horario-hora--editando"
  end
end
