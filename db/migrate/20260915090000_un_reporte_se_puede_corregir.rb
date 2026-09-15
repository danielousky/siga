# Que la familia pueda corregir su propio reporte (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«el error humano es posible, entonces deben poder corregir»* — y lo
# dijo de las DOS partes. La de finanzas ya estaba (revertir una validación,
# revalidar un rechazo); a la familia no le quedaba ninguna salida.
#
#     la madre copia la referencia del SMS del banco y baila dos dígitos
#        └─► no puede editar el reporte
#        └─► no puede retirarlo
#        └─► no puede volver a reportar: la referencia es única por colegio
#        └─► solo le queda esperar a que se lo RECHACEN para volver a empezar
#
# ## ⚠️ Y hace falta que la oficina vea que se corrigió
#
# El caso que muerde no es que la familia se equivoque: es que la oficina abra
# el reporte, se vaya al estado de cuenta del banco a buscar «0098-7745», y
# mientras tanto la familia lo cambie a «0098-7754». Vuelve, valida, y validó
# unos números que nunca leyó.
#
# Una marca de cuándo se tocó por última vez no lo impide —nada lo impide— pero
# lo hace VISIBLE, que es lo que permite que alguien lo note.
class UnReporteSePuedeCorregir < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_reports, :corregido_el, :datetime
  end
end
