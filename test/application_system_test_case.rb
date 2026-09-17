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

  # Tocar algo que TIENE que llevar a otra pantalla, y asegurarse de que llevó.
  #
  # ## ⚠️ El clic puede no hacer nada, y eso NO es un error de Selenium
  #
  # `tocando` cubre el clic que revienta —el elemento se movió, otro lo tapó, el
  # nodo quedó viejo— y `esperando_la_pagina` cubre la línea siguiente. Queda un
  # tercer caso que ninguno de los dos ve: **Turbo se traga el clic**.
  #
  # Turbo intercepta los enlaces con un listener que instala al hidratar. Un
  # clic que llega en esa rendija no lo atiende nadie: Selenium reporta éxito
  # —tocó el elemento correcto— el navegador no navega, y el test falla tres
  # líneas después con «expected "/secciones/1090" to equal
  # "/secciones/1090/asistencia"», que parece un problema de rutas.
  #
  # Se comprobó que no era ambigüedad: `all(:link_or_button, "Asistencia")`
  # devuelve UNA coincidencia, y es el `a.pestana` correcto.
  #
  # ⚠️ Por eso lo que se reintenta es el CLIC, no la aserción. Y solo aparece
  # bajo carga —dentro de `bin/ci`, después de los mil quinientos tests de
  # unidad— porque ahí la hidratación tarda más y la rendija se ensancha.
  def tocar_para_ir_a(destino, intentos: 3, &clic)
    intentos.times do
      tocando(&clic)
      esperando_la_pagina
      return if page.has_current_path?(destino, ignore_query: true, wait: 3)
    end

    # Que falle con el mensaje de Capybara, que dice a dónde se llegó.
    assert_current_path destino, ignore_query: true
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
  # ⚠️ El login espera MÁS que el resto, y no es paciencia: es otra cosa.
  #
  # `default_max_wait_time` está calibrado para una interacción —un clic, un
  # campo que aparece— y acá lo que se espera es que el servidor de pruebas
  # ARRANQUE: la primera visita levanta Puma y resuelve los assets. Dentro de
  # `bin/ci`, después de mil seiscientos tests de unidad, eso pasa de un
  # segundo a varios, y los tres intentos se consumían esperando lo mismo.
  ESPERA_DEL_LOGIN = 15

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
    # ⚠️ Y el reintento cubre TAMBIÉN que el campo no esté.
    #
    # Fallaba con «Unable to find field "user_email"», que no es lo mismo que
    # «el clic no llegó»: es que la página del login todavía no estaba ahí
    # cuando se la pidió. Con el `rescue` fuera del bucle, ese caso se comía el
    # reintento entero y hacía fallar un test que no habla de login.
    # ⚠️ Y se ESPERA a que el campo exista, en vez de pedirlo y ver si está.
    #
    # `visit` devuelve en cuanto el navegador acepta la orden, no cuando la
    # página está: `fill_in` llegaba a un documento vacío, fallaba, y los tres
    # intentos se consumían en tres carreras perdidas contra lo mismo. Bajo
    # carga —dentro de `bin/ci`, después de mil quinientos tests— eso pasó de
    # raro a frecuente. `has_field?` espera; `fill_in` no.
    3.times do |intento|
      begin
        visit new_user_session_path
        esperando_la_pagina

        unless page.has_field?("user_email", wait: ESPERA_DEL_LOGIN)
          # ⚠️ El mensaje dice QUÉ había, no solo que no estaba.
          #
          # «No cargó el login» manda a buscar una lentitud, y lo que suele
          # haber es otra cosa: una página de error de Rails, una redirección a
          # otro sitio, o el documento en blanco. Sin el contenido, cada fallo
          # cuesta media hora de reproducir a ciegas.
          raise "no cargó el login para #{usuario.email}.\n" \
                "  URL:   #{page.current_url}\n" \
                "  Texto: #{page.text.to_s[0, 300].inspect}" if intento == 2

          next
        end

        fill_in "user_email", with: usuario.email
        fill_in "user_password", with: clave
        tocando { find(".acceso-enviar").click }

        break if page.has_no_current_path?(new_user_session_path, wait: 5)
      rescue Capybara::ElementNotFound => e
        raise "no cargó el login para #{usuario.email}: #{e.message}" if intento == 2

        next
      end

      raise "no se pudo entrar como #{usuario.email}" if intento == 2
    end

    assert_no_current_path new_user_session_path, wait: 5
  end
end
