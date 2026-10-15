require "test_helper"

# Lo que un colegio dice que le pagó a SIGA (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.5).
#
#     en_revision  ──►  validado    la suscripción queda activa un mes
#                  └─►  rechazado   con su motivo
#
# Acá va lo que el REPORTE exige. Qué le hace una validación a la suscripción
# —desde cuándo cuenta el mes, a qué precio— está en `validar_un_pago_test`.
class SubscriptionPaymentTest < ActiveSupport::TestCase
  include CobroDeLaSuscripcion

  setup do
    @a, @b = dos_colegios_completos(suscripcion: :gratis)
  end

  # ── La cotización se congela al reportar ──────────────────────────────────

  # El colegio de prueba tiene dos alumnos: le toca el mínimo.
  test "el reporte guarda la cuenta con que se hizo" do
    pago = pago_reportado(@a)

    assert_equal 2, pago.alumnos
    assert_equal Subscription::PRECIO_POR_ALUMNO, pago.precio_por_alumno
    assert_equal Subscription::MINIMO_MENSUAL, pago.minimo_mensual
    assert_equal Subscription::MINIMO_MENSUAL, pago.precio_mensual
    assert_equal BigDecimal("39"), pago.cotizacion.monto
    # El precio es final: el reporte no guarda ningún IVA aparte (decisión 28).
    assert_not_includes SubscriptionPayment.column_names, "iva"
  end

  # ⚠️ Es lo que el colegio vio en su pantalla y lo que pagó. Si el precio sube
  # entre que reporta y que se valida, su pago sigue siendo por lo que se le dijo.
  test "y no cambia aunque después suba el precio" do
    pago = pago_reportado(@a)

    stub_const(Subscription, :PRECIO_POR_ALUMNO, BigDecimal("0.90")) do
      stub_const(Subscription, :MINIMO_MENSUAL, BigDecimal("99")) do
        con_el_colegio(@a.colegio) do
          assert_equal BigDecimal("39"), pago.reload.cotizacion.monto
        end
      end
    end
  end

  # ── La unidad la da el medio ──────────────────────────────────────────────

  test "Pago Móvil va en bolívares; Binance, PayPal y efectivo, en dólares" do
    assert_equal "Bs", SubscriptionPayment.new(medio: "pago_movil").unidad
    assert_equal "$",  SubscriptionPayment.new(medio: "binance").unidad
    assert_equal "$",  SubscriptionPayment.new(medio: "paypal").unidad
    assert_equal "$",  SubscriptionPayment.new(medio: "efectivo").unidad
  end

  # Zelle no (decisión 9), ni ningún otro: un medio que SIGA no ofrece no tiene
  # a dónde pagarse.
  test "no admite un medio que no existe" do
    pago = nuevo(medio: "zelle")

    assert_not pago.valid?
    assert pago.errors[:medio].any?
  end

  # ── La referencia ─────────────────────────────────────────────────────────

  test "la referencia hace falta, salvo en efectivo" do
    assert nuevo(medio: "pago_movil", referencia: nil).errors[:referencia].any?
    assert nuevo(medio: "binance", referencia: " ").errors[:referencia].any?
    assert nuevo(medio: "paypal", referencia: nil).errors[:referencia].any?
    assert_empty nuevo(medio: "efectivo", referencia: nil).errors[:referencia]
  end

  # «0012 3456» y «00123456» son el mismo pago: sin normalizar, el índice único
  # no impide reportarlo dos veces.
  test "la referencia se guarda sin espacios ni puntos, en mayúscula" do
    assert_equal "0012-3456AB", nuevo(referencia: " 0012-3456.ab ").referencia
  end

  test "una referencia de dos caracteres no es una referencia" do
    assert nuevo(referencia: "12").errors[:referencia].any?
  end

  test "la misma referencia no se reporta dos veces" do
    anterior = pago_reportado(@a, referencia: "0012345678")
    con_el_colegio(@a.colegio) { anterior.update!(estado: "validado") }

    assert_includes nuevo(referencia: "0012345678").errors[:referencia], "ya se reportó en otro pago"
  end

  # ⚠️ Un rechazo por un monto mal escrito deja la referencia buena, y el
  # colegio tiene que poder volver a reportarla. Con la unicidad a secas quedaba
  # en un callejón: el mismo que tuvieron los pagos de la familia.
  test "salvo que la anterior se haya rechazado" do
    anterior = pago_reportado(@a, referencia: "0012345678")
    con_el_colegio(@a.colegio) { anterior.rechazar!(por: @a.director, motivo: "El monto no coincide") }

    de_nuevo = pago_reportado(@a, referencia: "0012345678")

    assert de_nuevo.persisted?
  end

  # Dos bancos distintos emiten el mismo número todo el tiempo.
  test "y otro colegio sí puede usar ese número" do
    pago_reportado(@a, referencia: "0012345678")

    assert pago_reportado(@b, referencia: "0012345678").persisted?
  end

  # ── El comprobante ────────────────────────────────────────────────────────

  test "el comprobante hace falta, salvo en efectivo" do
    assert nuevo(medio: "pago_movil", con_comprobante: false).errors[:comprobante].any?
    assert_empty nuevo(medio: "efectivo", referencia: nil, con_comprobante: false).errors[:comprobante]
  end

  # Un `.docx` no se puede comparar con el banco.
  test "y tiene que ser una foto o un PDF" do
    pago = nuevo(con_comprobante: false)
    pago.comprobante.attach(io: StringIO.new("no soy una imagen"), filename: "pago.docx",
                            content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    pago.valid?

    assert_includes pago.errors[:comprobante], "tiene que ser una foto o un PDF"
  end

  # ── La fecha y el monto ───────────────────────────────────────────────────

  test "la fecha del pago no puede ser de mañana ni de hace más de un mes" do
    assert nuevo(pagado_el: Date.current + 1).errors[:pagado_el].any?
    assert nuevo(pagado_el: Date.current - 40).errors[:pagado_el].any?
    assert_empty nuevo(pagado_el: Date.current - 20).errors[:pagado_el]
  end

  test "el monto tiene que ser más que cero" do
    assert nuevo(monto: 0).errors[:monto].any?
    assert nuevo(monto: nil).errors[:monto].any?
  end

  # ── Uno en revisión a la vez ──────────────────────────────────────────────

  test "con un pago en revisión, no se reporta otro" do
    pago_reportado(@a)

    # ⚠️ Se miran los errores que dejó `nuevo`, sin volver a preguntar `valid?`
    # aquí afuera: sin colegio en contexto el RLS devuelve cero filas, y la
    # validación —que busca el otro reporte— no encontraría nada.
    otro = nuevo(referencia: "OTRA-0001")

    assert_match(/Ya hay un pago esperando validación/, otro.errors[:base].first.to_s)
  end

  # ⚠️ La base lo sostiene aunque el modelo no llegue a mirar: dos personas de
  # la oficina reportando el mismo pago a la vez pasan las dos la validación.
  test "y la base tampoco deja pasar el segundo" do
    pago_reportado(@a)
    otro = nuevo(referencia: "OTRA-0002")

    assert_raises(ActiveRecord::RecordNotUnique) do
      con_el_colegio(@a.colegio) { SubscriptionPayment.transaction(requires_new: true) { otro.save!(validate: false) } }
    end
  end

  test "resuelto el primero, sí" do
    primero = pago_reportado(@a)
    con_el_colegio(@a.colegio) { primero.rechazar!(por: @a.director, motivo: "No aparece en el banco") }

    assert pago_reportado(@a).persisted?
  end

  # ── Rechazar ──────────────────────────────────────────────────────────────

  # Un rechazo sin explicación deja al colegio reportando lo mismo otra vez.
  test "no se rechaza sin decir por qué" do
    pago = pago_reportado(@a)

    con_el_colegio(@a.colegio) do
      assert_raises(ActiveRecord::RecordInvalid) { pago.rechazar!(por: @a.director, motivo: "  ") }
      assert pago.reload.en_revision?
    end
  end

  test "retirar se puede solo mientras nadie lo ha mirado" do
    pago = pago_reportado(@a)
    assert pago.se_puede_retirar?

    con_el_colegio(@a.colegio) { pago.rechazar!(por: @a.director, motivo: "No aparece") }
    assert_not pago.se_puede_retirar?
  end

  # ── El aislamiento ────────────────────────────────────────────────────────

  test "un colegio no ve los pagos de otro" do
    pago_reportado(@a)

    con_el_colegio(@b.colegio) { assert_equal 0, SubscriptionPayment.count }
    con_el_colegio(@a.colegio) { assert_equal 1, SubscriptionPayment.count }
  end

  private

  # Un pago sin guardar, ya validado, para mirarle los errores.
  def nuevo(con_comprobante: true, **datos)
    con_el_colegio(@a.colegio) do
      pago = SubscriptionPayment.nuevo_para(Subscription.find_by!(school_id: @a.colegio.id), por: @a.director,
                                            **{ medio: "pago_movil", monto: 50_000, referencia: "REF-00001",
                                                pagado_el: Date.current }.merge(datos))
      if con_comprobante
        pago.comprobante.attach(io: File.open(IMAGEN_DE_PRUEBA), filename: "comprobante.png", content_type: "image/png")
      end
      pago.valid?
      pago
    end
  end
end
