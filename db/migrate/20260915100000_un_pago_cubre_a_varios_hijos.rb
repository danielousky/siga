# Un pago es del REPRESENTANTE, no de un hijo (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«yo tengo dos hijos, uno en el liceo y otro en primaria, y cuando
# hago un pago no hago un pago para uno y un pago para el otro. Hago el pago de
# los dos… eso es lo natural»*.
#
#     ANTES  un reporte → UNA inscripción      dos hijos = dos transferencias
#     AHORA  un reporte → las CUOTAS que paga  una transferencia, los dos hijos
#
# ## ⚠️ De quién es el reporte, entonces
#
# Del representante. A qué hijos alcanza sale de sus CUOTAS, que ya saben su
# inscripción: no hace falta que el reporte lo repita, y repetirlo era lo que
# obligaba a partir un pago en dos.
#
# Y por eso el colegio se deriva del REPRESENTANTE y no de la inscripción: sin
# `enrollment_id` no habría de dónde sacarlo, y el representante es de un
# colegio por definición.
#
# ⚠️ La columna se BORRA en vez de quedarse nullable. Una columna que nadie
# escribe es una que alguien va a leer: el día que un reporte cubra a dos hijos,
# `reporte.enrollment` diría uno de los dos y nadie sabría por qué.
class UnPagoCubreAVariosHijos < ActiveRecord::Migration[8.1]
  def up
    # Lo que ya existe no se pierde: su inscripción ya está en sus cuotas.
    remove_index :payment_reports, column: [ :enrollment_id, :created_at ]
    remove_column :payment_reports, :enrollment_id
  end

  def down
    add_reference :payment_reports, :enrollment, foreign_key: true
    add_index :payment_reports, [ :enrollment_id, :created_at ]
  end
end
