require "test_helper"

# Los ajustes de la plataforma: el WhatsApp de SIGA y los datos para pagarle
# (spec `docs/specs/del-registro-al-cobro.md`, decisiones 20 a 22).
class SigaSettingTest < ActiveSupport::TestCase
  include CobroDeLaSuscripcion

  # ── Un medio sin sus datos completos no se ofrece ─────────────────────────
  #
  # Un Pago Móvil sin cédula o un Binance sin ID no se pueden pagar, y
  # ofrecerlos deja al colegio con el teléfono en la mano y sin a dónde mandar
  # el dinero.

  test "con todo cargado se ofrecen los tres medios" do
    assert_equal %w[pago_movil binance efectivo], cargar_los_ajustes_de_siga.medios
  end

  test "sin nada cargado no se ofrece ninguno" do
    assert_empty SigaSetting.new.medios
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

  # ── Los datos se guardan en UNA forma ─────────────────────────────────────

  test "los teléfonos se guardan con su guion, como los escribe el campo" do
    ajustes = cargar_los_ajustes_de_siga(whatsapp: "0414 123 45 67", pago_movil_telefono: "04247654321")

    assert_equal "0414-1234567", ajustes.whatsapp
    assert_equal "0424-7654321", ajustes.pago_movil_telefono
  end

  # ⚠️ «58» + «0414…» es un número que no existe, y WhatsApp abre igual con un
  # chat hacia nadie: al número se le quita el cero antes del país.
  test "el enlace de WhatsApp lleva el país y no lleva el cero" do
    url = cargar_los_ajustes_de_siga(whatsapp: "0414-1234567").whatsapp_url("Hola")

    assert_equal "https://wa.me/584141234567?text=Hola", url
  end

  test "un fijo no sirve de WhatsApp ni de Pago Móvil" do
    ajustes = SigaSetting.new(whatsapp: "0212-5551234", pago_movil_telefono: "0212-5551234")

    assert_not ajustes.valid?
    assert ajustes.errors[:whatsapp].any?
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

  # Dos filas de ajustes son dos números de WhatsApp, y nadie sabe cuál está en
  # la portada.
  test "la base no admite una segunda fila de ajustes" do
    cargar_los_ajustes_de_siga

    assert_raises(ActiveRecord::RecordNotUnique) do
      SigaSetting.transaction(requires_new: true) { SigaSetting.create!(whatsapp: "0416-0000000") }
    end
  end

  # ── De dónde sale el WhatsApp mientras nadie lo guardó ────────────────────

  # ⚠️ La variable `SIGA_WHATSAPP` sirve de valor INICIAL: si está puesta en
  # producción, el botón no desaparece el día en que el número pasa a la base.
  test "sin ajustes guardados, el WhatsApp es el de la variable de entorno" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_equal "0424-1234567", SigaSetting.actuales.whatsapp
      assert_not SigaSetting.actuales.persisted?, "leer los ajustes no puede escribir en la base"
    end
  end

  test "y con ajustes guardados manda la base" do
    cargar_los_ajustes_de_siga(whatsapp: "0416-1112233")

    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_equal "0416-1112233", SigaSetting.actuales.whatsapp
    end
  end

  # Quien apagó el WhatsApp a propósito no lo ve volver por la variable.
  test "tampoco vuelve la variable si el número se dejó en blanco a propósito" do
    cargar_los_ajustes_de_siga(whatsapp: nil)

    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_nil SigaSetting.actuales.whatsapp
    end
  end

  test "una variable que no es un celular venezolano no se usa" do
    con_la_variable("SIGA_WHATSAPP", "12125551234") do
      assert_nil SigaSetting.actuales.whatsapp
    end
  end
end
