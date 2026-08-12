require "test_helper"

# Los dos tests que hacen que el aislamiento se mantenga SOLO.
#
# Todo lo demás de la suite prueba lo que hay hoy. Esto prueba lo que va a haber:
# un modelo nuevo que se olvide del concern, o una tabla nueva sin política de
# RLS, rompen acá — antes de llegar a producción.
#
# Ver MOR-90.
class AislamientoEstructuralTest < ActiveSupport::TestCase
  # Tablas con `school_id` que NO llevan aislamiento, y por qué. Cualquier otra
  # que aparezca tiene que romper el test hasta que alguien decida a cuál de las
  # dos listas pertenece.
  SIN_AISLAMIENTO = {
    # No hay ninguna hoy. Si mañana la hay, va acá con su razón escrita.
  }.freeze

  # ══════════════════════════════════════════════════════════════════════════
  # 1 · Todo modelo con school_id tiene que incluir SchoolScoped
  # ══════════════════════════════════════════════════════════════════════════

  test "ningún modelo con school_id se queda sin SchoolScoped" do
    Rails.application.eager_load!

    olvidados = ApplicationRecord.descendants.reject(&:abstract_class?).select do |modelo|
      next false unless modelo.table_exists?
      next false unless modelo.column_names.include?("school_id")
      next false if SIN_AISLAMIENTO.key?(modelo.table_name)

      !modelo.include?(SchoolScoped)
    end

    assert_empty olvidados.map(&:name),
                 "Estos modelos tienen school_id y NO incluyen SchoolScoped. " \
                 "Sin el concern, sus consultas devuelven los datos de todos los colegios."
  end

  # ══════════════════════════════════════════════════════════════════════════
  # 2 · Toda tabla con school_id tiene que tener RLS, con FORCE
  # ══════════════════════════════════════════════════════════════════════════

  # `ENABLE` sin `FORCE` no sirve de nada acá: el dueño de la tabla —que es el
  # rol de la app— se saltaría sus propias políticas. Es el error más común al
  # implementar RLS y no da ninguna señal (MOR-87).
  test "ninguna tabla con school_id se queda sin RLS y sin FORCE" do
    filas = ActiveRecord::Base.connection.select_all(<<~SQL.squish).to_a
      SELECT c.relname AS tabla, c.relrowsecurity AS habilitado, c.relforcerowsecurity AS forzado,
             (SELECT count(*) FROM pg_policy p WHERE p.polrelid = c.oid) AS politicas
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relkind = 'r'
         AND EXISTS (
           SELECT 1 FROM information_schema.columns col
            WHERE col.table_name = c.relname AND col.column_name = 'school_id'
         )
    SQL

    assert filas.any?, "la consulta no encontró ninguna tabla con school_id — algo anda mal en el test"

    sin_proteger = filas.reject do |f|
      SIN_AISLAMIENTO.key?(f["tabla"]) ||
        (f["habilitado"] && f["forzado"] && f["politicas"].to_i.positive?)
    end

    assert_empty sin_proteger.map { |f| f["tabla"] },
                 "Estas tablas tienen school_id y les falta ENABLE, FORCE o la política de RLS. " \
                 "Sin FORCE, el dueño de la tabla —que es el rol de la app— se salta sus propias políticas."
  end

  # ══════════════════════════════════════════════════════════════════════════
  # 3 · Cada capa, medida POR SEPARADO
  # ══════════════════════════════════════════════════════════════════════════
  #
  # ⚠️ Esto es lo que hace que la suite muerda, y costó descubrirlo.
  #
  # La primera versión de estos tests medía las dos capas juntas: se pedía un
  # recurso ajeno y se esperaba 404. Rompí el `default_scope` ENTERO a propósito
  # —lo dejé en `all`— y **los 54 tests siguieron en verde**, porque el RLS
  # filtraba igual.
  #
  # Que cada capa alcance sola es exactamente lo que se quería del diseño. Pero
  # significa que un test que las mide juntas **no puede detectar la pérdida de
  # una**: el sistema aguanta con la que queda, hasta el día que falle la otra.
  #
  # Así que cada capa se mide con la otra apagada.

  # Capa 1 sola: se apaga el RLS de la conexión y queda solo el `default_scope`.
  test "el default_scope de la app filtra por sí solo, sin el RLS" do
    a, b = dos_colegios_completos

    con_el_colegio(a.colegio) do
      sin_rls do
        assert_equal 1, Grade.count, "el default_scope tiene que filtrar aunque el RLS no esté"
        assert_equal 0, Grade.where(school_id: b.colegio.id).count
        assert_equal 2, Student.count
      end
    end
  end

  # Capa 2 sola: SQL crudo, que no pasa por ningún scope de ActiveRecord.

  test "una consulta SQL cruda solo ve el colegio del contexto" do
    a, b = dos_colegios_completos

    con_el_colegio(a.colegio) do
      assert_equal 1, contar_crudo("grades", a.colegio.id)
      assert_equal 0, contar_crudo("grades", b.colegio.id),
                   "pidiendo EXPLÍCITAMENTE las filas del otro colegio, Postgres tiene que devolver cero"
    end
  end

  # El modo correcto de fallar: sin contexto no se ve NADA, en vez de verse todo.
  # Una fuga silenciosa se vuelve una pantalla vacía, que alguien investiga.
  test "sin contexto de colegio no se ve ninguna fila" do
    dos_colegios_completos

    fijar_contexto_rls(nil)

    %w[grades students sections subjects enrollments report_cards].each do |tabla|
      assert_equal 0, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{tabla}").to_i,
                   "#{tabla}: sin contexto tiene que devolver cero filas, no todas"
    end
  end

  test "el WITH CHECK impide escribir una fila de otro colegio" do
    a, b = dos_colegios_completos

    con_el_colegio(a.colegio) do
      error = assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) do
          ActiveRecord::Base.connection.execute(<<~SQL.squish)
            INSERT INTO grades (school_id, name, level, created_at, updated_at)
            VALUES (#{b.colegio.id}, 'Colado', 1, NOW(), NOW())
          SQL
        end
      end

      assert_match(/row-level security/i, error.message)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # 4 · El rol de la base, que es de lo que depende todo lo anterior
  # ══════════════════════════════════════════════════════════════════════════

  # Si este test falla, TODOS los de RLS de arriba son decorativos: un superusuario
  # se salta las políticas antes de mirarlas y las consultas devuelven todo igual.
  test "el rol con el que corren los tests no puede saltarse el RLS" do
    rol = ActiveRecord::Base.connection.select_one(
      "SELECT rolname, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user"
    )

    assert_not rol["rolsuper"], "#{rol['rolname']} es SUPERUSER: los tests de RLS no prueban nada"
    assert_not rol["rolbypassrls"], "#{rol['rolname']} tiene BYPASSRLS: los tests de RLS no prueban nada"
  end

  private

  def contar_crudo(tabla, school_id)
    ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM #{tabla} WHERE school_id = #{school_id.to_i}"
    ).to_i
  end

  # Apaga SOLO el RLS, dejando el `default_scope` en pie.
  #
  # No sirve `Current.sin_aislamiento` acá: ese apaga las dos capas, que es lo
  # correcto para un backfill y justamente lo contrario de lo que hace falta para
  # medir una sola.
  def sin_rls
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'on'")
    yield
  ensure
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'off'")
  end
end
