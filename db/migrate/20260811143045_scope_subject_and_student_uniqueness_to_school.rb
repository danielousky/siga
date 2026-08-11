# `subjects.code` y `students.school_card` eran únicos GLOBALES. Son identificadores
# internos de cada institución, no de la plataforma: si un colegio usaba el código
# MAT-01 para Matemática, ningún otro podía volver a usarlo.
#
# Un colegio que viene de otro sistema trae sus códigos ya impresos en carnets y
# planillas. Pedirle que los cambie porque otro cliente los usó primero es
# inaceptable en la venta.
#
# No todo índice único es un error, y conviene dejar dicho cuáles quedan globales
# a propósito:
#
#   schools.dea_code   global ✅  lo asigna el MPPE, es único en el país
#   users.email        global ✅  Devise autentica ANTES de saber el inquilino
#   users.id_card      global ✅  la cédula identifica a una persona, no a un rol
#
# Ver MOR-84.
class ScopeSubjectAndStudentUniquenessToSchool < ActiveRecord::Migration[8.1]
  def up
    # --- subjects: la columna no existe, se deduce por el departamento ---------
    add_reference :subjects, :school, null: true, foreign_key: true

    execute <<~SQL.squish
      UPDATE subjects s
         SET school_id = d.school_id
        FROM departments d
       WHERE d.id = s.department_id
    SQL

    verify_every_subject_has_a_school!

    change_column_null :subjects, :school_id, false
    remove_index :subjects, name: "index_subjects_on_code"
    add_index :subjects, [:school_id, :code], unique: true

    # --- students: la columna YA existía, solo faltaba componer el índice ------
    remove_index :students, name: "index_students_on_school_card"
    add_index :students, [:school_id, :school_card], unique: true
  end

  def down
    remove_index :students, column: [:school_id, :school_card]
    desambiguar_por_colegio!(:students, :school_card)
    add_index :students, :school_card, unique: true

    remove_index :subjects, column: [:school_id, :code]
    desambiguar_por_colegio!(:subjects, :code)
    add_index :subjects, :code, unique: true
    remove_reference :subjects, :school, foreign_key: true
  end

  private

  def verify_every_subject_has_a_school!
    huerfanas = select_all(
      "SELECT id, code, name FROM subjects WHERE school_id IS NULL ORDER BY id"
    ).to_a
    return if huerfanas.empty?

    detalle = huerfanas.map { |s| "  ##{s['id']} #{s['code']} — #{s['name']}" }.join("\n")
    raise ActiveRecord::MigrationError, <<~MSG
      #{huerfanas.size} materia(s) quedaron sin colegio después del backfill:

      #{detalle}

      El colegio sale de su departamento, así que esto significa que el
      departamento tampoco tiene escuela. Revisalo antes de volver a correrla.
    MSG
  end

  # Volver a un índice único global exige que los valores repetidos entre colegios
  # dejen de repetirse. Se les antepone el código DEA del colegio.
  #
  # Ojo: NO es byte-idéntico a lo que hubiera antes de la migración. Restaura el
  # invariante (unicidad global), no el texto original. Y solo toca los valores
  # que efectivamente estén duplicados.
  def desambiguar_por_colegio!(tabla, columna)
    execute <<~SQL.squish
      UPDATE #{tabla} t
         SET #{columna} = s.dea_code || '-' || t.#{columna}
        FROM schools s
       WHERE s.id = t.school_id
         AND EXISTS (
               SELECT 1 FROM #{tabla} o
                WHERE o.#{columna} = t.#{columna}
                  AND o.#{tabla == :students ? 'user_id' : 'id'} <> t.#{tabla == :students ? 'user_id' : 'id'}
             )
    SQL
  end
end
