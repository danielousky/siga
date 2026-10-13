require "test_helper"

# «Suscripción» y el reporte de su pago, del lado del colegio (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.3 a 5.5).
#
#     el muro o el aviso  ──►  «Suscripción»: en qué está, cuánto cuesta, cómo pagar
#                         ──►  reporta el pago  ──►  queda «en revisión»
#
# Hasta el 12 de octubre de 2026 el muro terminaba en «se activa con la
# suscripción» y ahí se acababa el camino: ni precio, ni cómo pagar, ni a quién
# escribir. Lo que estos tests sostienen es que cada callejón tiene salida.
#
# La validación —lo que hace SIGA con el reporte— está en `pagos_en_siga_test`.
class SuscripcionDelColegioTest < ActionDispatch::IntegrationTest
  include CobroDeLaSuscripcion

  setup do
    @a, @b = dos_colegios_completos(suscripcion: :gratis)
    cargar_los_ajustes_de_siga
    sign_in @a.director
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién la ve (decisión 14: quien lleva el dinero es quien paga)
  # ══════════════════════════════════════════════════════════════════════════

  test "la dirección la ve, y la tiene en su menú" do
    get suscripcion_path

    assert_response :success
    assert_select "nav a[href=?], aside a[href=?]", suscripcion_path, suscripcion_path, minimum: 1
  end

  test "finanzas también" do
    sign_in admin_del_colegio(@a, :finanzas)

    get suscripcion_path

    assert_response :success
    assert_select "a[href=?]", suscripcion_path, minimum: 1
  end

  # ⚠️ Un enlace que se ve y rebota enseña que los enlaces de este sistema a
  # veces no funcionan: el menú se hace la MISMA pregunta que la pantalla.
  test "la coordinación no: ni la pantalla ni el enlace" do
    sign_in admin_del_colegio(@a, :coordinador)

    get suscripcion_path
    assert_response :redirect
    assert_match(/la lleva la dirección/, flash[:alert])

    follow_redirect!
    assert_select "a[href=?]", suscripcion_path, 0
  end

  test "un profesor tampoco, ni puede reportar un pago" do
    sign_in @a.profesor

    get suscripcion_path
    assert_response :redirect

    assert_no_difference -> { cantidad(SubscriptionPayment) } do
      post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }
    end
    assert_response :redirect
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Qué dice
  # ══════════════════════════════════════════════════════════════════════════

  # El colegio de prueba tiene dos alumnos: le toca el mínimo, 45 $.
  #
  # ⚠️ UN renglón, y sin IVA aparte (decisión 28): lo que se lee es lo que se
  # paga. Tenía tres —monto, IVA y total— y Daniel lo vio «muy incómodo».
  test "sin pagar: lo dice, con el precio de ese colegio y sin IVA aparte" do
    get suscripcion_path

    assert_select ".suscripcion-estado--sin-activar", text: /Sin suscripción activa/
    assert_select ".suscripcion-cuenta tr", 1
    assert_select ".suscripcion-cuenta-total" do
      assert_select "td", text: /2 alumnos inscritos · el mínimo, al mes/
      assert_select "td", text: "45,00 $"
    end
    assert_select ".suscripcion-cuenta", text: /IVA/, count: 0
  end

  # Por encima del mínimo, la cuenta se desglosa: tantos alumnos por tanto.
  test "por encima del mínimo, la cuenta dice los alumnos y su precio" do
    stub_const(Subscription, :MINIMO_MENSUAL, BigDecimal("0.10")) do
      get suscripcion_path
    end

    assert_select ".suscripcion-cuenta-total td", text: /2 alumnos inscritos × 0,35 \$, al mes/
    assert_select ".suscripcion-cuenta-total td", text: "0,70 $"
  end

  # Los seis estados del § 5.3, cada uno con su frase.
  test "activa: hasta cuándo" do
    pagando(vence: Date.current + 20)
    get suscripcion_path

    assert_select ".suscripcion-estado--activa", text: /Activa hasta el #{I18n.l(Date.current + 20, format: :long)}/
  end

  test "por vencer: cuándo vence" do
    pagando(vence: Date.current + 3)
    get suscripcion_path

    assert_select ".suscripcion-estado--por-vencer", text: /Vence el #{I18n.l(Date.current + 3, format: :long)}/
  end

  test "en gracia: cuántos días le quedan" do
    pagando(vence: Date.current - 3, estado: :en_gracia)
    get suscripcion_path

    assert_select ".suscripcion-estado--en-gracia", text: /Quedan 12 días antes de pasar a solo lectura/
  end

  test "solo lectura: qué puede hacer y cómo salir" do
    pagando(vence: Date.current - 40, estado: :vencida)
    get suscripcion_path

    assert_select ".suscripcion-estado--solo-lectura", text: /para volver a cargar, hay que reportar el pago/
  end

  # ⚠️ El pago en revisión va PRIMERO, antes que cualquier otro estado: el
  # director que ya pagó y lee «sin suscripción activa» cree que su reporte se
  # perdió, y reporta otra vez.
  test "con el pago reportado: que se está validando" do
    pago_reportado(@a)
    get suscripcion_path

    assert_select ".suscripcion-estado--en-revision", text: /Pago en revisión/
    assert_select ".suscripcion-estado--sin-activar", 0
  end

  # ── Cómo pagar ────────────────────────────────────────────────────────────

  test "muestra los datos de cada medio, tal como están en los ajustes de SIGA" do
    get suscripcion_path

    assert_select ".suscripcion-medio", 3
    assert_select ".suscripcion-medios", text: /Banco de Venezuela \(0102\)/
    assert_select ".suscripcion-medios", text: /0424-7654321/
    assert_select ".suscripcion-medios", text: /J-12345678-9/
    assert_select ".suscripcion-medios", text: /01020000000000001234/
    assert_select ".suscripcion-medios", text: /Empresa de Prueba, C\.A\./
    assert_select ".suscripcion-medios", text: /987654321/
    assert_select ".suscripcion-medios", text: /Efectivo en dólares/
  end

  # ⚠️ Un medio sin sus datos no se puede pagar: ofrecerlo deja al colegio con
  # el teléfono en la mano y sin a dónde mandar el dinero.
  test "un medio sin sus datos no aparece" do
    cargar_los_ajustes_de_siga(binance: nil)
    get suscripcion_path

    assert_select ".suscripcion-medio", 2
    assert_select ".suscripcion-medios", text: /Binance/, count: 0
  end

  # Un botón que abre un chat con nadie es peor que no tener botón.
  test "sin WhatsApp cargado no hay botón de WhatsApp ni efectivo" do
    cargar_los_ajustes_de_siga(whatsapp: nil)
    get suscripcion_path

    assert_select "a[href*='wa.me']", 0
    assert_select ".suscripcion-medios", text: /Efectivo/, count: 0
  end

  test "el botón de WhatsApp lleva al número de los ajustes" do
    get suscripcion_path

    assert_select "a[href^='https://wa.me/584141234567']", text: /Escribir por WhatsApp/
  end

  test "sin ningún medio cargado lo dice, y no ofrece reportar" do
    SigaSetting.delete_all
    get suscripcion_path

    assert_response :success
    assert_select "p", text: /Todavía no hay medios de pago cargados/
    assert_select "a[href=?]", new_suscripcion_pago_path, 0
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Reportar el pago
  # ══════════════════════════════════════════════════════════════════════════

  test "el colegio reporta su pago, y queda en revisión" do
    assert_difference -> { cantidad(SubscriptionPayment) }, 1 do
      post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }
    end

    assert_redirected_to suscripcion_path
    Current.sin_aislamiento do
      pago = SubscriptionPayment.last
      assert pago.en_revision?
      assert_equal @a.colegio.id, pago.school_id
      assert_equal @a.director, pago.reportado_por
      assert_equal "pago_movil", pago.medio
      assert_equal BigDecimal("18250.50"), pago.monto
      assert_equal "0012345678", pago.referencia
      assert pago.comprobante.attached?
      assert_equal BigDecimal("45"), pago.cotizacion.monto, "guarda la cuenta con que se reportó"
    end
  end

  # ⚠️ Reportar NO abre nada (decisión 4): lo abre la validación. Sin esa
  # separación, quien escriba cualquier número de referencia se activa el
  # sistema.
  test "reportar no activa nada: sigue sin poder calificar" do
    post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }

    assert suscripcion_de(@a.colegio).gratis?
    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno), params: { score: 15 }, as: :json
    assert_response :payment_required
  end

  # Es lo que hace que reportar no sea un formulario al vacío.
  test "a SIGA le llega el aviso, con lo que hay que buscar en el banco" do
    con_la_variable("SIGA_AVISOS_EMAIL", "avisos@siga.test") do
      assert_emails 1 do
        perform_enqueued_jobs { post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago } }
      end
    end

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ "avisos@siga.test" ], correo.to
    assert_match(/Pago por validar: #{Regexp.escape(@a.colegio.name)} · 18\.250,50 Bs/, correo.subject)
    assert_includes correo.text_part.body.to_s, "0012345678"
    assert_includes correo.text_part.body.to_s, "45,00 $"
    assert_includes correo.text_part.body.to_s, siga_cartera_index_path
  end

  test "y queda en el historial del colegio" do
    post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.where(action: "suscripcion_pago_reportado").last
      assert rastro, "reportar el pago no dejó rastro"
      assert_match(/reportó el pago de la suscripción/, rastro.message)
      assert_equal @a.director.id, rastro.user_id
    end
  end

  test "después de reportar, la pantalla lo dice y ya no ofrece reportar otro" do
    post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }
    follow_redirect!

    assert_select ".alert-success", text: /Recibimos su reporte/
    assert_select ".suscripcion-estado--en-revision"
    assert_select "a[href=?]", new_suscripcion_pago_path, 0
    assert_select "td", text: /0012345678/
  end

  # En efectivo no hay referencia, y a veces tampoco papel.
  test "en efectivo no hacen falta referencia ni comprobante" do
    assert_difference -> { cantidad(SubscriptionPayment) }, 1 do
      post suscripcion_pagos_path,
           params: { subscription_payment: { medio: "efectivo", monto: "45", pagado_el: Date.current.to_s } }
    end

    Current.sin_aislamiento do
      pago = SubscriptionPayment.last
      assert_equal "$", pago.unidad
      assert_nil pago.referencia
    end
  end

  test "por Pago Móvil sin comprobante no pasa, y dice qué falta" do
    assert_no_difference -> { cantidad(SubscriptionPayment) } do
      post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago.except(:comprobante) }
    end

    assert_response :unprocessable_entity
    assert_match(/Comprobante hace falta/, response.body)
  end

  test "el formulario ofrece solo los medios que SIGA tiene cargados" do
    cargar_los_ajustes_de_siga(binance: nil)
    get new_suscripcion_pago_path

    assert_response :success
    assert_select "input[type=radio][name='subscription_payment[medio]']", 2
    assert_select "input[type=radio][value=binance]", 0
    # La unidad que el campo muestra sale del medio: nadie escribe «Bs» a mano.
    assert_select "input[type=radio][value=pago_movil][data-unidad=Bs]"
    assert_select "input[type=radio][value=efectivo][data-unidad='$']"
  end

  # El número que tiene que coincidir con lo que pagó, a la vista mientras llena.
  test "el formulario le recuerda cuánto le toca" do
    get new_suscripcion_pago_path

    assert_select ".reporte-de-pago-cuenta", text: /45,00 \$ al mes/
  end

  test "sin medios cargados no hay formulario: vuelve a «Suscripción»" do
    SigaSetting.delete_all

    get new_suscripcion_pago_path

    assert_redirected_to suscripcion_path
    assert_match(/Todavía no hay medios de pago cargados/, flash[:alert])
  end

  # ── Uno en revisión a la vez ──────────────────────────────────────────────

  test "con un pago en revisión, el formulario ni se abre" do
    pago_reportado(@a)

    get new_suscripcion_pago_path

    assert_redirected_to suscripcion_path
    assert_match(/Ya hay un pago esperando validación/, flash[:alert])
  end

  test "y mandarlo igual tampoco lo crea" do
    pago_reportado(@a)

    assert_no_difference -> { cantidad(SubscriptionPayment) } do
      post suscripcion_pagos_path,
           params: { subscription_payment: datos_del_pago.merge(referencia: "OTRA-12345") }
    end

    assert_response :unprocessable_entity
  end

  # ⚠️ El doble envío: dos peticiones que pasan A LA VEZ la validación de arriba,
  # y la segunda choca contra el índice de la base. Era un 500 en la pantalla
  # donde el colegio dice que pagó.
  #
  # Para reproducirlo sin dos hilos se apaga la validación del modelo: lo que
  # queda es exactamente lo que ve la segunda petición de la carrera. Y que la
  # página se DIBUJE después del choque prueba la otra mitad: el `SAVEPOINT`
  # dejó viva la transacción de la petición.
  test "un doble envío no revienta: dice que el pago ya quedó reportado" do
    pago_reportado(@a)

    sin_la_validacion_de_uno_a_la_vez do
      assert_no_difference -> { cantidad(SubscriptionPayment) } do
        post suscripcion_pagos_path,
             params: { subscription_payment: datos_del_pago.merge(referencia: "OTRA-12345") }
      end
    end

    assert_response :unprocessable_entity
    assert_match(/Ese pago ya quedó reportado/, response.body)
  end

  # ── Retirar ───────────────────────────────────────────────────────────────

  # Se equivocó de monto o de referencia, y como solo cabe uno en revisión, sin
  # esto quedaría esperando a que se lo rechacen.
  test "el colegio retira su reporte mientras nadie lo ha mirado" do
    pago = pago_reportado(@a)

    assert_difference -> { cantidad(SubscriptionPayment) }, -1 do
      delete suscripcion_pago_path(pago)
    end

    assert_redirected_to suscripcion_path
    con_el_colegio(@a.colegio) { assert ActivityLog.exists?(action: "suscripcion_pago_retirado") }
  end

  # Uno validado ya abrió el sistema: retirarlo borraría la historia de qué se pagó.
  test "uno ya validado no se retira" do
    pago = pago_reportado(@a)
    Current.sin_aislamiento { pago.validar!(por: equipo_de_siga) }

    assert_no_difference -> { cantidad(SubscriptionPayment) } do
      delete suscripcion_pago_path(pago)
    end

    assert_match(/ya se revisó/, flash[:alert])
  end

  test "el colegio de al lado no ve ni retira el pago de este" do
    pago = pago_reportado(@a, referencia: "SOLO-DE-A-01")
    sign_in @b.director

    get suscripcion_path
    assert_no_match(/SOLO-DE-A-01/, response.body)

    assert_no_difference -> { cantidad(SubscriptionPayment) } do
      delete suscripcion_pago_path(pago)
    end
    assert_response :not_found
  end

  # ── El rechazo ────────────────────────────────────────────────────────────

  # Es la respuesta que el colegio está esperando: va arriba, con su motivo.
  test "el rechazo se lee arriba, con su motivo, y se puede reportar de nuevo" do
    pago = pago_reportado(@a)
    Current.sin_aislamiento { pago.rechazar!(por: equipo_de_siga, motivo: "La referencia no aparece en el banco") }

    get suscripcion_path

    assert_select ".suscripcion-rechazo", text: /no se pudo validar/
    assert_select ".suscripcion-rechazo", text: /La referencia no aparece en el banco/
    assert_select "a[href=?]", new_suscripcion_pago_path
  end

  # Si ya volvió a reportar, el rechazo es historia: queda en la tabla y no arriba.
  test "con un reporte nuevo después del rechazo, el rechazo ya no va arriba" do
    pago = pago_reportado(@a)
    Current.sin_aislamiento { pago.rechazar!(por: equipo_de_siga, motivo: "El monto no coincide") }
    pago_reportado(@a)

    get suscripcion_path

    assert_select ".suscripcion-rechazo", 0
    assert_select "td", text: /El monto no coincide/
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Las dos salidas: de lo gratis y de la solo lectura
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ El colegio vencido está en solo lectura, y la solo lectura rechaza
  # CUALQUIER verbo que escriba. Sin la excepción, cerraba también la única
  # puerta para dejar de estar vencido.
  test "un colegio vencido puede reportar su pago" do
    pagando(vence: Date.current - 40, estado: :vencida)

    assert_difference -> { cantidad(SubscriptionPayment) }, 1 do
      post suscripcion_pagos_path, params: { subscription_payment: datos_del_pago }
    end

    assert_redirected_to suscripcion_path
  end

  test "y sigue sin poder cargar nada más" do
    pagando(vence: Date.current - 40, estado: :vencida)

    assert_no_difference -> { cantidad(Subject) } do
      post subjects_path, params: { subject: { name: "Francés", code: "FRA",
                                               department_id: @a.materia.department_id } }
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El muro y el aviso llevan a «Suscripción»
  # ══════════════════════════════════════════════════════════════════════════

  test "el muro le dice a la dirección adónde ir" do
    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id },
                           headers: { "HTTP_REFERER" => constancias_url }

    assert_equal({ "texto" => "Ver cómo activarla", "url" => suscripcion_path }, flash[:enlace])

    follow_redirect!
    assert_select ".alert-danger a.alert-enlace[href=?]", suscripcion_path, text: /Ver cómo activarla/
  end

  # La planilla de asistencia se guarda por JSON, y pinta el enlace que le llega.
  test "también en la respuesta JSON" do
    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s }, as: :json

    assert_response :payment_required
    assert_equal suscripcion_path, response.parsed_body.dig("enlace", "url")
    assert_equal "Ver cómo activarla", response.parsed_body.dig("enlace", "texto")
  end

  # Un profesor no tiene nada que hacer en «Suscripción»: un enlace que rebota
  # es peor que ninguno.
  test "al profesor no le ofrece el enlace" do
    sign_in @a.profesor

    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno), params: { score: 15 }, as: :json

    assert_response :payment_required
    assert_not response.parsed_body.key?("enlace")
  end

  # ⚠️ El director que pagó ayer y hoy toca «Emitir» no puede leer otra vez lo
  # que cuesta: creería que su reporte se perdió, y reportaría dos veces.
  test "con el pago ya reportado, el muro dice eso y no vuelve a cobrar" do
    pago_reportado(@a)

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }

    assert_match(/ya reportó el pago de la suscripción/, flash[:alert])
    assert_no_match(/\$/, flash[:alert])
    assert_equal "Ver la suscripción", flash[:enlace]["texto"]
  end

  test "y al profesor le dice lo mismo, sin enlace" do
    pago_reportado(@a)
    sign_in @a.profesor

    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno), params: { score: 15 }, as: :json

    assert_match(/ya reportó el pago/, response.parsed_body["mensaje"])
    assert_not response.parsed_body.key?("enlace")
  end

  test "el aviso de arriba enlaza a «Suscripción» para quien la paga" do
    get dashboards_administrador_path

    assert_select ".aviso-suscripcion a.aviso-suscripcion-enlace[href=?]", suscripcion_path
  end

  test "y para el profesor no" do
    sign_in @a.profesor
    get dashboards_profesor_path

    assert_select ".aviso-suscripcion", text: /Sin suscripción activa/
    assert_select ".aviso-suscripcion a", 0
  end

  # ⚠️ Con el pago esperando, el aviso lo DICE en vez de volver a pedirlo.
  test "con el pago reportado, el aviso deja de pedir que se pague" do
    pago_reportado(@a)
    get dashboards_administrador_path

    assert_select ".aviso-suscripcion", text: /Recibimos su pago/
    assert_select ".aviso-suscripcion a", 0
  end

  test "vencido: el muro de la solo lectura también lleva a «Suscripción»" do
    pagando(vence: Date.current - 40, estado: :vencida)

    post subjects_path, params: { subject: { name: "Francés", code: "FRA",
                                             department_id: @a.materia.department_id } }

    assert_equal({ "texto" => "Ver cómo pagar", "url" => suscripcion_path }, flash[:enlace])
    assert_match(/hasta que se valide el pago/, flash[:alert])
  end

  test "cinco días antes de vencer, la dirección ve cuándo vence" do
    pagando(vence: Date.current + 4)
    get dashboards_administrador_path

    assert_select ".aviso-suscripcion", text: /La suscripción vence el #{I18n.l(Date.current + 4, format: :long)}/
  end

  test "y con tiempo de sobra no ve ningún cartel" do
    pagando(vence: Date.current + 20)
    get dashboards_administrador_path

    assert_select ".aviso-suscripcion", 0
  end

  private

  def datos_del_pago
    { medio: "pago_movil", monto: "18250.50", referencia: "0012345678",
      pagado_el: Date.current.to_s, comprobante: comprobante_para_subir }
  end

  # Apaga, mientras dura el bloque, la validación que impide el segundo reporte:
  # deja al modelo como lo ve la petición que perdió la carrera.
  def sin_la_validacion_de_uno_a_la_vez
    SubscriptionPayment.class_eval do
      alias_method :uno_en_revision_de_verdad, :uno_en_revision_a_la_vez
      define_method(:uno_en_revision_a_la_vez) { nil }
    end
    yield
  ensure
    SubscriptionPayment.class_eval do
      alias_method :uno_en_revision_a_la_vez, :uno_en_revision_de_verdad
      remove_method :uno_en_revision_de_verdad
      private :uno_en_revision_a_la_vez
    end
  end

  # Deja al colegio con su suscripción paga, venciendo el día que se diga.
  def pagando(vence:, estado: :activa)
    Current.sin_aislamiento do
      suscripcion_de(@a.colegio).update!(plan: :por_alumno, status: estado,
                                         precio_por_alumno: Subscription::PRECIO_POR_ALUMNO,
                                         minimo_mensual: Subscription::MINIMO_MENSUAL,
                                         precio_mensual: Subscription::MINIMO_MENSUAL,
                                         vigente_desde: vence - 1.month, vigente_hasta: vence)
    end
  end
end
