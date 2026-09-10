require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # ⚠️ `headless_chrome` y no `chrome`: en CI no hay pantalla, y abrir una
  # ventana real en cada corrida local es ruido.
  ESCRITORIO = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: ESCRITORIO

  # ⚠️ El tamaño se REPONE antes de cada test, y no es limpieza de cortesía.
  #
  # Los tests de sistema comparten UNA ventana de Chrome, así que el que emula
  # un teléfono se la deja emulada al que corra después. Con el orden aleatorio
  # de minitest eso es una bomba: falla un test cualquiera, en un punto
  # cualquiera, con un mensaje que no menciona el teléfono — «element click
  # intercepted at point (-35, 134)», que fue exactamente lo que apareció.
  #
  # Va en el SETUP y no solo en el teardown del test culpable: un teardown se
  # salta si el test revienta antes, y entonces la contaminación sobrevive.
  # Reponerlo acá lo arregla para todos y para siempre.
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.manage.window.resize_to(*ESCRITORIO)
  rescue StandardError
    # Un navegador que todavía no arrancó no tiene ventana que reponer.
    nil
  end

  # Tocar algo que NAVEGA, sin que la carrera del driver rompa el test.
  #
  # ## El problema, que no es del código de SIGA
  #
  # Cuando un clic dispara una navegación, Chrome destruye los nodos de la
  # página vieja. Si Capybara todavía tiene una referencia a uno —porque está
  # reintentando una espera, o porque el clic mismo llegó tarde— el driver
  # revienta con un mensaje que no menciona nada de esto:
  #
  #     Node with given id does not belong to the document
  #     element click intercepted at point (-35, 134)
  #
  # Capybara reintenta solo el `StaleElementReferenceError` estándar; estos
  # llegan como `UnknownError` de CDP y se le escapan. Aparecían una vez de cada
  # diez corridas, siempre en un test distinto — la peor clase de test roto,
  # porque enseña a volver a correr en vez de a mirar.
  #
  # ⚠️ El reintento NO esconde un bug de la app: se reintenta la misma acción
  # contra la misma página, y si la acción de verdad no se puede hacer, falla
  # las dos veces. Lo que absorbe es el instante en que el navegador está
  # cambiando de documento.
  ERRORES_DE_NAVEGACION = [
    Selenium::WebDriver::Error::UnknownError,
    Selenium::WebDriver::Error::ElementClickInterceptedError,
    Selenium::WebDriver::Error::StaleElementReferenceError
  ].freeze

  def tocando(intentos: 3)
    yield
  rescue *ERRORES_DE_NAVEGACION => e
    raise if (intentos -= 1).zero?

    # Un respiro corto: lo que se espera es que el documento nuevo termine de
    # instalarse, no que algo lento suceda.
    sleep 0.2
    retry
  end

  # Esperar a que el navegador TERMINE de instalar el documento nuevo.
  #
  # ⚠️ No consulta ni un solo nodo, y por eso funciona donde las aserciones de
  # Capybara fallaban: `document.readyState` es una propiedad del documento, no
  # un elemento que Chrome pueda tirar a mitad de la consulta.
  #
  # Es la mitad que faltaba de `tocando`. Ése absorbe el error cuando el clic
  # llega en mal momento; éste evita que la línea SIGUIENTE llegue en mal
  # momento — que era donde el error se movió después de arreglar el clic.
  def esperando_la_pagina
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.02 until page.evaluate_script("document.readyState") == "complete"
    end
  rescue Timeout::Error, Selenium::WebDriver::Error::UnknownError
    # Si ni eso se puede preguntar, que siga: la aserción del test dirá qué pasó
    # con un mensaje mucho más útil que un timeout del helper.
    nil
  end

  # Entrar por el formulario, como una persona. Un test de sistema que se saltea
  # el login no prueba la pantalla que de verdad se ve al llegar.
  #
  # ⚠️ El submit se busca por su CLASE, no por su texto. «Iniciar sesión» es
  # también el `h1` de la página, así que `click_on` con ese texto es ambiguo:
  # Capybara elige uno de los dos y, cuando elige el título, no pasa nada — la
  # sesión no se abre y las visitas siguientes rebotan al login **sin error**.
  #
  # Y esperar el resultado no es opcional: `visit` no espera a que el submit
  # termine, así que sin esto la primera medición sale sobre la página vieja.
  def entrar_como(usuario, clave = "123123")
    # ⚠️ REINTENTA el envío, y no es paranoia: fallaba una de cada cinco
    # corridas con «expected "/users/sign_in" not to equal "/users/sign_in"».
    #
    # El clic puede llegar mientras el navegador todavía está asentando la
    # página —Capybara lo da por hecho y sigue— y entonces el formulario nunca
    # se envía. No es un bug de la app: la app no llegó a recibir nada.
    #
    # Y un login flaky es el peor de todos: hace fallar CUALQUIER test, en un
    # punto cualquiera, con un mensaje que no menciona el login. Enseña a
    # volver a correr en vez de a mirar.
    3.times do |intento|
      visit new_user_session_path
      fill_in "user_email", with: usuario.email
      fill_in "user_password", with: clave
      tocando { find(".acceso-enviar").click }

      break if page.has_no_current_path?(new_user_session_path, wait: 5)
      raise "no se pudo entrar como #{usuario.email}" if intento == 2
    end

    assert_no_current_path new_user_session_path, wait: 5
  end
end
