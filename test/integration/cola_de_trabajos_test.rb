require "test_helper"

# La cola de trabajos (cierre de pendientes de `CLAUDE.md`).
#
# Hasta acá el adaptador era `:async`, que guarda la cola **en memoria del
# proceso web**. Un reinicio —un deploy, un OOM, un `systemctl restart`— se
# llevaba lo encolado sin dejar rastro:
#
#     profesor cambia un peso  →  job encolado  →  deploy  →  job perdido
#                              →  los 30 alumnos con el promedio viejo
#
# Y nadie se enteraba, porque no hay error: simplemente no pasa nada.
class ColaDeTrabajosTest < ActiveSupport::TestCase
  # El adaptador de cada entorno, que es la decisión de fondo.
  test "producción y desarrollo usan la misma cola durable" do
    %w[production development].each do |entorno|
      archivo = Rails.root.join("config/environments/#{entorno}.rb").read

      assert_match(/config\.active_job\.queue_adapter\s*=\s*:solid_queue/, archivo,
        "#{entorno} debería usar Solid Queue: si la cola se comporta distinto en " \
        "cada entorno, el problema solo aparece en producción")
    end
  end

  # En tests hace falta el adaptador de prueba: `perform_enqueued_jobs` y
  # `assert_enqueued_with` necesitan que los trabajos NO se ejecuten solos.
  test "en tests la cola es observable" do
    assert_match(/queue_adapter\s*=\s*:test/,
                 Rails.root.join("config/environments/test.rb").read)
  end

  # Sin base separada: el generador la asume, y para un solo job sería una
  # segunda cadena de conexión que configurar, respaldar y monitorear.
  test "la cola vive en la misma base que la app" do
    produccion = Rails.root.join("config/environments/production.rb").read

    assert_no_match(/solid_queue\.connects_to/, produccion,
      "sin `connects_to`, Solid Queue usa la conexión por defecto — que es lo que se quiere")

    assert_includes ActiveRecord::Base.connection.tables, "solid_queue_jobs",
      "las tablas de la cola tienen que estar en la base principal"
  end

  # Un worker que nadie levanta deja la cola llena para siempre: sobrevive al
  # reinicio, pero nadie la vacía.
  test "el despliegue declara el proceso worker" do
    procfile = Rails.root.join("Procfile")

    assert procfile.exist?, "falta el Procfile: sin proceso worker, la cola no se vacía nunca"
    assert_match(/^worker:/, procfile.read)
  end

  # Las tablas de la cola NO son datos de un colegio: son la maquinaria de la
  # plataforma, igual que `SigaStaff` (MOR-133). El colegio de un job viaja en
  # su payload y lo restablece `CarriesSchool` (MOR-88).
  test "las tablas de la cola no están bajo aislamiento por colegio" do
    con_rls = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT tablename FROM pg_tables
       WHERE schemaname = 'public'
         AND tablename LIKE 'solid_queue%'
         AND rowsecurity = true
    SQL

    assert_empty con_rls,
      "las tablas de la cola no deben tener RLS: no pertenecen a ningún colegio, " \
      "y con RLS un worker sin contexto no vería ni sus propios trabajos"
  end
end
