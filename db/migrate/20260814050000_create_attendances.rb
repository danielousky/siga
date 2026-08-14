# Asistencia diaria por sección (MOR-111).
#
# ## Las cuatro decisiones que el issue dejaba abiertas
#
# | Pregunta        | Elegido                    | Por qué |
# |-----------------|----------------------------|---------|
# | Granularidad    | **por día**                | Es lo que el colegio reporta al MPPE y lo que la familia pregunta. Por hora de clase multiplica por seis el trabajo del docente para responder la misma pregunta. |
# | Estados         | **presente · ausente · tarde** | Los tres que el docente puede OBSERVAR parado en la puerta. |
# | Quién la toma   | **el profesor guía**       | `grades.leader_teacher` ya existe. Un solo responsable por sección y por día. |
# | Justificación   | **una nota, después**      | Al tomar asistencia nadie sabe si la falta es justificada: el papel llega al día siguiente. Por eso no es un cuarto estado sino un campo aparte, que llena quien recibe el justificativo. |
#
# El issue recomendaba "tres estados" y son tres. La justificación quedó como
# nota y no como estado justamente para no volverlos cuatro: son dos momentos
# distintos del proceso y dos personas distintas.
class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.references :school,     null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }

      t.date    :date,   null: false
      t.integer :status, null: false, default: 0

      # Quién justificó y con qué. Llega DESPUÉS de la toma, casi siempre de otra
      # persona: el docente marca la falta, la secretaría recibe el papel.
      t.text     :justificacion
      t.datetime :justificada_en
      t.references :justificada_por, foreign_key: { to_table: :users }

      t.timestamps
    end

    # Un alumno tiene UNA asistencia por día. Sin esto, abrir la pantalla dos
    # veces —cosa que pasa— duplica el día y los reportes de inasistencia
    # empiezan a contar mal.
    add_index :attendances, [:enrollment_id, :date], unique: true

    # El reporte que el colegio necesita —quién acumula faltas— y la consulta de
    # la pantalla de toma, que pide un día de una sección.
    add_index :attendances, [:school_id, :date]

    add_check_constraint :attendances, "status IN (0, 1, 2)", name: "attendances_status_valido"

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE attendances ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE attendances FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON attendances
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down do
        execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON attendances"
      end
    end
  end

  private

  # La misma condición que las otras 18 tablas (MOR-87).
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
