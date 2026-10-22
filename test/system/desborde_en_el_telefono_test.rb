require "application_system_test_case"

# Ninguna pantalla puede desbordar a lo ancho en un teléfono (MOR-194).
#
# Daniel, abriendo /secciones a 493 px: *«mira cómo se ve desde el teléfono:
# BOOM, EXPLOTÓ TODO»*.
#
# ## Por qué un test de sistema y no uno de vista
#
# Esto NO se puede comprobar leyendo el HTML: el desborde lo produce el
# LAYOUT —un `min-width` implícito, un `nowrap`, un flex que no encoge— y para
# verlo hay que medirlo en un navegador de verdad.
#
# ## Qué cuenta como desborde, y qué no
#
# ⚠️ `documentElement.scrollWidth` NO alcanza, y da falsos positivos.
#
# Una tabla de cinco columnas en un teléfono se corre de lado A PROPÓSITO:
# `.table-academic` es `overflow-x: auto`, y esa barra de scroll es la manera
# correcta de mostrar una tabla ancha. Pero el navegador la suma igual al
# `scrollWidth` del documento, así que la guarda reportaba «se pasa 6px» en las
# ocho pantallas cuando lo que sobraba era exactamente eso.
#
# Lo que sí es un defecto es un elemento que se sale del viewport **sin ningún
# ancestro que scrollee**: ahí no hay manera de llegar a lo que quedó afuera y
# la página entera se arrastra de lado. Eso es lo que se mide.
class DesbordeEnElTelefonoTest < ApplicationSystemTestCase
  # 390 px es un iPhone; 493 es el ancho exacto donde Daniel lo vio.
  #
  # ⚠️ Y 1.024, una laptop chica o una tableta acostada (14 de octubre de 2026).
  # Entre el teléfono —las reglas empiezan a 640— y la pantalla grande, la barra
  # no cedía nada: de 641 a 1.350 px TODAS las pantallas se corrían de lado,
  # hasta 500 px, y este test no lo veía porque solo medía teléfonos.
  #
  # ⚠️ Y 601, el primer ancho donde una tabla deja de deslizarse sola (la regla
  # del teléfono llega a 600). Ahí cinco pantallas se corrían, la peor 245 px;
  # una tabla ancha nueva va dentro de `.tabla-envoltura`.
  ANCHOS = [ 390, 493, 601, 1024 ].freeze

  # ⚠️ La ventana se DEVUELVE al terminar, y no es limpieza de cortesía.
  #
  # Los tests de sistema comparten una sola ventana de Chrome, así que este test
  # dejaba el navegador en 390 px para el que corriera después. Con el orden
  # aleatorio de minitest eso es una bomba de tiempo: falla un test cualquiera,
  # en un punto cualquiera, con un mensaje que no menciona el teléfono.
  #
  # Ya explotó — «element not clickable at point (-35, 134)» en el panel de
  # contexto, que a 390 px se ancla a la derecha y quedaba fuera de una ventana
  # que el test creía de 1400.
  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(*ApplicationSystemTestCase::ESCRITORIO)
  rescue StandardError
    # Si el navegador ya se cerró, no hay nada que devolver — y hacer fallar el
    # teardown escondería el error de verdad que cerró la sesión.
    nil
  end

  # ⚠️ Se emula por CDP, NO con `resize_to`, y la diferencia invalidaba la
  # medición entera.
  #
  # Chrome no deja achicar una VENTANA por debajo de unos 500 px: pedirle 390
  # devuelve 500, y el test mide contra un ancho que nunca pidió. Así reportaba
  # «/alumnos a 390px se pasa 3px» —falso— mientras el teléfono de verdad
  # estaba bien. `Emulation.setDeviceMetricsOverride` fija el viewport de
  # verdad, que es lo que hace el modo dispositivo de las DevTools.
  def desborde_en(ruta, ancho)
    # ⚠️ La VENTANA primero y la emulación después, o las dos no coinciden.
    #
    # Chrome no achica una ventana por debajo de ~500 px, así que con
    # `resize_to(390)` sola el viewport queda en 500 y el test mide contra un
    # ancho que nunca pidió. Pero con la emulación sola, `clientWidth` dice 390
    # mientras `innerWidth` sigue en 480: el layout se calcula contra uno y la
    # barra de scroll contra el otro, y aparecen desbordes fantasma.
    #
    # Achicar la ventana todo lo que Chrome permita y después fijar el viewport
    # por CDP deja los dos números en el mismo lugar.
    page.driver.browser.manage.window.resize_to(ancho, 844)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: ancho, height: 844,
                                    deviceScaleFactor: 0, mobile: true)
    visit ruta

    medido = page.evaluate_script("document.documentElement.clientWidth")
    raise "el viewport quedó en #{medido}px y se pidió #{ancho}px" unless medido == ancho

    # ⚠️ Sin esto el test miente y ya mintió: si la sesión se cayó, TODA visita
    # rebota a `/users/sign_in` —una pantalla simple que nunca desborda— y las
    # dieciocho dan cero. Verde por no haber medido nada.
    raise "rebotó al login en #{ruta}" if page.current_url.include?("sign_in")

    page.evaluate_script(<<~JS)
      (() => {
        const limite = document.documentElement.clientWidth
        const dentroDeUnScroll = e => {
          for (let p = e.parentElement; p; p = p.parentElement) {
            const o = getComputedStyle(p).overflowX
            if (o === "auto" || o === "scroll") return true
          }
          return false
        }
        // ⚠️ Dice QUÉ se sale, no solo cuánto (14 de octubre de 2026): «se pasa
        // 15px» en una sola corrida del CI no alcanzaba para saber si era la
        // barra o una tabla.
        const quien = e => e.tagName.toLowerCase() + (e.className && e.className.baseVal === undefined
          ? "." + String(e.className).trim().split(/\\s+/).slice(0, 2).join(".") : "")
        const fuera = [...document.querySelectorAll("*")]
          .filter(e => e.getBoundingClientRect().right > limite + 1 && !dentroDeUnScroll(e))
          .map(e => [Math.round(e.getBoundingClientRect().right - limite), quien(e)])

        // ⚠️ Y los globos de `data-tooltip`, que no son elementos —el recorrido
        // de arriba no los ve— y ESCONDIDOS igual ocupan lugar: uno centrado
        // en el botón del borde corría la página 6 px, sin que nadie lo viera
        // nunca. Se mide la página con los globos y sin ellos.
        const d = document.documentElement
        const conGlobos = d.scrollWidth
        const apagados = document.createElement("style")
        apagados.textContent = "[data-tooltip]::after, [data-tooltip]::before { display: none !important }"
        document.head.appendChild(apagados)
        const globos = conGlobos - d.scrollWidth
        apagados.remove()
        if (globos > 1) fuera.push([globos, "un globo de data-tooltip"])

        if (!fuera.length) return 0
        const peor = fuera.reduce((a, b) => (b[0] > a[0] ? b : a))
        return `${peor[0]}px (${peor[1]})`
      })()
    JS
  end

  # ⚠️ Se recorren TODAS las pantallas del director, no una muestra: el desborde
  # de MOR-194 estaba en la barra, o sea en las veintitantas a la vez, y una
  # muestra de cuatro lo habría encontrado igual — pero la próxima puede estar
  # en una sola vista, y ésa es justo la que no se elige a mano.
  PANTALLAS = %i[
    dashboards_administrador_path students_path representatives_path teachers_path
    admins_path grades_path sections_path enrollments_path subjects_path
    departments_path academic_periods_path evaluation_moments_path
    asistencias_path evaluation_activities_path report_cards_path
    constancias_path certificados_path importaciones_path dashboards_activity_logs_path
    competencies_path horarios_path
  ].freeze

  test "ninguna pantalla se corre de lado en un teléfono" do
    a, _b = dos_colegios_completos

    # ⚠️ Con DOS niveles y uno elegido, que es la barra más ancha que existe.
    #
    # `dos_colegios_completos` trae un solo nivel, así que el selector de nivel
    # no se dibujaba y este test —que existe justamente para la barra— no lo
    # habría medido nunca. Es la misma clase de agujero que el `sign_in` que no
    # entraba: verde por no haber mirado.
    con_el_colegio(a.colegio) { Grade.create!(school: a.colegio, name: "6to Grado") }

    entrar_como(a.director)
    visit sections_path
    # ⚠️ Con un nivel PUESTO, que es cuando la barra lleva más texto: la
    # pastilla dice «2025-2026 · Primaria» en vez de solo el año. Sin esto, el
    # test mide la barra en su estado más corto y no la que hay que medir.
    tocando { find(".contexto-pastilla").click }
    assert_selector ".contexto-panel", visible: true
    tocando do
      find(".contexto-panel button", text: GradoOficial.etiqueta(:primaria, corto: true),
                                     exact_text: true).click
    end
    esperando_la_pagina
    tocando do
      assert_selector ".contexto-pastilla", text: GradoOficial.etiqueta(:primaria, corto: true)
    end

    culpables = ANCHOS.flat_map do |ancho|
      PANTALLAS.filter_map do |helper|
        ruta = send(helper)
        sobra = desborde_en(ruta, ancho)
        "#{ruta} a #{ancho}px se pasa #{sobra}" if sobra.to_i > 0
      end
    end

    assert_empty culpables, "páginas que desbordan:\n  " + culpables.join("\n  ")
  end
end
