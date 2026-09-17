# Un boletín emitido no lo ve la familia hasta que alguien lo revisa.
#
# Daniel: *«las boletas deberán pasar por una revisión por parte de Admin antes
# de ser mostradas al representante, por si algo no está bien. Una especie de
# vistazo final»*.
#
#     HOY      emitir = crear + descargar
#     AHORA    emitir ──► revisar ──► liberar ──► la familia lo ve
#
# ## ⚠️ Emitir y liberar son dos hechos, no uno
#
# Emitir CONGELA las notas —eso ya estaba y no se toca: lo que decía en
# diciembre tiene que seguir diciéndolo en marzo—. Liberar es publicarlo. Con
# una sola columna, corregir un error obligaría a re-emitir, y re-emitir
# reescribe el documento que ya se revisó.
#
# ⚠️ Y es REVERSIBLE: si al liberar aparece un error, se vuelve a esconder con
# el mismo clic. Un botón de una sola dirección obliga a que alguien escriba a
# soporte por un dedazo.
#
# ⚠️ Lo ya emitido queda SIN liberar, y está bien: nadie lo revisó. Marcarlo
# como liberado sería afirmar un vistazo que no ocurrió.
class LaBoletaSeLibera < ActiveRecord::Migration[8.1]
  def change
    add_column :report_cards, :liberado_el, :datetime
    add_reference :report_cards, :liberado_por, foreign_key: { to_table: :users }

    # La consulta de la familia: «los boletines liberados de mi hijo».
    add_index :report_cards, [ :enrollment_id, :liberado_el ]
  end
end
