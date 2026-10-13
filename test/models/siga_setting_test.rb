require "test_helper"

# Cómo se le paga a SIGA (spec `docs/specs/del-registro-al-cobro.md`,
# decisiones 21, 22 y 36). Pago Móvil y transferencia viven aquí; el WhatsApp,
# Binance y PayPal, en `Setup`: ver `setup_test`.
class SigaSettingTest < ActiveSupport::TestCase
  include CobroDeLaSuscripcion

  # ── Un medio sin sus datos completos no se ofrece ─────────────────────────
  #
  # Un Pago Móvil sin cédula o un Binance sin ID no se pueden pagar, y
  # ofrecerlos deja al colegio con el teléfono en la mano y sin a dónde mandar
  # el dinero.

  test "con todo cargado se ofrecen los cuatro medios" do
    assert_equal %w[pago_movil binance paypal efectivo], cargar_los_ajustes_de_siga.medios
  end

  test "sin nada cargado no se ofrece ninguno" do
    sin_medios_de_pago

    assert_empty SigaSetting.actuales.medios
  end

  test "al Pago Móvil le hacen falta el banco, el teléfono y la cédula" do
    assert cargar_los_ajustes_de_siga.pago_movil?
    assert_not cargar_los_ajustes_de_siga(pago_movil_banco: nil).pago_movil?
    assert_not cargar_los_ajustes_de_siga(pago_movil_telefono: nil).pago_movil?
    assert_not cargar_los_ajustes_de_siga(documento: nil).pago_movil?
  end

  test "a la transferencia, la cuenta, el titular y la cédula" do
    assert cargar_los_ajustes_de_siga.transferencia?
    assert_not cargar_los_ajustes_de_siga(cuenta: nil).transferencia?
    assert_not cargar_los_ajustes_de_siga(titular: nil).transferencia?
  end

  # Para el colegio son el mismo medio: en bolívares, a la tasa BCV del día.
  test "con uno de los dos alcanza para ofrecer «Pago Móvil o transferencia»" do
    assert_includes cargar_los_ajustes_de_siga(cuenta: nil).medios, "pago_movil"
    assert_includes cargar_los_ajustes_de_siga(pago_movil_telefono: nil).medios, "pago_movil"
    assert_not_includes cargar_los_ajustes_de_siga(cuenta: nil, pago_movil_telefono: nil).medios, "pago_movil"
  end

  # El efectivo no tiene datos: se coordina por WhatsApp.
  test "sin WhatsApp no hay con quién coordinar el efectivo" do
    assert_not_includes cargar_los_ajustes_de_siga(whatsapp: nil).medios, "efectivo"
  end

  # Binance y PayPal son un dato cada uno: sin él, no se ofrecen.
  test "Binance y PayPal se ofrecen solo con su cuenta" do
    assert_not_includes cargar_los_ajustes_de_siga(binance: nil).medios, "binance"
    assert_not_includes cargar_los_ajustes_de_siga(paypal: nil).medios, "paypal"
  end

  # ⚠️ Y al revés: con WhatsApp hay efectivo aunque no haya NINGÚN dato para
  # pagar. El número vive en otra tabla, y vaciar esta no lo apaga.
  test "con WhatsApp hay efectivo, aunque no haya datos para pagar" do
    poner_el_whatsapp("0414-1234567")
    SigaSetting.delete_all

    assert_equal %w[efectivo], SigaSetting.actuales.medios
  end

  # ── Los datos se guardan en UNA forma ─────────────────────────────────────

  test "el teléfono del Pago Móvil se guarda con su guion, como lo escribe el campo" do
    assert_equal "0424-7654321", cargar_los_ajustes_de_siga(pago_movil_telefono: "04247654321").pago_movil_telefono
  end

  test "un fijo no sirve de Pago Móvil" do
    ajustes = SigaSetting.new(pago_movil_telefono: "0212-5551234")

    assert_not ajustes.valid?
    assert ajustes.errors[:pago_movil_telefono].any?
  end

  test "la cédula o el RIF se guardan en una sola forma" do
    assert_equal "V-12345678", SigaSetting.new(documento: "v 12.345.678").documento
    assert_equal "J-12345678-9", SigaSetting.new(documento: "j-12345678-9").documento
    assert SigaSetting.new(documento: "doce millones").invalid?
  end

  test "la cuenta son veinte dígitos, y dice su banco" do
    ajustes = SigaSetting.new(cuenta: "0102-0000-00-0000001234")

    assert_equal "01020000000000001234", ajustes.cuenta
    assert_equal "Banco de Venezuela", ajustes.banco_de_la_cuenta
    assert SigaSetting.new(cuenta: "0102123").invalid?
  end

  test "el banco del Pago Móvil sale de la lista" do
    assert SigaSetting.new(pago_movil_banco: "9999").invalid?
    assert SigaSetting.new(pago_movil_banco: "0134").valid?
  end

  # ── Una sola fila ─────────────────────────────────────────────────────────

  # Dos filas de ajustes son dos cuentas a donde pagar, y nadie sabe cuál ve el
  # colegio.
  test "la base no admite una segunda fila de ajustes" do
    cargar_los_ajustes_de_siga

    assert_raises(ActiveRecord::RecordNotUnique) do
      SigaSetting.transaction(requires_new: true) { SigaSetting.create!(titular: "Otra empresa") }
    end
  end
end
