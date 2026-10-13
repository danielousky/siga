require "application_system_test_case"

# El colegio de muestra, en un navegador (spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
#     LAS PUERTAS ──► un clic ──► el panel de ese rol, con la franja arriba
#                                        │
#                                        ▼  «Cambiar de rol»
#                                 LAS PUERTAS otra vez
#
# ⚠️ Va como test de SISTEMA porque los dos botones pasan por Turbo: cada uno
# es un formulario que termina en dos redirecciones seguidas, y eso un test de
# integración lo sigue a mano —y lo ve bien aunque el navegador se quede en
# blanco—.
class ColegioDeMuestraEnElNavegadorTest < ApplicationSystemTestCase
  include ColegioDeMuestra

  TELEFONOS = [ 390, 360 ].freeze

  setup do
    @a, @b = dos_colegios_completos
    montar_la_muestra(@a, @b)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  rescue StandardError
    nil
  end

  test "un clic entra como director, y «cambiar de rol» devuelve a las puertas" do
    en_la_muestra do
      visit root_path
      assert_selector ".muestra-puerta", count: Muestra::CUENTAS.size
      capturar "1-las-puertas"

      tocar_y_llegar("Entrar como director", dashboards_administrador_path)

      assert_selector ".aviso-muestra", text: "Colegio de muestra"
      capturar "2-el-panel-del-director"

      tocar_y_llegar("Cambiar de rol", root_path)

      assert_selector ".muestra-puerta", count: Muestra::CUENTAS.size

      tocar_y_llegar("Entrar como profesor", dashboards_profesor_path)

      assert_selector ".aviso-muestra"
      capturar "3-el-panel-del-profesor"
    end
  end

  # La muestra se abre desde un enlace de WhatsApp: se mira primero en el teléfono.
  test "las puertas no se corren de lado en un teléfono" do
    en_la_muestra do
      culpables = TELEFONOS.filter_map do |ancho|
        sobra = desborde_de_las_puertas(ancho)
        capturar "4-las-puertas-a-#{ancho}"
        "las puertas a #{ancho}px se pasan #{sobra}px" if sobra.to_i.positive?
      end

      assert_empty culpables
    end
  end

  private

  # Toca un botón que TIENE que llevar a otra pantalla, y espera a llegar.
  #
  # ⚠️ Cada botón de este recorrido es un formulario que termina en DOS
  # redirecciones —entrar, la raíz, el panel—, así que con la máquina cargada
  # llegar tarda más que un enlace. El 12 de octubre de 2026 falló dos veces
  # seguidas, de dos maneras: con un clic a secas, «expected "/" to equal
  # "/dashboards/administrador"»; con `tocar_para_ir_a`, «Unable to find button
  # "Entrar como director"» — el primer clic SÍ había funcionado, y el
  # reintento buscaba el botón en una pantalla que ya se estaba yendo.
  #
  # Así que: si el botón sigue ahí, el clic no se atendió y se vuelve a tocar;
  # si ya no está, la pantalla se fue y solo falta esperar a que llegue.
  def tocar_y_llegar(boton, destino)
    3.times do
      tocando { click_button boton }
      return if page.has_current_path?(destino, wait: 5)
      break unless page.has_button?(boton, wait: 0)
    end

    assert_current_path destino, wait: 15
  end

  def capturar(nombre)
    carpeta = ENV["CAPTURAS"].presence or return

    page.save_screenshot(File.join(carpeta, "#{nombre}.png"))
  end

  # Cuánto se pasa del ancho de la pantalla lo más ancho de la página. La misma
  # medición de `desborde_en_el_telefono_test`: la ventana primero y el viewport
  # por CDP después, o los dos números no coinciden.
  def desborde_de_las_puertas(ancho)
    page.driver.browser.manage.window.resize_to(ancho, 844)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: ancho, height: 844, deviceScaleFactor: 0, mobile: true)
    visit root_path
    assert_selector ".muestra-puerta", count: Muestra::CUENTAS.size

    medido = page.evaluate_script("document.documentElement.clientWidth")
    raise "el viewport quedó en #{medido}px y se pidió #{ancho}px" unless medido == ancho

    page.evaluate_script(<<~JS)
      (() => {
        const limite = document.documentElement.clientWidth
        const recortado = e => {
          for (let p = e.parentElement; p; p = p.parentElement) {
            const o = getComputedStyle(p).overflowX
            if (o === "auto" || o === "scroll" || o === "hidden") return true
          }
          return false
        }
        const fuera = [...document.querySelectorAll("*")]
          .filter(e => e.getBoundingClientRect().right > limite + 1 && !recortado(e))
          .map(e => Math.round(e.getBoundingClientRect().right - limite))
        return fuera.length ? Math.max(...fuera) : 0
      })()
    JS
  end
end
