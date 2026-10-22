require "application_system_test_case"

# Armar en el navegador (spec `horarios`, tanda 2): tocar el área y la casilla
# cambia solo el marco «horario» y el mensaje cuenta lo que pasó.
#
# ⚠️ Esto solo lo prueba un navegador: un test de integración ve el HTML
# correcto aunque Turbo no cambie el marco y la pantalla quede en blanco
# («Content missing», la trampa de § «Dentro de un turbo_frame»).
class ArmarElHorarioTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
    visit horarios_path
  end

  test "tocar una casilla libre ubica el bloque de 80 minutos, y la × lo devuelve a «por ubicar»" do
    click_on "Armar"
    assert_selector ".horario-armar", text: "Por ubicar"

    within(".horario-rejilla") { first(".horario-libre").click }
    assert_selector ".horario-mensaje--ok", text: "Listo: Matemática el lunes de 7:10 a 8:30. Van 2 de 4."
    assert_selector ".horario-rejilla .horario-clase", count: 1

    within(".horario-rejilla") { find(".horario-quitar").click }
    assert_selector ".horario-mensaje--ok", text: "Se quitó Matemática del lunes (7:10 – 8:30)."
    assert_selector ".horario-rejilla .horario-clase", count: 0
  end
end
