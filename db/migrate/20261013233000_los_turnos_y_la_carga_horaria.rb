# Los horarios, tanda 1: a qué hora suena el timbre y cuántas horas tiene cada
# área. Spec: `docs/specs/horarios.md`.
#
#     bell_schedules   «Turno»   Media · mañana
#     time_slots       «hora»    1ra 7:10–7:50 … Receso 9:50–10:20
#     sections.bell_schedule_id          el turno de la sección
#     grade_subjects.weekly_hours        la carga horaria: horas a la semana
#
# ## ⚠️ La hora se guarda en MINUTOS desde la medianoche, no en una columna de hora
#
# `starts_min = 430` es las 7:10. Son dos razones, y las dos muerden:
#
# - La app corre en UTC y Venezuela está cuatro horas atrás. Una columna `time`
#   pasa por la zona horaria de Rails, y el día que alguien ponga
#   `config.time_zone` las siete de la mañana pasarían a ser las once.
# - Un choque de horario es que dos rangos se PISEN, y eso PostgreSQL lo sabe
#   preguntar de un rango de enteros: `int4range(430, 470) && int4range(470, 510)`
#   es falso, porque el rango es `[inicio, fin)` — la 1ra termina a las 7:50 y la
#   2da empieza a las 7:50, y no chocan.
#
# ## ⚠️ `btree_gist`, la primera extensión del proyecto
#
# Una restricción `EXCLUDE` mezcla «el mismo turno» (un `=` sobre un entero) con
# «rangos que se pisan» (un `&&`), y el índice que sabe de rangos —GiST— no sabe
# comparar enteros sin esta extensión. Es de confianza: la crea el dueño de la
# base, sin superusuario. Se miró en producción el 13 de octubre de 2026, en las
# dos instancias: PostgreSQL 18.4, `siga_app` es dueño y la puede crear.
#
# ## ⚠️ Y por qué la regla vive en la base y no solo en el modelo
#
# Dos personas guardando a la vez pasan las dos la validación —ninguna ve
# todavía la fila de la otra— y entran las dos. La base es la única que las ve
# juntas. Es la misma idea del `CHECK` de la nota del 1 al 20.
class LosTurnosYLaCargaHoraria < ActiveRecord::Migration[8.1]
  TABLAS = %i[bell_schedules time_slots].freeze

  def change
    enable_extension "btree_gist"

    # El turno es del AÑO ESCOLAR, como las secciones y los lapsos: el timbre de
    # este año puede no ser el del que viene, y un horario de un año cerrado
    # tiene que seguir diciendo a qué hora fue.
    create_table :bell_schedules do |t|
      t.references :school, null: false, foreign_key: true
      t.references :academic_period, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :bell_schedules, [ :academic_period_id, :name ],
              unique: true, name: "index_bell_schedules_sin_repetir"

    create_table :time_slots do |t|
      t.references :school, null: false, foreign_key: true
      t.references :bell_schedule, null: false, foreign_key: true
      t.integer :starts_min, null: false
      t.integer :ends_min, null: false
      # 0 clase · 1 receso. El receso no es un hueco: es un renglón que el
      # colegio escribe en su horario, con su hora.
      t.integer :kind, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :time_slots, "starts_min >= 0 AND starts_min < ends_min AND ends_min <= 1440",
                         name: "time_slots_minutos_validos"
    add_check_constraint :time_slots, "kind IN (0, 1)", name: "time_slots_kind_valido"

    # ⚠️ Dos horas de un mismo turno no se pisan. Diferible, para el día que se
    # corra el timbre entero de una vez: moviendo hora por hora, la 1ra pisaría
    # a la 2da a mitad de camino aunque el resultado final esté bien.
    add_exclusion_constraint :time_slots,
                             "bell_schedule_id WITH =, int4range(starts_min, ends_min) WITH &&",
                             using: :gist, deferrable: :immediate, name: "time_slots_no_se_pisan"

    add_reference :sections, :bell_schedule, null: true, foreign_key: true

    # ⚠️ Sin año: es del pensum (`grade_subjects`), que tampoco lo tiene. Cuántas
    # horas de Matemática lleva 1er Año no cambia de septiembre a septiembre.
    add_column :grade_subjects, :weekly_hours, :integer
    add_check_constraint :grade_subjects, "weekly_hours IS NULL OR weekly_hours BETWEEN 1 AND 60",
                         name: "grade_subjects_horas_validas"

    reversible do |dir|
      dir.up do
        TABLAS.each do |tabla|
          execute "ALTER TABLE #{tabla} ENABLE ROW LEVEL SECURITY"
          execute "ALTER TABLE #{tabla} FORCE  ROW LEVEL SECURITY"
          execute <<~SQL.squish
            CREATE POLICY aislamiento_por_colegio ON #{tabla}
              USING (#{condicion})
              WITH CHECK (#{condicion})
          SQL
        end
      end
      dir.down do
        TABLAS.each { |tabla| execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON #{tabla}" }
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
