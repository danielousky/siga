require "application_system_test_case"

# El alta de un turno muestra el timbre que saldría —«Así queda»— y lo rehace
# al cambiar un número (spec `horarios`, tanda 1).
#
# ⚠️ Esto solo lo prueba un navegador: la vista previa la pide `auto-envio`
# con el botón «Ver cómo queda», por GET y solo para su marco. Un test de
# integración ve el HTML correcto aunque el controlador de Stimulus no esté
# conectado y nada se mueva.
class TurnoConVistaPreviaTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
    visit new_bell_schedule_path
  end

  test "al cambiar las horas del día, el timbre se rehace sin salir del formulario" do
    fill_in "Nombre", with: "Media · mañana"
    within("#asi-queda") { assert_text "8 horas de clase al día" }

    fill_in "Horas al día", with: "6"
    find_field("Horas al día").send_keys(:tab)

    within("#asi-queda") do
      assert_text "6 horas de clase al día"
      assert_no_text "7ma"
    end
    # Lo escrito sigue en su campo: se rehízo el marco, no la página.
    assert_field "Nombre", with: "Media · mañana"
  end

  test "lo que se registra es lo que mostraba" do
    fill_in "Nombre", with: "Media · mañana"
    fill_in "Horas al día", with: "6"
    find_field("Horas al día").send_keys(:tab)
    within("#asi-queda") { assert_text "6 horas de clase al día" }

    click_on "Crear"

    # ⚠️ Con el procesador ocupado, la ficha tarda más que la espera de siempre:
    # el clic ya salió —la barra de Turbo está corriendo— y lo que falta es la
    # respuesta. Se espera la DIRECCIÓN, sin volver a tocar: un segundo «Crear»
    # registraría el turno dos veces. Falló así una vez en `bin/ci`, con la
    # máquina a carga 11.
    assert_current_path(%r{\A/turnos/\d+\z}, wait: 15)
    assert_selector "table.horas-del-turno tbody tr", count: 7
    assert_text "6 horas al día"
  end
end
