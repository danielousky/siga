# Que una constancia se pueda comprobar, como el boletín.
#
# Daniel, tras la prueba de campo: *«la constancia de estudio debe poder ser
# validada como los boletines»*.
#
# ## ⚠️ Esto NO contradice «la constancia no se guarda»; lo precisa
#
# La decisión anterior decía: el boletín certifica CALIFICACIONES y por eso
# queda archivado; la constancia certifica una SITUACIÓN DE HOY, y congelarla la
# volvería mentira mañana.
#
# Sigue siendo verdad, y por eso lo que se emite sigue saliendo con la situación
# del día. Lo que cambia es qué contesta el verificador:
#
#     NO dice   «este alumno estudia aquí»          ← eso cambia, y es de hoy
#     SÍ dice   «el colegio emitió este papel el 16 de septiembre,
#                y decía esto»                      ← eso no cambia nunca
#
# Que es justamente lo que necesita una embajada o un banco con el papel en la
# mano: no saber si hoy sigue inscrito, sino que el papel no está adulterado.
#
# ⚠️ Y por eso el código es ÚNICO GLOBAL, como el del boletín: se consulta desde
# `/verificar/CÓDIGO`, sin sesión y sin colegio.
class LaConstanciaSePuedeVerificar < ActiveRecord::Migration[8.1]
  def change
    create_table :constancias do |t|
      t.references :school, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :issued_by, null: false, foreign_key: { to_table: :users }

      t.string :code, null: false

      # Lo que decía el papel, congelado. Mismo criterio que el boletín: el
      # colegio puede renombrar una sección o corregir un apellido, y el
      # documento emitido tiene que seguir diciendo lo que decía.
      t.jsonb :snapshot, null: false, default: {}

      t.timestamps
    end

    add_index :constancias, :code, unique: true
    add_index :constancias, [ :enrollment_id, :created_at ]

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE constancias ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE constancias FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON constancias
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end
      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON constancias" }
    end
  end

  private

  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
