require "test_helper"

# El colegio da de alta a alguien y esa persona elige su contraseña (MOR-143).
#
# Es `recoverable` de Devise con otro texto: genera el token, lo digiere, lo
# caduca, lo consume una vez. Lo único que cambia es de dónde sale el disparo
# —la secretaria, no el usuario— y qué dice el mensaje.
class ActivacionDelAccesoTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    con_el_colegio(@a.colegio) do
      @sin_correo = representante("Yolanda", "Guerra", "99887766")
      @con_correo = representante("Carmen", "López", "99887767", email: "carmen@familia.test")
    end
  end

  def representante(nombre, apellido, documento, **extra)
    Representative.create!(
      school: @a.colegio, phone: "0416-3334455",
      user: User.create!(first_name: nombre, last_name: apellido,
                         document: documento, document_type: :cedula_v, **extra)
    )
  end

  # El token viaja en el flash y en la URL del enlace que se muestra en pantalla.
  def generar_codigo_para(representante)
    sign_in @a.director
    post codigo_representative_path(representante)
    follow_redirect!
    session[:codigo_a_la_vista]&.dig("codigo")
  end

  # ── el código es de la PERSONA, no de su rol ──────────────────────────────
  #
  # ⚠️ Nació en la ficha del representante y se quedó ahí, así que profesores y
  # administradores seguían con "que alguien más te elija la contraseña" — el
  # patrón que este trabajo vino a sacar. El importador de pensum lo volvió
  # urgente: carga ocho profesores de un golpe, todos con correo y ninguno con
  # contraseña.

  test "un profesor recibe su código igual que un representante" do
    sign_in @a.director

    assert_emails 1 do
      post codigo_teacher_path(@a.registro_de_profesor)
    end
    follow_redirect!

    assert_not_nil session[:codigo_a_la_vista]
    assert_select "p.codigo-de-acceso-enlace", text: /#{Regexp.escape(session[:codigo_a_la_vista]["codigo"])}/
  end

  test "un administrador recibe su código igual, desde el listado" do
    sign_in @a.director

    post codigo_admin_path(@a.registro_de_admin)
    follow_redirect!

    assert_response :success
    assert_not_nil session[:codigo_a_la_vista]
    assert_select "p.codigo-de-acceso-enlace", text: /#{Regexp.escape(session[:codigo_a_la_vista]["codigo"])}/
  end

  # Y el código sirve para lo mismo: no es un enlace decorativo por rol.
  test "el profesor entra con su código y elige su contraseña" do
    sign_in @a.director
    post codigo_teacher_path(@a.registro_de_profesor)
    codigo = session[:codigo_a_la_vista]&.dig("codigo")
    sign_out @a.director

    get activar_path(codigo)
    assert_response :success

    patch activacion_path, params: { user: { token: codigo, password: "clave-nueva-123",
                                             password_confirmation: "clave-nueva-123" } }

    assert_redirected_to dashboards_profesor_path
    assert @a.profesor.reload.valid_password?("clave-nueva-123")
  end

  # ⚠️ Acá lo que se filtra no es una ficha: es una LLAVE.
  #
  # `User` no es `SchoolScoped` —una persona es de la plataforma— así que un
  # `POST /personas/:id/codigo` central tendría que resolver a mano si esa
  # persona es de este colegio. Colgando de cada rol, el `default_scope` del rol
  # lo hace solo: el profesor del colegio B no existe para el director de A.
  test "no se le puede generar código a alguien de otro colegio" do
    sign_in @a.director

    post codigo_teacher_path(@b.registro_de_profesor)

    assert_response :not_found
    assert_nil session[:codigo_a_la_vista]&.dig("codigo")

    # ⚠️ Lo que de verdad hay que probar es que NO SE ESCRIBIÓ NADA. Un 404 con
    # el token ya generado sería el peor de los dos mundos: la pantalla no lo
    # muestra, pero la llave existe y el correo pudo salir.
    assert_nil Current.sin_aislamiento { @b.profesor.reload.reset_password_token }
  end

  # ── generar el código ─────────────────────────────────────────────────────

  test "el código se ve en pantalla y se manda por correo cuando lo hay" do
    assert_emails 1 do
      codigo = generar_codigo_para(@con_correo)

      assert_not_nil codigo
      assert_select "p.codigo-de-acceso-enlace", text: /#{Regexp.escape(codigo)}/
    end

    correo = ActionMailer::Base.deliveries.last

    assert_equal ["carmen@familia.test"], correo.to
    assert_match(/active su acceso/i, correo.subject)
  end

  # Sin correo la pantalla es el ÚNICO canal: la secretaria lo pega en WhatsApp
  # desde su teléfono. Por eso se muestra siempre, haya correo o no.
  test "sin correo el código se ve igual, y no se manda nada" do
    assert_no_emails do
      codigo = generar_codigo_para(@sin_correo)

      assert_not_nil codigo
      assert_select "p.codigo-de-acceso-enlace", text: /#{Regexp.escape(codigo)}/
    end
  end

  test "el código NO queda guardado en claro" do
    codigo = generar_codigo_para(@sin_correo)

    # En la columna vive el digest. Si alguien lee la base, no tiene la llave.
    assert_not_equal codigo, @sin_correo.user.reload.reset_password_token
  end

  test "quien no gestiona alumnos no puede generar códigos" do
    sign_in @a.estudiante
    post codigo_representative_path(@con_correo)

    assert_redirected_to dashboard_path_for_user_de_prueba
    assert_nil session[:codigo_a_la_vista]&.dig("codigo")
  end

  # ── canjearlo ─────────────────────────────────────────────────────────────

  test "con el código se elige contraseña y se entra" do
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    get activar_path(codigo)

    assert_response :success

    patch activacion_path, params: { user: { token: codigo, password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }

    assert_response :redirect
    assert @con_correo.user.reload.valid_password?("clave-nueva")
    assert @con_correo.user.puede_entrar?
  end

  test "a quien no tiene correo se le pide junto con la contraseña" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director

    get activar_path(codigo)

    assert_response :success
    assert_select "input[name='user[email]']"

    patch activacion_path, params: { user: { token: codigo, email: "yolanda@familia.test",
                                             password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }

    assert_response :redirect
    assert_equal "yolanda@familia.test", @sin_correo.user.reload.email
  end

  # ⚠️ Aceptarlos por separado deja a alguien con contraseña puesta y sin correo:
  # o sea, sin ninguna forma de recuperarla nunca.
  test "no se puede activar sin correo si no lo tenía" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director

    patch activacion_path, params: { user: { token: codigo, email: "",
                                             password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }

    assert_response :unprocessable_entity
    assert_not @sin_correo.user.reload.puede_entrar?
    assert_select "input[name='user[email]']", 1,
                  "el campo de correo tiene que seguir ahí para poder corregirlo"
  end

  test "un correo ya registrado da una frase que dice qué hacer, no un 500" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director

    patch activacion_path, params: { user: { token: codigo, email: "carmen@familia.test",
                                             password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }

    assert_response :unprocessable_entity
    assert_select "ul.lista-errores", text: /ya está registrado en SIGA/
    assert_select "input[name='user[email]']", 1
  end

  test "la contraseña corta se sigue rechazando" do
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    patch activacion_path, params: { user: { token: codigo, password: "123",
                                             password_confirmation: "123" } }

    assert_response :unprocessable_entity
    assert_not @con_correo.user.reload.puede_entrar?
  end

  # ── un solo uso, y caduca ─────────────────────────────────────────────────

  test "el código sirve una sola vez" do
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    patch activacion_path, params: { user: { token: codigo, password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }
    assert_response :redirect

    get activar_path(codigo)

    assert_response :gone
  end

  test "regenerar invalida el anterior" do
    viejo = generar_codigo_para(@con_correo)
    nuevo = generar_codigo_para(@con_correo)

    assert_not_equal viejo, nuevo
    sign_out @a.director

    get activar_path(viejo)
    assert_response :gone

    get activar_path(nuevo)
    assert_response :success
  end

  # La secretaria carga la matrícula un jueves y la mamá abre el mensaje el
  # domingo. Con las 6 horas de Devise, el enlace ya no serviría nunca.
  test "el código de activación vive 72 horas, no 6" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director

    @sin_correo.user.update_column(:reset_password_sent_at, 48.hours.ago)
    get activar_path(codigo)
    assert_response :success, "a las 48 horas todavía tiene que servir"

    @sin_correo.user.update_column(:reset_password_sent_at, 73.hours.ago)
    get activar_path(codigo)
    assert_response :gone, "a las 73 ya no"
  end

  # Las 72 horas son para ACTIVAR. Quien ya tiene contraseña y pide recuperarla
  # está sentado frente a la pantalla esperando el correo: ahí valen las 6 de
  # Devise, y la diferencia se deduce del estado sin guardar ninguna bandera.
  test "una vez activo, el plazo vuelve a ser el de Devise" do
    usuario = @con_correo.user
    usuario.update!(password: "clave-vieja")

    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    usuario.update_column(:reset_password_sent_at, 7.hours.ago)
    get activar_path(codigo)

    assert_response :gone
  end

  # ⚠️ El MISMO token abre el formulario estándar de Devise, que NO pregunta por
  # el correo. Sin el invariante del modelo, por ahí quedaba una persona con
  # contraseña y sin correo: sin ninguna forma de recuperarla nunca, que es el
  # estado exacto que este issue dice que no puede existir.
  #
  # Se cierra en `User` y no en un controller porque la puerta de Devise no es
  # la única: están la consola y el importador que todavía no existe.
  test "el formulario estándar de Devise no sirve para saltarse el correo" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director

    put user_password_path, params: { user: { reset_password_token: codigo,
                                              password: "clave-nueva",
                                              password_confirmation: "clave-nueva" } }

    usuario = @sin_correo.user.reload

    assert_not usuario.puede_entrar?, "quedó con contraseña"
    assert_nil usuario.email
  end

  # ── una sola puerta, y dice de quién es la cuenta ─────────────────────────

  # La pantalla de Devise construye un usuario EN BLANCO a partir del token y
  # nunca carga la persona, así que no puede decir de quién es la cuenta. Le
  # pasó a Daniel: "no sé de cuál usuario estoy reseteando la contraseña".
  test "la pantalla dice de quién es la cuenta" do
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    get activar_path(codigo)

    assert_response :success
    assert_select ".acceso-quien", text: /Carmen López/
    assert_select ".acceso-quien-correo", text: "carmen@familia.test"
  end

  # Activar y recuperar son la misma pantalla, pero no dicen lo mismo: a quien
  # nunca tuvo cuenta se le da la bienvenida; a quien la está recuperando, no.
  test "el texto distingue activar de recuperar" do
    codigo = generar_codigo_para(@sin_correo)
    sign_out @a.director
    get activar_path(codigo)

    assert_select "h1", text: /Bienvenido/

    sign_in @a.director
    @con_correo.user.update!(password: "clave-vieja")
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director
    get activar_path(codigo)

    assert_select "h1", text: /contraseña nueva/
  end

  # ⚠️ 302 y no 301: la URL lleva un token de un solo uso, y un navegador que
  # cachee una redirección permanente se queda con el token viejo.
  test "la pantalla vieja de Devise redirige a la nueva, sin cachear" do
    get "/users/password/edit", params: { reset_password_token: "un-token" }

    assert_response :found
    assert_redirected_to "/activar/un-token"
  end

  test "el correo de recuperación lleva al mismo lugar" do
    @con_correo.user.update!(password: "clave-vieja")
    token = @con_correo.user.send(:set_reset_password_token)

    correo = Devise.mailer.reset_password_instructions(@con_correo.user, token)

    # ⚠️ En las DOS versiones: el correo lleva HTML y texto, y quien lo abre en
    # un cliente sin HTML sigue el enlace del texto.
    [ correo.html_part, correo.text_part ].each do |parte|
      assert_match %r{/activar/#{token}}, parte.body.to_s
      assert_no_match(%r{/users/password/edit}, parte.body.to_s)
    end
  end

  # ── una persona sin credenciales sigue sin poder entrar ───────────────────

  test "antes de activar, la cuenta no entra por la puerta normal" do
    post user_session_path, params: { user: { email: "carmen@familia.test", password: "" } }

    assert_response :unprocessable_entity
    assert_nil controller.current_user
  end

  test "despues de activar, olvidé mi contraseña funciona normal" do
    codigo = generar_codigo_para(@con_correo)
    sign_out @a.director

    patch activacion_path, params: { user: { token: codigo, password: "clave-nueva",
                                             password_confirmation: "clave-nueva" } }
    delete destroy_user_session_path

    assert_emails 1 do
      post user_password_path, params: { user: { email: "carmen@familia.test" } }
    end

    assert_response :redirect
  end

  # ⚠️ Con 90 alumnos sin correo en la base, un `WHERE email = ''` que
  # coincidiera con alguno le mandaría a un desconocido el enlace para tomar esa
  # cuenta. No pasa —los correos vacíos son NULL, no `''`, y NULL no iguala a
  # nada— pero es exactamente el tipo de cosa que hay que fijar con un test.
  test "pedir recuperación con el correo vacío no le pega a nadie" do
    Current.sin_aislamiento { assert_operator User.where(email: nil).count, :>, 0 }

    assert_no_emails do
      post user_password_path, params: { user: { email: "" } }
    end
  end

  private

  # El dashboard al que redirige el guard de `RepresentativesController`.
  def dashboard_path_for_user_de_prueba = dashboards_estudiante_path

  # ── La regresión que Daniel reportó DOS veces ─────────────────────────────
  #
  # «Antes se visualizaba en pantalla el código para entregárselo al
  # representante, ahora solo va al correo».
  #
  # ⚠️ El código vivía en el `flash`, que dura UN render — y acá llegan dos.
  # `button_to` envía con Turbo, el redirect se sigue con
  # `Accept: text/vnd.turbo-stream.html`, y como no hay plantilla `.turbo_stream`
  # Rails contesta HTML; Turbo no sabe aplicarlo y repite la visita como
  # navegación normal. El primer render mostraba el enlace y el segundo lo
  # repintaba sin él:
  #
  #     POST /representantes/411/codigo
  #       └─► GET /representantes/411   as TURBO_STREAM   ← el flash sale acá
  #           └─► GET /representantes/411   as HTML       ← y acá ya no está
  #
  # Se vio en el log del servidor de Daniel, no razonando: las dos peticiones
  # están ahí, en el mismo segundo.
  test "el enlace sigue a la vista si la pantalla se vuelve a pedir" do
    sign_in @a.director
    post codigo_representative_path(@con_correo)
    follow_redirect!

    assert_select "p.codigo-de-acceso-enlace"

    # El segundo render —el que hace Turbo— ya no encontraba el flash.
    get representative_path(@con_correo)

    # El enlace se ve una sola vez y no se puede recuperar: no puede depender
    # de que el navegador no vuelva a pedir la página.
    assert_select "p.codigo-de-acceso-enlace"
  end

  test "y sobrevive a una recarga entera" do
    sign_in @a.director
    post codigo_teacher_path(@a.registro_de_profesor)
    follow_redirect!
    get teacher_path(@a.registro_de_profesor)

    assert_select "p.codigo-de-acceso-enlace"
  end

  # ⚠️ Con dos fichas abiertas, el enlace de una no puede salir en la otra.
  test "el enlace solo se ve en la ficha de su dueño" do
    sign_in @a.director
    post codigo_representative_path(@con_correo)
    follow_redirect!

    get teacher_path(@a.registro_de_profesor)

    assert_select "p.codigo-de-acceso-enlace", count: 0
  end

  test "«Ya lo copié» lo retira" do
    sign_in @a.director
    post codigo_representative_path(@con_correo)
    follow_redirect!

    delete codigo_a_la_vista_path,
           headers: { "HTTP_REFERER" => representative_path(@con_correo) }
    follow_redirect!

    assert_nil session[:codigo_a_la_vista]
    assert_select "p.codigo-de-acceso-enlace", count: 0
  end
end
