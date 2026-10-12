require "test_helper"

# Lo que le hace a la suscripción un pago validado (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.6 y 5.7).
#
#     AL VALIDAR, ¿DESDE CUÁNDO CUENTA EL MES?
#     primer pago              desde el día que se valida
#     pago a tiempo            desde el día que vencía         sin huecos ni días encimados
#     pago en la gracia        desde el día que VENCIÓ         los días de gracia se pagan
#     pago en solo lectura     desde el día que se VALIDA      lo de solo lectura no se cobra
#
# Sin la tercera fila, un colegio que paga siempre el día 14 de la gracia usaría
# casi cuatro meses gratis al año.
class ValidarUnPagoTest < ActiveSupport::TestCase
  include CobroDeLaSuscripcion

  HOY = Date.new(2026, 10, 20)

  setup do
    travel_to Time.utc(2026, 10, 20, 15)
    @a, _b = dos_colegios_completos(suscripcion: :gratis)
    @fundador = equipo_de_siga
  end

  # ── El primer pago ────────────────────────────────────────────────────────

  test "el primer pago activa un mes desde el día en que se valida" do
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert suscripcion.por_alumno?, "validar el pago saca al colegio de lo gratis"
    assert suscripcion.activa?
    assert_equal HOY, suscripcion.vigente_desde
    assert_equal Date.new(2026, 11, 20), suscripcion.vigente_hasta
  end

  # El colegio de prueba tiene dos alumnos: le toca el mínimo.
  test "y le congela el precio con que reportó" do
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert_equal Subscription::PRECIO_POR_ALUMNO, suscripcion.precio_por_alumno
    assert_equal Subscription::MINIMO_MENSUAL, suscripcion.minimo_mensual
    assert_equal BigDecimal("39"), suscripcion.precio_mensual
    assert_equal 2, suscripcion.matricula_facturada
  end

  # ⚠️ Decisión 17: el que entra a 0,30 sigue a 0,30. Si el precio sube entre
  # que el colegio reporta y que se valida, vale el que vio.
  test "aunque el precio haya subido antes de validarlo" do
    pago = pago_reportado(@a)

    stub_const(Subscription, :PRECIO_POR_ALUMNO, BigDecimal("0.90")) do
      stub_const(Subscription, :MINIMO_MENSUAL, BigDecimal("99")) { validar(pago) }
    end

    suscripcion = suscripcion_de(@a.colegio)
    assert_equal BigDecimal("0.30"), suscripcion.precio_por_alumno
    assert_equal BigDecimal("39"), suscripcion.precio_mensual
  end

  test "el pago queda validado, con quién lo miró y qué mes cubre" do
    pago = pago_reportado(@a)

    validar(pago)

    Current.sin_aislamiento do
      pago.reload
      assert pago.validado?
      assert_equal @fundador, pago.revisado_por
      assert_equal HOY, pago.cubre_desde
      assert_equal Date.new(2026, 11, 20), pago.cubre_hasta
    end
  end

  # ── La renovación ─────────────────────────────────────────────────────────

  test "un pago a tiempo cuenta desde el día que vencía, no desde hoy" do
    pagando(vence: Date.new(2026, 10, 23))
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert_equal Date.new(2026, 10, 23), suscripcion.vigente_desde
    assert_equal Date.new(2026, 11, 23), suscripcion.vigente_hasta, "pagar tres días antes no regala ni quita días"
  end

  # ⚠️ Los días de gracia se PAGAN: pagar tarde no regala nada.
  test "un pago en la gracia cuenta desde el día que venció" do
    pagando(vence: Date.new(2026, 10, 10), estado: :en_gracia)
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert suscripcion.activa?
    assert_equal Date.new(2026, 10, 10), suscripcion.vigente_desde
    assert_equal Date.new(2026, 11, 10), suscripcion.vigente_hasta
  end

  # Lo de solo lectura no se cobra: no queda deuda que perseguir.
  test "un pago ya en solo lectura cuenta desde que se valida" do
    pagando(vence: Date.new(2026, 9, 20), estado: :vencida)
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert suscripcion.activa?
    assert_equal HOY, suscripcion.vigente_desde
    assert_equal Date.new(2026, 11, 20), suscripcion.vigente_hasta
  end

  # ⚠️ Lo tarde se mide por cuándo REPORTÓ. El colegio pagó el día 13 de la
  # gracia; que se valide cuando la gracia ya pasó es demora nuestra, y no
  # puede moverle el mes.
  test "lo tarde se mide por el día del reporte, no por el de la validación" do
    pagando(vence: Date.new(2026, 10, 1), estado: :en_gracia)
    pago = pago_reportado(@a, reportado_el: Date.new(2026, 10, 14))

    validar(pago)   # el 20: la gracia terminó el 16

    assert_equal Date.new(2026, 10, 1), suscripcion_de(@a.colegio).vigente_desde
  end

  # La cuenta que justifica la regla: tres pagos seguidos el día 14 de la
  # gracia mueven el vencimiento exactamente tres meses, ni un día más.
  test "quien paga siempre al final de la gracia no gana días" do
    pagando(vence: Date.new(2026, 7, 1))

    [ Date.new(2026, 7, 15), Date.new(2026, 8, 15), Date.new(2026, 9, 15) ].each do |dia|
      travel_to dia.to_time(:utc).change(hour: 15)
      Current.sin_aislamiento { suscripcion_de(@a.colegio).actualizar_estado! }
      validar(pago_reportado(@a))
    end

    assert_equal Date.new(2026, 10, 1), suscripcion_de(@a.colegio).vigente_hasta
  end

  # ⚠️ El precio con que entró sigue siendo el suyo al renovar.
  test "al renovar conserva su precio, aunque el de hoy sea otro" do
    pagando(vence: Date.new(2026, 10, 23), por_alumno: BigDecimal("0.25"), minimo: BigDecimal("30"))
    pago = pago_reportado(@a)

    validar(pago)

    suscripcion = suscripcion_de(@a.colegio)
    assert_equal BigDecimal("0.25"), suscripcion.precio_por_alumno
    assert_equal BigDecimal("30"), suscripcion.minimo_mensual
    assert_equal BigDecimal("30"), suscripcion.precio_mensual
  end

  # ── Lo que ya se revisó no se vuelve a decidir ────────────────────────────

  # Validar dos veces sumaría dos meses por un solo pago.
  test "un pago no se valida dos veces" do
    pago = pago_reportado(@a)
    validar(pago)

    assert_raises(SubscriptionPayment::YaRevisado) { validar(pago) }
    assert_equal Date.new(2026, 11, 20), suscripcion_de(@a.colegio).vigente_hasta
  end

  test "ni se rechaza uno que ya se validó" do
    pago = pago_reportado(@a)
    validar(pago)

    assert_raises(SubscriptionPayment::YaRevisado) do
      Current.sin_aislamiento { pago.rechazar!(por: @fundador, motivo: "Me equivoqué") }
    end
    assert suscripcion_de(@a.colegio).activa?
  end

  test "rechazar no toca la suscripción" do
    pago = pago_reportado(@a)

    Current.sin_aislamiento { pago.rechazar!(por: @fundador, motivo: "La referencia no aparece en el banco") }

    assert suscripcion_de(@a.colegio).gratis?
    Current.sin_aislamiento { assert_equal "La referencia no aparece en el banco", pago.reload.motivo }
  end

  # ── Nada baja mientras un pago espera ─────────────────────────────────────

  # ⚠️ El colegio que pagó a tiempo no puede quedar en solo lectura porque
  # nadie alcanzó a mirar el comprobante: la demora sería nuestra y el
  # castigo, suyo.
  test "con un pago en revisión, la suscripción no baja de estado" do
    pagando(vence: Date.new(2026, 9, 20))   # venció hace un mes: sin el pago, solo lectura
    pago_reportado(@a)

    Subscription.actualizar_todas!

    assert suscripcion_de(@a.colegio).activa?
  end

  test "sin pago en revisión, baja como siempre" do
    pagando(vence: Date.new(2026, 9, 20))

    Subscription.actualizar_todas!

    assert suscripcion_de(@a.colegio).vencida?
  end

  test "y si el pago se rechaza, vuelve a bajar" do
    pagando(vence: Date.new(2026, 9, 20))
    pago = pago_reportado(@a)
    Current.sin_aislamiento { pago.rechazar!(por: @fundador, motivo: "No aparece") }

    Subscription.actualizar_todas!

    assert suscripcion_de(@a.colegio).vencida?
  end

  # Lo que no se permite es caer; subir, sí.
  test "pero con un pago en revisión sí sube" do
    pagando(vence: Date.new(2026, 11, 20), estado: :vencida)
    pago_reportado(@a)

    Subscription.actualizar_todas!

    assert suscripcion_de(@a.colegio).activa?
  end

  # ── Lo que la pantalla le pregunta ────────────────────────────────────────

  test "cinco días antes de vencer está «por vencer», y seis no" do
    pagando(vence: HOY + 5)
    assert suscripcion_de(@a.colegio).por_vencer?

    pagando(vence: HOY + 6)
    assert_not suscripcion_de(@a.colegio).por_vencer?
  end

  test "en la gracia dice cuántos días le quedan" do
    pagando(vence: HOY - 3, estado: :en_gracia)

    assert_equal 12, suscripcion_de(@a.colegio).dias_de_gracia_restantes
  end

  private

  # Como lo hace `/siga`: sin colegio, con el aislamiento apagado.
  def validar(pago)
    Current.sin_aislamiento { SubscriptionPayment.find(pago.id).validar!(por: @fundador) }
  end

  # Deja al colegio con su suscripción paga, venciendo el día que se diga.
  def pagando(vence:, estado: :activa, por_alumno: Subscription::PRECIO_POR_ALUMNO, minimo: Subscription::MINIMO_MENSUAL)
    Current.sin_aislamiento do
      suscripcion_de(@a.colegio).update!(plan: :por_alumno, status: estado,
                                         precio_por_alumno: por_alumno, minimo_mensual: minimo,
                                         precio_mensual: minimo, vigente_desde: vence - 1.month, vigente_hasta: vence)
    end
  end
end
