# La segunda capa del aislamiento, en la base.
#
# El `default_scope` de SchoolScoped es una convención de la aplicación, y las
# convenciones se rompen: un `joins` a mano, un `find_by_sql`, un controller
# nuevo que no incluyó el concern. Cada una de esas es una fuga, y NINGUNA hace
# ruido — la página simplemente muestra datos de más.
#
# Con RLS ese mismo olvido produce una lista vacía. Un desarrollador investiga
# una lista vacía en cinco minutos; una lista con datos de más puede vivir meses
# en producción.
#
# ## FORCE no es opcional
#
# El usuario con que Rails se conecta es el OWNER de las tablas, y el owner está
# exento de RLS por defecto. Sin `FORCE ROW LEVEL SECURITY` todo parece
# configurado, los tests pasan, y la política no se evalúa ni una vez.
#
# ## Cómo falla
#
# `current_setting('siga.school_id', true)` devuelve NULL cuando la variable no
# está puesta, y `school_id = NULL` es NULL, que filtra la fila. O sea: sin
# contexto no se ve NADA. Es el modo correcto de fallar — hacia el silencio, no
# hacia la fuga.
#
# Ver MOR-87.
class EnableRowLevelSecurityPerSchool < ActiveRecord::Migration[8.1]
  TABLAS = %w[
    academic_periods activity_grades activity_logs admins departments
    enrollments evaluation_activities final_grade_books grade_subjects
    grades moment_grades sections students subjects teachers teacher_sections
  ].freeze

  POLITICA = "aislamiento_por_colegio".freeze

  def up
    TABLAS.each do |tabla|
      execute "ALTER TABLE #{tabla} ENABLE ROW LEVEL SECURITY"
      execute "ALTER TABLE #{tabla} FORCE  ROW LEVEL SECURITY"

      # `USING` filtra lo que se puede LEER; `WITH CHECK`, lo que se puede
      # ESCRIBIR. Sin el segundo se podrían insertar filas de otro colegio
      # aunque no se pudieran ver después.
      execute <<~SQL.squish
        CREATE POLICY #{POLITICA} ON #{tabla}
          USING (#{condicion})
          WITH CHECK (#{condicion})
      SQL
    end
  end

  def down
    TABLAS.each do |tabla|
      execute "DROP POLICY IF EXISTS #{POLITICA} ON #{tabla}"
      execute "ALTER TABLE #{tabla} NO FORCE ROW LEVEL SECURITY"
      execute "ALTER TABLE #{tabla} DISABLE ROW LEVEL SECURITY"
    end
  end

  private

  # Dos formas de pasar:
  #
  #   1. La fila es del colegio de la sesión.
  #   2. La sesión declaró explícitamente que no quiere aislamiento — migraciones,
  #      seeds, consola. Se activa desde `Current.sin_aislamiento`, que es
  #      greppable: buscar ese nombre muestra todos los lugares que ven la
  #      plataforma entera.
  #
  # `activity_logs` necesita además dejar pasar las filas sin colegio, que son
  # las de usuarios sin rol (ver MOR-85). Se resuelve con `IS NOT DISTINCT FROM`
  # en vez de un caso aparte: NULL solo coincide con NULL.
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
