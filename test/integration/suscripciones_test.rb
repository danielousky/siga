require "test_helper"

# La suscripción de cada colegio, y lo que pasa cuando vence (MOR-108).
#
# La decisión más importante del módulo, y la que estos tests sostienen: **al
# vencer se degrada a SOLO LECTURA, nunca se corta el acceso.**
#
# > *"Cortar el acceso a un colegio a mitad de año escolar es quitarle las notas
# > de sus alumnos — se gana la disputa de cobranza y se pierde el cliente y su
# > reputación en la red."*
class SuscripcionesTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @a, @b = dos_colegios_completos
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Solo lectura, no corte de acceso
  # ══════════════════════════════════════════════════════════════════════════

  test "con la suscripción vencida se sigue viendo TODO" do
    vencer!(@a)
    sign_in @a.director

    # Lo que la familia y el colegio necesitan aunque haya una deuda de por medio.
    %w[/dashboards/administrador /students /grades /boletines /constancias /asistencia].each do |ruta|
      get ruta
      # /asistencia redirige a la sección cuando hay una sola: es el atajo de
      # MOR-111, no un bloqueo.
      follow_redirect! if response.redirect?

      assert_response :success, "#{ruta} tiene que seguir viéndose: cortarlo es quitarle las notas al colegio"
    end
  end

  test "y se siguen descargando los documentos oficiales" do
    vencer!(@a)
    sign_in @a.director

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    # Es un POST, pero lo que hace es LEER y devolver un PDF. Un colegio con una
    # deuda no puede quedarse sin poder darle una constancia a una familia.
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "pero no se puede cargar nada nuevo" do
    vencer!(@a)
    sign_in @a.director

    assert_no_difference -> { con_el_colegio(@a.colegio) { Department.count } } do
      post departments_url, params: { department: { name: "Nuevo con deuda" } }
    end

    assert_response :redirect
    assert_match(/suscripción del colegio está vencida/i, flash[:alert])
  end

  # Se bloquea por VERBO y no por pantalla: esconder los botones de guardar no es
  # solo lectura, es una sugerencia.
  test "armar la petición a mano tampoco sirve" do
    vencer!(@a)
    sign_in @a.profesor

    patch "/evaluation_activities/#{@a.actividad.id}/notas/#{@a.alumno.id}",
          params: { score: "20" }, as: :json

    assert_response :payment_required
  end

  test "los cuatro verbos que escriben quedan bloqueados" do
    vencer!(@a)
    sign_in @a.director

    patch "/departments/#{@a.departamento.id}", params: { department: { name: "Cambiado" } }
    assert_response :redirect

    delete "/departments/#{@a.departamento.id}"
    assert_response :redirect

    con_el_colegio(@a.colegio) do
      assert Department.exists?(@a.departamento.id), "se borró con la suscripción vencida"
    end
  end

  # Dejar a alguien encerrado sin poder salir sería un error distinto y peor.
  test "siempre se puede cerrar sesión" do
    vencer!(@a)
    sign_in @a.director

    delete destroy_user_session_path

    assert_response :redirect
    assert_no_match(/vencida/i, flash[:alert].to_s)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los estados intermedios
  # ══════════════════════════════════════════════════════════════════════════
  #
  # `en_gracia` es la diferencia entre un colegio que se atrasó una semana y uno
  # que dejó de pagar. Sin ese estado, el primero se queda sin cargar notas el
  # lunes por una transferencia que sale el martes.

  test "en gracia todavía se puede escribir" do
    con_el_colegio(@a.colegio) do
      Subscription.create!(school: @a.colegio, plan: :basico, status: :activa,
                           vigente_hasta: Date.current - 3, dias_de_gracia: 15)
                  .actualizar_estado!
    end
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { Department.count } }, 1 do
      post departments_url, params: { department: { name: "Con gracia" } }
    end
  end

  test "el estado se mueve solo según la fecha" do
    suscripcion = con_el_colegio(@a.colegio) do
      Subscription.create!(school: @a.colegio, plan: :basico, status: :activa,
                           vigente_hasta: Date.new(2026, 8, 1), dias_de_gracia: 10)
    end

    con_el_colegio(@a.colegio) do
      travel_to(Date.new(2026, 7, 20)) { suscripcion.actualizar_estado!; assert suscripcion.activa? }
      travel_to(Date.new(2026, 8, 5))  { suscripcion.actualizar_estado!; assert suscripcion.en_gracia? }
      travel_to(Date.new(2026, 8, 20)) { suscripcion.actualizar_estado!; assert suscripcion.vencida? }
    end
  end

  # ⚠️ Sin suscripción se PUEDE escribir, y es deliberado: son los colegios que
  # todavía no se facturan —una demo, un piloto—. Bloquearlos rompería el
  # producto para quien lo está evaluando.
  test "un colegio sin suscripción escribe normalmente" do
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { Department.count } }, 1 do
      post departments_url, params: { department: { name: "Sin facturar todavía" } }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El plan sale de la matrícula ACTIVA del año vigente
  # ══════════════════════════════════════════════════════════════════════════

  test "los cortes del contrato" do
    assert_equal :basico,     Subscription.plan_para(1)
    assert_equal :basico,     Subscription.plan_para(150)
    assert_equal :estandar,   Subscription.plan_para(151)
    assert_equal :estandar,   Subscription.plan_para(400)
    assert_equal :premium,    Subscription.plan_para(401)
    assert_equal :premium,    Subscription.plan_para(800)
    # El borde que el issue pedía definir: arriba de 800 no hay precio
    # automático, están las redes de colegios.
    assert_equal :a_convenir, Subscription.plan_para(801)
    assert_nil Subscription.precio_para(801)
  end

  test "la matrícula cuenta las inscripciones ACTIVAS del año vigente" do
    con_el_colegio(@a.colegio) do
      assert_equal 2, Subscription.matricula_de(@a.colegio.id)

      # Un alumno retirado deja de contar: el colegio no lo tiene.
      @a.inscripcion.update!(status: :retirado)
      @a.inscripcion.reload
      assert_equal 1, Subscription.matricula_de(@a.colegio.id)
    end
  end

  test "la matrícula de un colegio no cuenta la del otro" do
    con_el_colegio(@a.colegio) do
      assert_equal 2, Subscription.matricula_de(@a.colegio.id)
      assert_equal 2, Subscription.matricula_de(@b.colegio.id),
                   "cada colegio cuenta lo suyo"
    end
  end

  # Que difieran no es un error: el plan se OBSERVA siempre y se COBRA al
  # renovar. Un aumento sorpresa a mitad de año escolar es la clase de cosa que
  # se comenta entre colegios.
  test "crecer de matrícula no cambia lo facturado" do
    suscripcion = con_el_colegio(@a.colegio) do
      Subscription.create!(school: @a.colegio, plan: :basico, status: :activa,
                           matricula_facturada: 2, precio_mensual: 25,
                           vigente_hasta: Date.current + 1.month)
    end

    con_el_colegio(@a.colegio) do
      assert_equal 25, suscripcion.precio_mensual
      assert_equal :basico, suscripcion.plan.to_sym
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La cartera es de SIGA, no de los colegios
  # ══════════════════════════════════════════════════════════════════════════

  test "un director no ve la cartera de la plataforma" do
    sign_in @a.director

    get "/siga/cartera"

    assert_response :redirect
  end

  test "el equipo de SIGA ve el estado de todos" do
    staff = User.create!(first_name: "Equipo", last_name: "SIGA", password: "123123", email: "cartera@siga.app",
                        document: "V-#{"cartera@siga.app".bytes.sum}")
    SigaStaff.create!(user: staff, role: :fundador)
    vencer!(@a)
    sign_in staff

    get "/siga/cartera"

    assert_response :success
    assert_match(/#{Regexp.escape(@a.colegio.name)}/, response.body)
    assert_match(/#{Regexp.escape(@b.colegio.name)}/, response.body)
    assert_match(/solo lectura/i, response.body)
  end

  # El colegio sí tiene derecho a saber que ÉL está vencido — lo que no ve es
  # quién más lo está.
  test "el colegio ve su propio aviso de vencimiento" do
    vencer!(@a)
    sign_in @a.director

    get dashboards_administrador_url

    assert_select ".aviso-suscripcion--vencida"
    assert_match(/no cargar información nueva/i, response.body)
  end

  test "un colegio al día no ve ningún cartel" do
    con_el_colegio(@a.colegio) do
      Subscription.create!(school: @a.colegio, plan: :basico, status: :activa,
                           vigente_hasta: Date.current + 1.month)
    end
    sign_in @a.director

    get dashboards_administrador_url

    assert_select ".aviso-suscripcion", count: 0,
                  message: "un cartel permanente de 'estás al día' es ruido que se deja de ver"
  end

  private

  def vencer!(colegio)
    con_el_colegio(colegio.colegio) do
      Subscription.create!(school: colegio.colegio, plan: :basico, status: :vencida,
                           vigente_hasta: Date.current - 60, dias_de_gracia: 15)
    end
  end
end
