# El representante y su vínculo con los alumnos (MOR-110).
#
# ## Por qué son DOS tablas y no una columna en `students`
#
# El vínculo es menos simple de lo que parece:
#
#   · un representante puede tener **varios hijos**, en secciones y grados
#     distintos;
#   · un alumno puede tener **más de un representante** — madre, padre, tutor;
#   · y un representante puede tener hijos **en colegios distintos**, que es el
#     caso que choca de frente con el aislamiento: su usuario es uno, sus
#     inquilinos son dos.
#
# Una columna `representative_id` en `students` solo resuelve el primero.
#
# ## `representatives` refleja a `teachers` y `admins`
#
# Es el registro de ROL, con su colegio. Un usuario con hijos en dos colegios
# tiene **dos filas**, una por colegio — igual que un profesor que trabaja en
# dos. Así cada fila sigue perteneciendo a un solo inquilino y el aislamiento
# no necesita ninguna excepción.
class CreateRepresentatives < ActiveRecord::Migration[8.1]
  def change
    create_table :representatives do |t|
      t.references :user,   null: false, foreign_key: true
      t.references :school, null: false, foreign_key: true

      # Cómo prefiere que le escriban. El correo ya está en `users`; acá va el
      # teléfono, que en Venezuela es el canal real (MOR-113, WhatsApp).
      t.string :phone

      t.timestamps
    end

    # Una fila por usuario y colegio. Dos filas del mismo par serían dos
    # identidades para la misma persona en el mismo colegio.
    add_index :representatives, [:user_id, :school_id], unique: true

    create_table :student_representatives do |t|
      t.references :representative, null: false, foreign_key: true
      t.references :student,        null: false, foreign_key: { to_table: :students, primary_key: :user_id }
      t.references :school,         null: false, foreign_key: true

      t.integer :parentesco, null: false, default: 0

      # Quién recibe las comunicaciones cuando hay dos. Sin esto, o se le escribe
      # a los dos siempre —y uno de los dos se molesta— o el sistema elige por su
      # cuenta, que es peor.
      t.boolean :principal, null: false, default: false

      t.timestamps
    end

    add_index :student_representatives, [:representative_id, :student_id], unique: true,
              name: "index_student_representatives_unicos"

    add_check_constraint :student_representatives, "parentesco IN (0, 1, 2, 3)",
                         name: "student_representatives_parentesco_valido"

    reversible do |dir|
      dir.up do
        %w[representatives student_representatives].each do |tabla|
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
        %w[representatives student_representatives].each do |tabla|
          execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON #{tabla}"
        end
      end
    end
  end

  private

  # La misma condición que las otras 19 tablas (MOR-87).
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
