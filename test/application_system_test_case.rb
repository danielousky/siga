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
  #
  # ## ⚠️ «Terminó de cargar» NO es «ya se puede usar», y a Chrome le importa
  #
  # Chrome DESCARTA lo que se teclea y lo que se toca en una página recién
  # abierta, hasta que la pintó y un instante más. No lo encola: lo tira. Tiene
  # sentido para una persona —nadie escribe en lo que no ve— y un test lo hace
  # sin darse cuenta, porque Selenium avisa al cargar, no al pintar.
  #
  # Medido con una caja negra puesta dentro del navegador (6 de octubre de
  # 2026), con el procesador saturado, en dos corridas del mismo test:
  #
  #     LA QUE PASÓ                            LA QUE FALLÓ
  #     10 ms  carga   sin pintar              10 ms  carga   sin pintar
  #     46 ms  foco    PINTADA                 40 ms  foco    SIN PINTAR
  #     56 ms  teclas, clic, envío             … y nada más en cinco segundos:
  #                                            ni una tecla, ni el clic
  #
  # El campo quedaba vacío, el navegador bloqueaba el envío por ser obligatorio,
  # y el test fallaba con «no encontré la fila», que se lee como «el alta no
  # funciona» cuando la página nunca recibió nada. En una máquina libre esos
  # treinta milisegundos no existen; en GitHub, con dos procesos de tests
  # repartiéndose el procesador, tocaba una vez de cada tantas — y nunca en el
  # mismo test.
  #
  # ⚠️ El foco SÍ llega, y eso despista: el driver lo pone por JavaScript, que
  # no es una entrada del usuario. Por eso la captura mostraba el cursor
  # parpadeando en un campo vacío.
  #
  # ## ⚠️ Por qué se PREGUNTA, en vez de esperar al primer pintado
  #
  # Esperar el primer pintado fue el primer arreglo, y no alcanzó: con esa
  # espera puesta, la falla volvió dos veces en ciento sesenta. En la que se
  # capturó, el navegador ya decía haber pintado cuando llegó el foco — y las
  # teclas se perdieron igual. Adivinar cuándo empieza a escuchar es volver a
  # apostar: midiendo, la tecla muda llega unos ocho milisegundos ANTES de la
  # hora que el navegador da para su primer pintado.
  #
  # Así que no se adivina. Se toca una tecla que no escribe nada —Shift— hasta
  # que la página la oye, y recién entonces sigue el test. Es la misma vía por
  # la que después van a entrar las teclas de verdad, así que si ésta llegó,
  # aquéllas llegan.
  #
  # ⚠️ Lo que NO es una página que se pueda usar no se espera: un PDF, un JSON,
  # un documento vacío. Ahí no hay quien oiga, y la espera se iría entera en
  # cada visita.
  LA_PAGINA_OYE = <<~JS.squish.freeze
    (function () {
      if (document.readyState !== "complete") return false;
      if (document.contentType !== "text/html" || !document.body || !document.body.children.length) return true;
      if (window.__sigaOye === undefined) {
        window.__sigaOye = false;
        document.addEventListener("keydown", function oir(evento) {
          if (evento.key !== "Shift") return;
          window.__sigaOye = true;
          document.removeEventListener("keydown", oir, true);
        }, true);
      }
      return window.__sigaOye;
    })()
  JS

  # Más que `default_max_wait_time`, y no es paciencia: lo que se espera es un
  # hecho —la página oyó— y no una suposición. Bajo carga puede tardar varios
  # segundos, y cortar antes es volver a escribir a ciegas.
  ESPERA_DE_LA_PAGINA = 10

  def esperando_la_pagina
    limite = ahora + ESPERA_DE_LA_PAGINA
    errores = 0

    until (oye = la_pagina_oye? { errores += 1 }) || ahora > limite
      sleep 0.01
    end

    # `SIGA_DIAG=1` es para cuando haya que volver a buscar una intermitencia:
    # dice si alguna página no oyó, que es el dato que no deja ningún registro.
    warn "[esperando_la_pagina] #{oye ? 'oyó' : 'NO OYÓ'} · errores: #{errores} · #{name}" if ENV["SIGA_DIAG"] && (!oye || errores.positive?)
    # Si ni así oye, que siga: la aserción del test dirá qué pasó con un mensaje
    # mucho más útil que un timeout del helper.
    nil
  end

  # ⚠️ Un error al preguntar NO corta la espera: se vuelve a preguntar.
  #
  # Mientras el navegador cambia de documento, cualquier consulta puede
  # reventar —«execution context was destroyed»— y eso no dice que la página
  # nueva ya oiga: dice que todavía no está. Abandonar ahí era seguir el test
  # justo en el instante que esta espera existe para evitar.
  def la_pagina_oye?
    return true if page.evaluate_script(LA_PAGINA_OYE)

    tocar_una_tecla_muda
    false
  rescue Selenium::WebDriver::Error::WebDriverError
    yield if block_given?
    false
  end

  def ahora = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Shift, apretada y soltada: no escribe, no envía y ningún atajo de la app la
  # mira sola. Va por el mismo canal que usa el driver para teclear.
  def tocar_una_tecla_muda
    tecla = { key: "Shift", code: "ShiftLeft", windowsVirtualKeyCode: 16 }
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "rawKeyDown", **tecla)
    page.driver.browser.execute_cdp("Input.dispatchKeyEvent", type: "keyUp", **tecla)
  end

  # Abrir una página y esperar a que se pueda USAR.
  #
  # ⚠️ Va en `visit` y no en cada test porque el descuido es invisible:
  # `visit` + `fill_in` se lee correcto, pasa en una máquina libre y falla una
  # de cada tantas en GitHub. Con Turbo casi todo lo demás ocurre DENTRO del
  # mismo documento, que ya oye; la página nueva de verdad es la del `visit`.
  def visit(*)
    super
    esperando_la_pagina
  end

  # Escribir en un campo, y comprobar que lo escrito QUEDÓ.
  #
  # ⚠️ La otra mitad de lo mismo, y no sobra. `visit` espera a que la página
  # oiga; esto mira el resultado, que es lo único que no admite discusión: si
  # se pidió escribir algo y el campo quedó vacío, no se escribió nada. Es la
  # huella exacta de la falla —el campo vacío con el cursor adentro— y la deja
  # sin efecto venga de donde venga, también de una página nueva a la que se
  # llegó sin `visit`.
  #
  # ⚠️ Solo mira que no esté VACÍO, no que diga lo mismo. Hay campos que
  # transforman lo que reciben —el teléfono le pone su guion, los nombres
  # pasan a mayúscula, la cédula descarta las letras— y compararlos letra por
  # letra sería reintentar lo que salió bien.
  #
  # ⚠️ Y no puede tapar un defecto de SIGA: si es la app la que vacía el
  # campo, queda vacío las tres veces y el test falla igual que antes.
  def fill_in(locator = nil, with:, **opciones)
    campo = super
    return campo if with.to_s.empty?

    3.times do |intento|
      break unless campo.value.to_s.empty?

      warn "[fill_in] el campo quedó vacío, se reescribe (#{intento + 1}) · #{name}" if ENV["SIGA_DIAG"]
      sleep 0.05
      campo = super
    end

    campo
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    # Escribir disparó algo que reemplazó el campo: ya no hay a quién preguntarle.
    campo
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

  # Tocar algo que TIENE que abrir un panel en su sitio, y asegurarse de que abrió.
  #
  # ## ⚠️ El hermano de `tocar_para_ir_a`, para lo que NO navega
  #
  # Turbo se traga el clic igual —la misma rendija de la hidratación— pero acá
  # no hay URL que mirar: el `turbo_frame` se llena donde está y la barra de
  # direcciones no cambia. `tocar_para_ir_a` no sirve, y con un `click` crudo el
  # test falla con «Unable to find css .alta-en-linea», que se lee como «el
  # panel no existe» cuando lo que pasó es que **nunca se pidió**.
  #
  # Costó encontrarlo porque el HTML era correcto: pidiendo el frame a mano, el
  # formulario llegaba entero. Lo que fallaba era el clic, y solo bajo carga.
  def tocar_para_ver(selector, intentos: 3, &clic)
    intentos.times do
      tocando(&clic)
      esperando_la_pagina
      return if page.has_css?(selector, wait: 3)
    end

    # Que falle con el mensaje de Capybara, que dice qué había en la página.
    assert_selector selector
  end

  # Tocar algo que TIENE que cerrar un panel, y asegurarse de que cerró.
  #
  # ⚠️ El tercer hermano, y por la misma rendija: «Cancelar» dentro de un frame
  # es un enlace que Turbo intercepta, así que el clic que cae mientras hidrata
  # tampoco lo atiende nadie. El panel sigue abierto y el test falla con
  # «expected not to find .alta-en-linea», que se lee como «el cancelar no
  # funciona» cuando nunca se pulsó.
  def tocar_para_cerrar(selector, intentos: 3, &clic)
    intentos.times do
      tocando(&clic)
      esperando_la_pagina
      return if page.has_no_css?(selector, wait: 3)
    end

    assert_no_selector selector
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
    # ⚠️ Y el reintento SE DA POR BUENO si la sesión ya está abierta.
    #
    # Esta era la causa de la intermitencia que quedaba, y estuvo a la vista
    # todo el tiempo en el texto del error: «Ya has iniciado sesión».
    #
    #     1 · se envía el formulario y ENTRA
    #     2 · Capybara no alcanza a ver el cambio de ruta en 5 s
    #     3 · el reintento visita /users/sign_in… con sesión abierta
    #     4 · Devise redirige al panel, no hay campo `user_email`
    #     5 · el helper lo declara «no cargó el login» — y sí había cargado
    #
    # O sea que el reintento, que existe para tapar una carrera, creaba otra.
    # Hacía fallar tests que no hablan de login, con un mensaje que tampoco
    # hablaba de lo que pasaba: enseñaba a volver a correr en vez de a mirar.
    3.times do |intento|
      begin
        visit new_user_session_path
        esperando_la_pagina

        # Sin campo de correo y con botón de salir: ya está adentro.
        break if page.has_link?("Cerrar sesión", wait: 1)

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
