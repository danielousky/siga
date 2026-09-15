# Que un reporte rechazado se pueda validar después (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«un "rechazado", pudiera ser validado nuevamente, ¿tiene sentido?»*.
# Sí, y hay una razón más fuerte que la comodidad: hoy es un CALLEJÓN SIN SALIDA.
#
#     la oficina rechaza por error (leyó mal el banco, se equivocó de fila)
#        └─► la familia no puede volver a reportar: la referencia es ÚNICA por
#            colegio, así que el mismo número lo rechaza la validación
#        └─► y el reporte rechazado no se puede validar porque al rechazarlo se
#            soltaron sus cobros y ya no se sabe cuáles eran
#
# La única salida era inventarse una referencia falsa, que es corromper el dato
# que existe para cuadrar con el banco.
#
# ## ⚠️ Por qué una columna y no volver a leer el enlace
#
# `charges.payment_report_id` es el enlace VIVO, y rechazar lo suelta a
# propósito: la familia tiene que poder reportar esas cuotas de nuevo. Pero al
# soltarlo se pierde QUÉ decía pagar el reporte — y eso no es estado, es
# historia: la oficina que mira un rechazado tiene derecho a ver de qué era.
#
# Se guarda al crearlo y no se toca nunca más.
class UnReporteRecuerdaQueCobrosDijoPagar < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_reports, :cobros_declarados, :jsonb, null: false, default: []

    # ⚠️ Los que ya existen se rellenan de su enlace vivo. Los rechazados de
    # antes quedan con la lista vacía y no se pueden revalidar: su información
    # se perdió cuando se rechazaron, y inventarla sería peor.
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE payment_reports SET cobros_declarados = coalesce(
            (SELECT jsonb_agg(charges.id) FROM charges
              WHERE charges.payment_report_id = payment_reports.id), '[]'::jsonb)
        SQL
      end
    end
  end
end
