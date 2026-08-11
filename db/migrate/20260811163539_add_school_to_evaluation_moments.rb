# `evaluation_moments` era la única tabla del dominio que quedaba sin aislar.
#
# MOR-85 materializó `school_id` en nueve tablas, pero esta no estaba en la lista
# porque en ese momento no tenía ningún vínculo con un colegio — MOR-83 le dio
# `academic_period_id` en la misma sesión. Quedó en el hueco entre los dos.
#
# Sin `school_id` no puede tener política de RLS: una política evalúa columnas de
# la fila y no puede recorrer la asociación hasta el período. Se descubrió
# comparando lo que ve el admin de cada colegio: los dos veían los 8 momentos.
#
# Ver MOR-87.
class AddSchoolToEvaluationMoments < ActiveRecord::Migration[8.1]
  def up
    add_reference :evaluation_moments, :school, null: true, foreign_key: true

    execute <<~SQL.squish
      UPDATE evaluation_moments em
         SET school_id = ap.school_id
        FROM academic_periods ap
       WHERE ap.id = em.academic_period_id
    SQL

    huerfanos = select_value("SELECT COUNT(*) FROM evaluation_moments WHERE school_id IS NULL").to_i
    if huerfanos.positive?
      raise ActiveRecord::MigrationError,
            "#{huerfanos} momento(s) sin colegio: su período académico no tiene school_id."
    end

    change_column_null :evaluation_moments, :school_id, false

    execute "ALTER TABLE evaluation_moments ENABLE ROW LEVEL SECURITY"
    execute "ALTER TABLE evaluation_moments FORCE  ROW LEVEL SECURITY"
    execute <<~SQL.squish
      CREATE POLICY aislamiento_por_colegio ON evaluation_moments
        USING (#{condicion})
        WITH CHECK (#{condicion})
    SQL
  end

  def down
    execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON evaluation_moments"
    execute "ALTER TABLE evaluation_moments NO FORCE ROW LEVEL SECURITY"
    execute "ALTER TABLE evaluation_moments DISABLE ROW LEVEL SECURITY"
    remove_reference :evaluation_moments, :school, foreign_key: true
  end

  private

  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
