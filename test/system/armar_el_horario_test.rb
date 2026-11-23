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

  # ⚠️ «Armar» es un `button_to` DENTRO del marco «horario», y Turbo se traga
  # el clic que cae mientras hidrata (`tocar_para_ver`). Reintentarlo no hace
  # daño: el POST llama a `TurnoDelAnio.asegurar!`, que no duplica el turno.
  #
  # ## ⚠️ Y TODO clic dentro del marco va por `tocar_para_ver`
  #
  # El 16 de noviembre de 2026 este archivo fallaba una de cada diez corridas,
  # cada vez en un clic distinto —«Armar», la casilla, la ×, el lápiz de la
  # hora— y siempre igual: el servidor no recibía nada. La caja negra
  # (`SIGA_CAJA_NEGRA=1`) lo dijo del lado del navegador: tras ubicar una
  # clase, Turbo dibujó el marco y avanzó el historial (`turbo:frame-render`,
  # `turbo:visit`, `turbo:load` en 18 ms), el test tocó la × enseguida, y la
  # página no recibió NADA — ni un `pointerdown`. Selenium dio el clic por
  # hecho. Es la familia de «Chrome descarta, no encola» (CLAUDE.md), en otro
  # momento: no al abrir la página, sino al redibujar el marco.
  #
  # Una persona no toca en esos milisegundos; un test sí, y por eso el clic se
  # reintenta hasta ver su efecto. Sin riesgo de un envío doble: `tocar_hasta`
  # no vuelve a tocar mientras haya una petición en vuelo.
  #
  # El `text:` no es adorno: «Áreas y profesores de 1er Año A» lleva la misma
  # clase y ya está en la pantalla antes del clic. Y va en mayúsculas por CSS:
  # el navegador lee lo que se VE.
  def abrir_armar
    tocar_para_ver(".horario-armar-titulo", text: /por ubicar/i) { click_on "Armar" }
  end

  test "tocar una casilla libre ubica el bloque de 80 minutos, y la × lo devuelve a «por ubicar»" do
    abrir_armar

    tocar_para_ver(".horario-mensaje--ok", text: "Listo: Matemática el lunes de 7:10 a 8:30. Van 2 de 4.") do
      within(".horario-rejilla") { first(".horario-libre").click }
    end
    assert_selector ".horario-rejilla .horario-clase", count: 1

    tocar_para_ver(".horario-mensaje--ok", text: "Se quitó Matemática del lunes (7:10 – 8:30).") do
      within(".horario-rejilla") { find(".horario-quitar").click }
    end
    assert_selector ".horario-rejilla .horario-clase", count: 0
  end

  # Daniel, el 26 de octubre de 2026: el lápiz convierte ESA casilla en el
  # formulario, sin un cuadro aparte y sin botones, como el texto de Linear
  # (decisión 30). El foco, las teclas y «salir» son del navegador: un test de
  # integración no ve ninguno.
  test "corregir una hora en su casilla: Escape la deja, Enter guarda, y salir de ella también" do
    abrir_armar

    tocar_para_ver("form.horario-hora--editando") { find(".horario-hora--editable", text: "10:20 – 11:00").click }
    assert_selector "form.horario-hora--editando", count: 1
    assert_selector ".horario-mensaje--info", text: "Corrija la 5ta hora en su casilla"
    # El foco ya está en «desde»: se escribe sin ir a buscar el campo.
    # ⚠️ Con una aserción que ESPERA. El foco lo pone Turbo por el `autofocus`,
    # un cuadro DESPUÉS de dibujar el marco: leído enseguida, falló una vez
    # bajo carga con «Expected: "time_slot[desde]", Actual: nil».
    assert_selector "form.horario-hora--editando input[name='time_slot[desde]']:focus"

    find("form.horario-hora--editando input[name='time_slot[desde]']").send_keys(:escape)
    assert_no_selector "form.horario-hora--editando"
    assert_selector ".horario-hora--editable", text: "10:20 – 11:00"

    tocar_para_ver("form.horario-hora--editando") { find(".horario-hora--editable", text: "10:20 – 11:00").click }
    desde = find("form.horario-hora--editando input[name='time_slot[desde]']")
    desde.set(Time.zone.local(2026, 3, 2, 10, 25))
    desde.send_keys(:enter)
    assert_selector ".horario-mensaje--ok", text: "La 5ta hora ahora va de 10:25 a 11:00."
    assert_no_selector "form.horario-hora--editando"
    assert_selector ".horario-hora--editable", text: "10:25 – 11:00"

    # Pasar de «desde» a «hasta» no guarda: guardaría la mitad.
    tocar_para_ver("form.horario-hora--editando") { find(".horario-hora--editable", text: "10:25 – 11:00").click }
    hasta = find("form.horario-hora--editando input[name='time_slot[hasta]']")
    hasta.set(Time.zone.local(2026, 3, 2, 10, 55))
    hasta.click
    assert_selector "form.horario-hora--editando", count: 1
    assert_selector ".horario-mensaje--info", text: "Corrija la 5ta hora en su casilla"

    # Salir de la casilla sí.
    tocar_para_ver(".horario-mensaje--ok", text: "La 5ta hora ahora va de 10:25 a 10:55.") { find("h1").click }
    assert_no_selector "form.horario-hora--editando"
  end
end
