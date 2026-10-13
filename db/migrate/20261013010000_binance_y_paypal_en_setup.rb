# PayPal entra como medio de pago, y Binance y PayPal pasan a ser «variables»
# de `setup` (spec `docs/specs/del-registro-al-cobro.md`, decisión 36).
#
# Daniel, 12 de octubre de 2026: *«Hay que agregar una variable para los
# valores de Binance y Paypal»*.
#
#     setup
#     nombre              valor
#     whatsapp            …
#     url_de_la_muestra   …
#     binance             el ID o el correo de Binance Pay   ← venía de siga_settings
#     paypal              el correo de PayPal                ← nuevo
#
# ## Por qué en `setup` y no en `siga_settings`
#
# Un medio de UN dato es una variable: Binance y PayPal son un correo o un ID, y
# no se validan con nada. En `siga_settings` se quedan los dos medios que
# comparten titular y cédula —Pago Móvil y transferencia— y que por eso se
# validan juntos.
#
# ⚠️ Binance se MUDA, no se copia, como el WhatsApp en `LosAjustesEnSetup`: dos
# lugares para la misma cuenta son dos cuentas el día que alguien cambie una.
#
# ## Y el reporte de un pago admite `paypal`
#
# `subscription_payments.medio` tiene un CHECK con los medios que existen.
class BinanceYPaypalEnSetup < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO setup (nombre, valor, actualizado_por_id, created_at, updated_at)
      SELECT 'binance', binance, actualizado_por_id, updated_at, updated_at
      FROM siga_settings
      WHERE binance IS NOT NULL AND binance <> ''
      LIMIT 1
    SQL

    remove_column :siga_settings, :binance

    remove_check_constraint :subscription_payments, name: "subscription_payments_medio_valido"
    add_check_constraint :subscription_payments,
                         "medio IN ('pago_movil', 'binance', 'paypal', 'efectivo')",
                         name: "subscription_payments_medio_valido"
  end

  def down
    # ⚠️ `subscription_payments` lleva RLS: sin el bypass, el DELETE no ve
    # ninguna fila, no avisa, y el CHECK de abajo revienta contra ellas.
    execute "SET LOCAL siga.bypass_rls = 'on'"

    # Un reporte por PayPal no tiene a dónde volver: el medio no existía.
    execute "DELETE FROM subscription_payments WHERE medio = 'paypal'"
    remove_check_constraint :subscription_payments, name: "subscription_payments_medio_valido"
    add_check_constraint :subscription_payments,
                         "medio IN ('pago_movil', 'binance', 'efectivo')",
                         name: "subscription_payments_medio_valido"

    add_column :siga_settings, :binance, :string
    execute <<~SQL
      UPDATE siga_settings
      SET binance = (SELECT valor FROM setup WHERE nombre = 'binance')
    SQL
    execute "DELETE FROM setup WHERE nombre IN ('binance', 'paypal')"
  end
end
