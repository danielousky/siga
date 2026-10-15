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
    [ dashboards_administrador_path, students_path, grades_path,
      report_cards_path, constancias_path, certificados_path, asistencias_path ].each do |ruta|
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

  # ⚠️ El certificado se pide por dos puertas y tiene que salir por las dos.
  #
  # Desde la ficha es un GET, que la suscripción vencida no bloquea. Desde la
  # pestaña de «Documentos» es un POST —llegó el 1 de octubre de 2026— y los
  # POST sí se bloquean. Sin su línea en `SIEMPRE_PERMITIDO`, el colegio
  # endeudado sacaba el certificado de un alumno abriendo su ficha y no podía
  # sacarlo desde la pestaña: el mismo papel, según por dónde se pida.
  test "y los certificados, por la pestaña igual que por la ficha" do
    vencer!(@a)
    sign_in @a.director

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    assert_response :success
    assert_equal "application/pdf", response.media_type

    get certificacion_de_calificaciones_path(student_id: @a.alumno, format: :pdf)

    assert_response :success
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

    patch evaluation_activity_nota_path(@a.actividad, @a.alumno),
          params: { score: "20" }, as: :json

    assert_response :payment_required
  end

  test "los cuatro verbos que escriben quedan bloqueados" do
    vencer!(@a)
    sign_in @a.director

    patch department_path(@a.departamento), params: { department: { name: "Cambiado" } }
    assert_response :redirect

    delete department_path(@a.departamento)
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
      suscripcion_de(@a.colegio).tap do |s|
        s.update!(vigente_hasta: Date.current - 3, dias_de_gracia: 15)
        s.actualizar_estado!
      end
    end
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { Department.count } }, 1 do
      post departments_url, params: { department: { name: "Con gracia" } }
    end
  end

  test "el estado se mueve solo según la fecha" do
    suscripcion = con_el_colegio(@a.colegio) do
      suscripcion_de(@a.colegio).tap { |s| s.update!(vigente_hasta: Date.new(2026, 8, 1), dias_de_gracia: 10) }
    end

    con_el_colegio(@a.colegio) do
      travel_to(Date.new(2026, 7, 20)) { suscripcion.actualizar_estado!; assert suscripcion.activa? }
      travel_to(Date.new(2026, 8, 5))  { suscripcion.actualizar_estado!; assert suscripcion.en_gracia? }
      travel_to(Date.new(2026, 8, 20)) { suscripcion.actualizar_estado!; assert suscripcion.vencida? }
    end
  end

  # ⚠️ Sin fila cuenta como GRATIS, no como acceso completo (decisión 16 del spec
  # `del-registro-al-cobro`). Cargar sigue abierto —es la entrada—; lo que no
  # abre es operar, y eso lo prueba `plan_gratis_test`.
  test "un colegio sin suscripción carga igual" do
    Current.sin_aislamiento { suscripcion_de(@a.colegio).destroy! }
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { Department.count } }, 1 do
      post departments_url, params: { department: { name: "Sin facturar todavía" } }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El precio: por alumno, con un mínimo
  # ══════════════════════════════════════════════════════════════════════════

  # Hasta el 12 de octubre de 2026 eran bandas, y el alumno 151 duplicaba la
  # factura: 39 → 79. Ahora cada alumno cuesta lo mismo, y el chico paga el
  # mínimo. Los números son los del spec: si alguien sube el precio, este test
  # le recuerda que también cambia lo que se le dijo a Daniel.
  test "el precio sale por alumno, con su mínimo y sin escalones" do
    assert_equal BigDecimal("39"),     Subscription.cotizar(0).monto
    assert_equal BigDecimal("39"),     Subscription.cotizar(111).monto
    assert_equal BigDecimal("39.20"),  Subscription.cotizar(112).monto
    assert_equal BigDecimal("52.50"),  Subscription.cotizar(150).monto
    assert_equal BigDecimal("52.85"),  Subscription.cotizar(151).monto,
                 "el alumno 151 cuesta lo mismo que el 150"
    assert_equal BigDecimal("126"),    Subscription.cotizar(360).monto
    assert_equal BigDecimal("280"),    Subscription.cotizar(800).monto
  end

  # ⚠️ El precio es FINAL (decisión 28 del spec). Nació como «0,30 $ + IVA» y
  # Daniel lo corrigió el mismo día: *«no podemos cobrar IVA en dólares, eso no
  # es correcto… vamos a incrementarle el IVA al costo»*. Lo que cuida este
  # test es que el IVA esté ADENTRO y no vuelva como un renglón aparte: una
  # cotización tiene un monto, y ese monto es lo que se paga.
  test "el precio lleva el IVA adentro: la cuenta no desglosa ninguno" do
    cotizacion = Subscription.cotizar(360)

    assert_equal BigDecimal("126"), cotizacion.monto
    assert_not_respond_to cotizacion, :iva
    assert_not_respond_to cotizacion, :total
    assert_not Subscription.const_defined?(:IVA), "el IVA volvió a ser una constante: alguien lo va a sumar aparte"

    # 0,30 × 1,16 = 0,348, «poco menos de 0,35». El mínimo NO lleva esa cuenta:
    # salió en 45 (39 × 1,16) y Daniel lo dejó en 39 el 14 de octubre de 2026.
    assert_equal BigDecimal("0.35"), Subscription::PRECIO_POR_ALUMNO
    assert_equal BigDecimal("39"),   Subscription::MINIMO_MENSUAL
  end

  # ⚠️ Decisión 17: subir el precio toca a los que entran después. El colegio
  # que entró a 0,25 sigue a 0,25, aunque la constante diga otra cosa.
  test "el precio con que entró un colegio queda congelado" do
    suscripcion = suscripcion_de(@a.colegio)
    Current.sin_aislamiento { suscripcion.update!(precio_por_alumno: BigDecimal("0.25"), minimo_mensual: 30) }

    con_el_colegio(@a.colegio) do
      assert_equal BigDecimal("90"), suscripcion.cotizacion(360).monto
      assert_equal BigDecimal("30"), suscripcion.cotizacion(2).monto
    end
  end

  test "el gratis cotiza con el precio de hoy" do
    con_el_colegio(@a.colegio) do
      gratis = Subscription.new(school: @a.colegio, plan: :gratis)

      assert_equal Subscription.cotizar(360).monto, gratis.cotizacion(360).monto
    end
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
      suscripcion_de(@a.colegio).tap do |s|
        s.update!(matricula_facturada: 2, precio_mensual: 45, vigente_hasta: Date.current + 1.month)
      end
    end

    con_el_colegio(@a.colegio) do
      assert_equal BigDecimal("45"), suscripcion.reload.precio_mensual
      assert_equal 2, suscripcion.matricula_facturada
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
    Current.sin_aislamiento { suscripcion_de(@a.colegio).update!(vigente_hasta: Date.current + 1.month) }
    sign_in @a.director

    get dashboards_administrador_url

    assert_select ".aviso-suscripcion", count: 0,
                  message: "un cartel permanente de 'estás al día' es ruido que se deja de ver"
  end

  private

  def vencer!(colegio)
    Current.sin_aislamiento do
      suscripcion_de(colegio.colegio).update!(status: :vencida, vigente_hasta: Date.current - 60,
                                              dias_de_gracia: 15)
    end
  end
end
