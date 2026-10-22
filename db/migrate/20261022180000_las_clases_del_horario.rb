# La clase: una casilla del horario —sección · área · día · hora— y las dos
# reglas que hacen imposible el choque (spec `horarios`, § 9).
#
#    una SECCIÓN, una clase a la vez        lessons_una_clase_a_la_vez
#    un PROFESOR, un sitio a la vez         lessons_un_profesor_en_un_sitio
#
# ## ⚠️ La clase copia tres datos de otras tablas, y los mantiene PostgreSQL
#
# Una restricción solo mira las columnas de su propia fila, así que la clase
# guarda el año, los minutos y el profesor. No los mantiene el código: son
# llaves compuestas, y cada una dice qué pasa cuando cambia el original.
#
#    (section_id, academic_period_id)      → sections          borrar la sección se lleva sus clases
#    (time_slot_id, starts_min, ends_min)  → time_slots        corregir la hora mueve los minutos;
#                                                              una hora con clases no se borra
#    (section_id, subject_id, teacher_id)  → teacher_sections  borrar la asignación deja la clase
#                                                              «sin profesor» (SET NULL de UNA columna)
#
# Hay seis sitios que crean o borran asignaciones —la pantalla, el importador,
# copiar la estructura, dos siembras y `prueba.rake` con `delete_all`—: con
# callbacks, alguno se quedaría atrás.
#
# ⚠️ `ON DELETE SET NULL (teacher_id)` pide PostgreSQL 15. Local y CI: 17;
# producción y la muestra: 18.4 (mirado el 13 de octubre).
class LasClasesDelHorario < ActiveRecord::Migration[8.1]
  def change
    # Una llave compuesta exige, del otro lado, un índice único con EXACTAMENTE
    # esas columnas: que una de ellas ya sea única no le alcanza a PostgreSQL.
    add_index :sections, [ :id, :academic_period_id ], unique: true,
              name: "index_sections_con_su_anio"
    add_index :time_slots, [ :id, :starts_min, :ends_min ], unique: true,
              name: "index_time_slots_con_sus_minutos"
    add_index :teacher_sections, [ :section_id, :subject_id, :teacher_id ], unique: true,
              name: "index_teacher_sections_con_su_profesor"

    create_table :lessons do |t|
      t.references :school, null: false, foreign_key: true
      t.references :academic_period, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: false
      t.references :subject, null: false, foreign_key: true
      t.references :teacher, null: true, foreign_key: true
      t.references :time_slot, null: false, foreign_key: false
      t.integer :day, null: false
      t.integer :starts_min, null: false
      t.integer :ends_min, null: false

      t.timestamps
    end

    add_check_constraint :lessons, "day BETWEEN 1 AND 5", name: "lessons_dia_valido"
    add_check_constraint :lessons, "starts_min >= 0 AND starts_min < ends_min AND ends_min <= 1440",
                         name: "lessons_minutos_validos"

    add_exclusion_constraint :lessons,
                             "section_id WITH =, day WITH =, int4range(starts_min, ends_min) WITH &&",
                             using: :gist, deferrable: :immediate, name: "lessons_una_clase_a_la_vez"
    # Dos clases sin profesor no chocan: `NULL = NULL` no es verdadero.
    add_exclusion_constraint :lessons,
                             "teacher_id WITH =, academic_period_id WITH =, day WITH =, " \
                             "int4range(starts_min, ends_min) WITH &&",
                             using: :gist, deferrable: :immediate, name: "lessons_un_profesor_en_un_sitio"

    add_column :sections, :timetable_published_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE lessons ADD CONSTRAINT lessons_de_su_seccion
            FOREIGN KEY (section_id, academic_period_id) REFERENCES sections (id, academic_period_id)
            ON UPDATE CASCADE ON DELETE CASCADE
        SQL
        execute <<~SQL.squish
          ALTER TABLE lessons ADD CONSTRAINT lessons_en_su_hora
            FOREIGN KEY (time_slot_id, starts_min, ends_min) REFERENCES time_slots (id, starts_min, ends_min)
            ON UPDATE CASCADE ON DELETE RESTRICT
        SQL
        execute <<~SQL.squish
          ALTER TABLE lessons ADD CONSTRAINT lessons_con_su_profesor
            FOREIGN KEY (section_id, subject_id, teacher_id) REFERENCES teacher_sections (section_id, subject_id, teacher_id)
            ON UPDATE CASCADE ON DELETE SET NULL (teacher_id)
        SQL

        execute "ALTER TABLE lessons ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE lessons FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON lessons
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end
      dir.down do
        execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON lessons"
        %w[lessons_de_su_seccion lessons_en_su_hora lessons_con_su_profesor].each do |llave|
          execute "ALTER TABLE lessons DROP CONSTRAINT IF EXISTS #{llave}"
        end
      end
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
