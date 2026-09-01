# Cuántas materias puede arrastrar un alumno al año siguiente (MOR-169).
#
# ## Por qué es del colegio y no una constante
#
# La regla venezolana de referencia son **dos** materias pendientes, y en el
# último año ninguna —no se puede egresar debiendo—. Pero los mecanismos los
# fijan circulares del MPPE que cambian, y en primaria la norma es menos clara
# que en bachillerato.
#
# Decisión de Daniel: *«que lo configure cada colegio... 2 y configurable. Si hay
# algún cambio ajustaremos»*. SIGA propone el número correcto y el colegio lo
# corrige sin esperar un despliegue.
#
# ⚠️ El valor por defecto es **2**, no cero. Un `NOT NULL` sin default dejaría a
# los colegios que ya existen sin regla, y la promoción los tomaría como «cero
# arrastres» — o sea, mandaría a repetir a todo el que aplazó una materia.
class AgregarTopeDeArrastreALosColegios < ActiveRecord::Migration[8.1]
  def change
    add_column :schools, :tope_de_arrastre, :integer, null: false, default: 2
  end
end
