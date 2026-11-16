require "application_system_test_case"

# El buscador de la cabecera se puede USAR (16 de noviembre de 2026).
#
#   COMPUTADORA   el título se llevaba el sobrante de la franja: el campo
#                 quedaba en su ancho de fábrica, 122 px útiles, y la pista
#                 de Alumnos —229 px— salía cortada en todas las listas
#   TELÉFONO      el campo tenía base cero y se quedaba junto a «Buscar»:
#                 −32 px útiles, no se podía escribir, y la × bajaba sola
#
# Ninguno de los dos corría la página de lado, y por eso
# `desborde_en_el_telefono_test` no los vio: aquí se mide el CAMPO.
class BuscadorDeLaCabeceraTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
  end

  def medir
    page.evaluate_script(<<~JS)
      (() => {
        const campo = document.querySelector(".cabecera-de-lista .search-input-wrap input")
        const equis = document.querySelector(".cabecera-de-lista .campo-con-boton-final")
        const estilo = getComputedStyle(campo)
        const regla = document.createElement("canvas").getContext("2d")
        regla.font = estilo.font
        return {
          util: campo.clientWidth - parseFloat(estilo.paddingLeft) - parseFloat(estilo.paddingRight),
          pista: regla.measureText(campo.placeholder).width,
          mismoRenglon: Math.abs(campo.getBoundingClientRect().top - equis.getBoundingClientRect().top) < 2
        }
      })()
    JS
  end

  test "en la computadora, la pista se lee entera" do
    visit students_path
    medido = medir

    assert_operator medido["util"], :>=, medido["pista"],
                    "el campo deja #{medido['util'].round} px y la pista mide #{medido['pista'].round}"
  end

  # ⚠️ La ventana primero y la emulación después, como en
  # `desborde_en_el_telefono_test`: Chrome no achica una ventana por debajo de
  # ~500 px, y con la emulación sola el layout y la barra de scroll se
  # calculan contra dos anchos distintos.
  test "en el teléfono, el campo tiene dónde escribir y su × al lado" do
    page.driver.browser.manage.window.resize_to(390, 844)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: 390, height: 844, deviceScaleFactor: 0, mobile: true)
    visit students_path
    assert_equal 390, page.evaluate_script("document.documentElement.clientWidth")
    assert_no_current_path new_user_session_path

    medido = medir
    assert_operator medido["util"], :>=, 150, "el campo deja #{medido['util'].round} px para escribir"
    assert medido["mismoRenglon"], "la × bajó sola a otro renglón"
  end
end
