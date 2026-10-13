# Qué aviso de la escalera ya recibió un colegio (spec
# `docs/specs/del-registro-al-cobro.md`, § 5.7).
#
#     5 días antes       «su suscripción vence el 9 de noviembre»
#     al vencer          «venció; le quedan 15 días»
#     pasados 15 días    «su colegio quedó en solo lectura»
#
# Los manda un trabajo que corre todos los días, y cada uno sale UNA vez. Para
# eso hace falta acordarse de cuál fue el último, y de qué vencimiento era:
#
#     aviso_enviado           0 ninguno · 1 por vencer · 2 venció · 3 solo lectura
#     aviso_del_vencimiento   la fecha `vigente_hasta` a la que pertenece
#
# ⚠️ La fecha es lo que REINICIA la cuenta sin que nadie la toque: al validarse
# un pago cambia `vigente_hasta`, y un aviso anotado para el vencimiento
# anterior deja de contar. Con el número solo, habría que acordarse de ponerlo
# en cero en cada lugar que mueve el vencimiento —y el que se olvide deja a un
# colegio sin su aviso del mes siguiente—.
class LosAvisosDeLaEscalera < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :aviso_enviado, :integer, null: false, default: 0
    add_column :subscriptions, :aviso_del_vencimiento, :date

    add_check_constraint :subscriptions, "aviso_enviado IN (0, 1, 2, 3)",
                         name: "subscriptions_aviso_enviado_valido"
  end
end
