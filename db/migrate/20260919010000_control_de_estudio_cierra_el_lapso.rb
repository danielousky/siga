# El visto bueno de Control de Estudio sobre un lapso de una sección.
#
# Daniel, 18 de septiembre: *«CE mira las boletas y da por "cerrado" el proceso
# de carga y completación de la calificación. Al dar el visto bueno se envía el
# correo al representante y ya puede entrar a ver sus notas, y a su vez el profe
# ya no puede modificar las notas»*.
#
#     POR CALIFICAR   falta alguna nota                    ← se DEDUCE
#     CALIFICADA      todas las notas de todos los alumnos ← se DEDUCE
#     CERRADA         Control de Estudio dio el visto bueno ← se GUARDA acá
#
# ## ⚠️ Los dos primeros estados NO se guardan
#
# Daniel lo pidió como «un campo de la sección», y guardar los tres sería un
# segundo lugar donde vive la misma verdad: el día que un profesor cargue la
# nota que faltaba, la columna seguiría diciendo «por calificar» hasta que algo
# la actualizara. Las notas SON la respuesta; lo único que ningún dato contesta
# es si una persona miró y dio el visto bueno, y eso es esta tabla.
#
# ## ⚠️ Y no es una columna de `sections`
#
# Una sección tiene tres lapsos y cada uno se cierra por su cuenta: el primero
# cerrado en diciembre, el segundo todavía por calificar. Una columna obligaría
# a tres —`cerrado_1`, `cerrado_2`, `cerrado_3`— y a renombrarlas el día que un
# colegio use dos semestres.
class ControlDeEstudioCierraElLapso < ActiveRecord::Migration[8.1]
  def change
    create_table :section_closures do |t|
      t.references :school, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.references :evaluation_moment, null: false, foreign_key: true
      t.references :cerrado_por, null: false, foreign_key: { to_table: :users }
      t.datetime :cerrado_el, null: false

      t.timestamps
    end

    # ⚠️ Único: cerrar dos veces el mismo lapso no es un hecho nuevo, y dos
    # filas harían que «quién lo cerró» tuviera dos respuestas.
    add_index :section_closures, [ :section_id, :evaluation_moment_id ],
              unique: true, name: "index_section_closures_sin_repetir"

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE section_closures ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE section_closures FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON section_closures
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end
      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON section_closures" }
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
