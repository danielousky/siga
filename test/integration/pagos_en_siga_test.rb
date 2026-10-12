require "test_helper"

# Validar y rechazar en `/siga` lo que reportó un colegio (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.6).
#
#     Validar   ──►  la suscripción queda activa por un mes, y se abre todo en el momento
#     Rechazar  ──►  pide el motivo; el colegio lo ve en su pantalla y le llega por correo
#
# Hasta el 12 de octubre de 2026 esto se hacía por consola: la Cartera tenía la
# acción `update` y ninguna pantalla la llamaba.
class PagosEnSigaTest < ActionDispatch::IntegrationTest
  include CobroDeLaSuscripcion

  setup do
    @a, @b = dos_colegios_completos(suscripcion: :gratis)
    cargar_los_ajustes_de_siga
    @fundador    = equipo_de_siga(:fundador)
    @operaciones = equipo_de_siga(:operaciones)
    @pago = pago_reportado(@a, monto: BigDecimal("18250.50"), referencia: "0012345678")
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La Cartera dice qué espera
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Los dos números, separados y sin compararlos: lo que le toca está en
  # dólares y lo que pagó, en la unidad de su medio. El puente —la tasa BCV del
  # día— lo hace quien valida, con el comprobante delante.
  test "la Cartera muestra el pago que espera, con lo que pagó y lo que le toca" do
    sign_in @fundador
    get siga_cartera_index_path

    assert_response :success
    assert_select ".siga-pago", 1 do
      assert_select ".siga-pago-colegio", text: @a.colegio.name
      assert_select ".siga-pago-datos", text: /Pago Móvil o transferencia/
      assert_select ".siga-pago-datos", text: /18\.250,50 Bs/
      assert_select ".siga-pago-datos", text: /0012345678/
      assert_select ".siga-pago-datos", text: /45,24 \$/
      assert_select "a", text: /Ver el comprobante/
      assert_select "form[action=?]", validar_siga_pago_path(@pago)
      assert_select "form[action=?] input[name=motivo][required]", rechazar_siga_pago_path(@pago)
    end
  end

  test "sin pagos esperando, lo dice" do
    Current.sin_aislamiento { @pago.destroy! }
    sign_in @fundador

    get siga_cartera_index_path

    assert_select ".siga-vacio", text: /Ningún pago espera validación/
  end

  # ⚠️ Operaciones ve la lista y no aprieta (decisión 22): validar le abre el
  # sistema a un colegio.
  test "operaciones ve el pago, sin botones" do
    sign_in @operaciones
    get siga_cartera_index_path

    assert_select ".siga-pago", 1
    assert_select "form[action=?]", validar_siga_pago_path(@pago), 0
    assert_select "form[action=?]", rechazar_siga_pago_path(@pago), 0
    assert_select ".siga-pago", text: /Valida el fundador/
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Validar
  # ══════════════════════════════════════════════════════════════════════════

  test "el fundador valida, y el colegio queda activo por un mes" do
    sign_in @fundador

    patch validar_siga_pago_path(@pago)

    assert_redirected_to siga_cartera_index_path
    assert_match(/Validado\. #{Regexp.escape(@a.colegio.name)} queda activo hasta el/, flash[:notice])

    suscripcion = suscripcion_de(@a.colegio)
    assert suscripcion.por_alumno?
    assert suscripcion.activa?
    assert_equal Date.current + 1.month, suscripcion.vigente_hasta
    Current.sin_aislamiento { assert @pago.reload.validado? }
  end

  # ⚠️ El criterio del spec: «abre calificar, asistencia y salidas en el momento».
  test "y el colegio puede calificar, pasar lista y emitir enseguida" do
    sign_in @fundador
    patch validar_siga_pago_path(@pago)
    sign_out @fundador

    # Calificar es del profesor de esa área; pasar lista y emitir, de la dirección.
    sign_in @a.profesor
    patch evaluation_activity_nota_path(@a.actividad, @a.escenario.alumno), params: { score: 15 }, as: :turbo_stream
    assert_response :success
    sign_out @a.profesor

    sign_in @a.director
    post seccion_asistencia_path(@a.seccion), params: { dia: Date.current.to_s, estados: {} }, as: :json
    assert_response :success

    post constancias_path, params: { section_id: @a.seccion.id, enrollment_id: @a.inscripcion.id }
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "al otro colegio no le cambia nada" do
    sign_in @fundador
    patch validar_siga_pago_path(@pago)

    assert suscripcion_de(@b.colegio).gratis?
  end

  # Decisión 23: el colegio se entera sin tener que entrar a mirar ni preguntar.
  test "a quien reportó le llega el correo de que ya está activa" do
    sign_in @fundador

    assert_emails 1 do
      perform_enqueued_jobs { patch validar_siga_pago_path(@pago) }
    end

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ @a.director.email ], correo.to
    assert_equal "SIGA", correo[:from].display_names.first, "es de SIGA: le escribe a su cliente"
    assert_match(/Su suscripción a SIGA está activa hasta el #{I18n.l(Date.current + 1.month, format: :long)}/, correo.subject)
    assert_includes correo.text_part.body.to_s, @a.colegio.name
    assert_includes correo.text_part.body.to_s, "18.250,50 Bs"
  end

  # ⚠️ El correo se encola con el COLEGIO en su carga, aunque `/siga` no tenga
  # ninguno. El worker corre sin el aislamiento apagado: sin colegio, busca el
  # pago con el RLS puesto, no lo encuentra, y el correo no sale — sin que la
  # validación falle. El test de arriba no lo vería: ahí el trabajo corre dentro
  # de la misma petición, que ve todos los colegios.
  test "el correo viaja con el colegio del pago" do
    sign_in @fundador

    patch validar_siga_pago_path(@pago)

    trabajo = enqueued_jobs.find { |t| t["arguments"].first == "SuscripcionMailer" }
    assert trabajo, "no se encoló el correo al colegio"
    assert_equal @a.colegio.id, trabajo["school_id"]
  end

  # Es quien preguntará «¿quién nos activó, y cuándo?».
  test "queda en el historial DEL COLEGIO" do
    sign_in @fundador
    patch validar_siga_pago_path(@pago)

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.find_by(action: "suscripcion_pago_validado")
      assert rastro, "validar no dejó rastro en el colegio"
      assert_equal @fundador.id, rastro.user_id
      assert_match(/de SIGA, validó el pago/, rastro.message)
    end
    con_el_colegio(@b.colegio) { assert_not ActivityLog.exists?(action: "suscripcion_pago_validado") }
  end

  test "ya validado, sale de lo que espera y pasa a lo revisado" do
    sign_in @fundador
    patch validar_siga_pago_path(@pago)

    get siga_cartera_index_path

    assert_select ".siga-pago", 0
    assert_select "table.siga-tabla td", text: /18\.250,50 Bs · Pago Móvil o transferencia/
    assert_select ".siga-estado--activa", text: "Validado"
  end

  # Validar dos veces sumaría dos meses por un solo pago.
  test "un pago no se valida dos veces" do
    sign_in @fundador
    patch validar_siga_pago_path(@pago)

    patch validar_siga_pago_path(@pago)

    assert_match(/ya se revisó/, flash[:alert])
    assert_equal Date.current + 1.month, suscripcion_de(@a.colegio).vigente_hasta
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Rechazar
  # ══════════════════════════════════════════════════════════════════════════

  test "rechazar pide el motivo" do
    sign_in @fundador

    patch rechazar_siga_pago_path(@pago), params: { motivo: "   " }

    assert_match(/Falta el motivo del rechazo/, flash[:alert])
    Current.sin_aislamiento { assert @pago.reload.en_revision? }
  end

  test "con motivo, queda rechazado y el colegio sigue como estaba" do
    sign_in @fundador

    patch rechazar_siga_pago_path(@pago), params: { motivo: "La referencia no aparece en el banco" }

    assert_redirected_to siga_cartera_index_path
    Current.sin_aislamiento do
      assert @pago.reload.rechazado?
      assert_equal "La referencia no aparece en el banco", @pago.motivo
      assert_equal @fundador, @pago.revisado_por
    end
    assert suscripcion_de(@a.colegio).gratis?
  end

  test "el motivo le llega por correo a quien reportó" do
    sign_in @fundador

    assert_emails 1 do
      perform_enqueued_jobs do
        patch rechazar_siga_pago_path(@pago), params: { motivo: "La referencia no aparece en el banco" }
      end
    end

    correo = ActionMailer::Base.deliveries.last
    assert_equal [ @a.director.email ], correo.to
    assert_equal "No pudimos validar el pago de su suscripción a SIGA", correo.subject
    assert_includes correo.text_part.body.to_s, "La referencia no aparece en el banco"
    assert_includes correo.text_part.body.to_s, suscripcion_path, "lleva a donde se reporta de nuevo"
    assert_includes correo.text_part.body.to_s, "https://wa.me/584141234567"
  end

  test "y lo lee en su pantalla" do
    sign_in @fundador
    patch rechazar_siga_pago_path(@pago), params: { motivo: "La referencia no aparece en el banco" }
    sign_out @fundador

    sign_in @a.director
    get suscripcion_path

    assert_select ".suscripcion-rechazo", text: /La referencia no aparece en el banco/
  end

  test "el rechazo también queda en el historial del colegio" do
    sign_in @fundador
    patch rechazar_siga_pago_path(@pago), params: { motivo: "El monto no coincide" }

    con_el_colegio(@a.colegio) do
      assert_match(/rechazó el pago de la suscripción: El monto no coincide/,
                   ActivityLog.find_by(action: "suscripcion_pago_rechazado").message)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién puede
  # ══════════════════════════════════════════════════════════════════════════

  test "operaciones no valida ni rechaza" do
    sign_in @operaciones

    patch validar_siga_pago_path(@pago)
    assert_match(/lo hace el fundador/, flash[:alert])

    patch rechazar_siga_pago_path(@pago), params: { motivo: "No aparece" }
    assert_match(/lo hace el fundador/, flash[:alert])

    Current.sin_aislamiento { assert @pago.reload.en_revision? }
    assert suscripcion_de(@a.colegio).gratis?
  end

  # ⚠️ El colegio que reportó no puede validarse a sí mismo: `/siga` no es su
  # panel, y un director rebota en la puerta.
  test "el director del colegio no puede validar su propio pago" do
    sign_in @a.director

    patch validar_siga_pago_path(@pago)

    assert_redirected_to root_path
    Current.sin_aislamiento { assert @pago.reload.en_revision? }
    assert suscripcion_de(@a.colegio).gratis?
  end

  # ── El rodeo sin terminal ─────────────────────────────────────────────────
  #
  # Un pago en efectivo que el colegio no reportó, o un mes de cortesía: el
  # fundador entra al colegio, lo reporta por él y lo valida. Es lo que dice
  # `docs/tareas-de-operacion.md`, y por eso tiene que funcionar.
  test "el fundador, visitando un colegio, reporta un pago por él y después lo valida" do
    sign_in @fundador
    post siga_visitas_path, params: { school_id: @b.colegio.id }

    assert_difference -> { cantidad(SubscriptionPayment) }, 1 do
      post suscripcion_pagos_path,
           params: { subscription_payment: { medio: "efectivo", monto: "45.24", pagado_el: Date.current.to_s } }
    end
    pago = Current.sin_aislamiento { SubscriptionPayment.order(:id).last }
    assert_equal @b.colegio.id, pago.school_id, "el pago es del colegio visitado, no de otro"

    patch validar_siga_pago_path(pago)

    assert suscripcion_de(@b.colegio).activa?
    assert suscripcion_de(@b.colegio).por_alumno?
    assert suscripcion_de(@a.colegio).gratis?
  end

  # ⚠️ `cartera#update` no tiene pantalla, y por eso mismo estaba abierta a todo
  # el equipo de SIGA: una petición armada a mano le cambiaba el plan o el
  # vencimiento a cualquier colegio.
  test "operaciones tampoco toca una suscripción por la puerta sin pantalla" do
    sign_in @operaciones
    suscripcion = suscripcion_de(@a.colegio)

    patch siga_cartera_path(suscripcion), params: { subscription: { plan: "por_alumno", status: "activa" } }

    assert_match(/lo hace el fundador/, flash[:alert])
    assert suscripcion_de(@a.colegio).gratis?
  end
end
