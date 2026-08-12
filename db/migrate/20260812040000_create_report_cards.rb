# El registro de cada boletín emitido.
#
# Resuelve tres cosas del issue con una sola tabla:
#
#   ARCHIVO       `snapshot` guarda las notas TAL COMO SE IMPRIMIERON. No sirve
#                 recalcularlas después: un boletín entregado en diciembre dice
#                 lo que decía en diciembre, aunque el profesor corrija una nota
#                 en marzo. Guardar el JSON es más útil que guardar el PDF —
#                 ocupa nada, se puede consultar y el PDF se regenera igual.
#
#   AUDITORÍA     quién lo emitió y cuándo. Un boletín es un documento oficial.
#
#   VERIFICACIÓN  `code` va impreso en el papel y se consulta en una ruta
#                 pública. Un PDF es trivial de editar antes de imprimirlo; el
#                 código deja que la familia —o el colegio al que el alumno se
#                 traslada— compruebe contra la fuente.
#
# Ver MOR-98.
class CreateReportCards < ActiveRecord::Migration[8.1]
  def change
    create_table :report_cards do |t|
      t.references :school, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true

      # NULL = boletín anual. Con lapso = boletín de ese lapso.
      t.references :evaluation_moment, foreign_key: true

      t.string :code, null: false
      t.jsonb  :snapshot, null: false, default: {}
      t.references :issued_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Único en TODA la plataforma, no por colegio: el código se teclea en una
    # ruta pública sin sesión, así que no hay inquilino con el que desempatar.
    add_index :report_cards, :code, unique: true

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE report_cards ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE report_cards FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON report_cards
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down do
        execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON report_cards"
      end
    end
  end

  private

  # La misma condición que las otras 17 tablas (MOR-87).
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
