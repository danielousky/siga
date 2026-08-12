# El RLS no protege nada si la aplicación se conecta como superusuario.
#
# Un superusuario —y cualquier rol con BYPASSRLS— se salta las políticas por
# completo, y `FORCE ROW LEVEL SECURITY` tampoco lo alcanza: FORCE solo hace que
# el DUEÑO de la tabla quede sujeto a las políticas. El superusuario está por
# encima de eso.
#
# En un macOS con Postgres de Homebrew el usuario por defecto ES superusuario,
# así que sin este rol el aislamiento parece configurado y no se evalúa ni una
# vez. Se descubrió midiéndolo: las políticas estaban, FORCE estaba, y una
# consulta cruda seguía devolviendo los 290 alumnos de los dos colegios.
#
# Ver MOR-87.
namespace :rls do
  ROL_APP = "siga_app".freeze

  desc "Crea el rol sin privilegios con el que la app se conecta (obligatorio para que el RLS aplique)"
  task crear_rol: :environment do
    conn = ActiveRecord::Base.connection

    existe = conn.select_value(
      ActiveRecord::Base.sanitize_sql_array(["SELECT 1 FROM pg_roles WHERE rolname = ?", ROL_APP])
    )

    # CREATEDB es para `bin/rails test`, que purga y recrea siga_test en cada
    # corrida. NO afecta el aislamiento: lo que hace que el RLS se evalúe es
    # NOSUPERUSER + NOBYPASSRLS, y crear bases no confiere ninguno de los dos.
    # En producción la app entra con otro rol (ver config/database.yml), que no
    # necesita crear nada.
    # En el CI, Postgres corre en otro contenedor y exige contraseña por TCP. En
    # una máquina de desarrollo la conexión va por socket local y no hace falta.
    clave = ENV["SIGA_APP_PASSWORD"]
    con_clave = clave.present? ? "PASSWORD #{conn.quote(clave)}" : ""

    if existe
      conn.execute("ALTER ROLE #{ROL_APP} CREATEDB #{con_clave}")
      puts "· El rol #{ROL_APP} ya existe."
    else
      conn.execute("CREATE ROLE #{ROL_APP} LOGIN NOSUPERUSER NOBYPASSRLS CREATEDB NOCREATEROLE #{con_clave}")
      puts "✓ Rol #{ROL_APP} creado (NOSUPERUSER, NOBYPASSRLS)."
    end

    # La base también cambia de dueño, no solo las tablas.
    #
    # `bin/rails test` empieza purgando y recreando siga_test, y eso solo lo puede
    # hacer el DUEÑO DE LA BASE. Con las tablas traspasadas pero la base ajena, la
    # app corría bien y la suite moría con "must be owner of database siga_test".
    %w[siga_development siga_test].each do |db|
      existe_base = conn.select_value(
        ActiveRecord::Base.sanitize_sql_array(["SELECT 1 FROM pg_database WHERE datname = ?", db])
      )
      next unless existe_base

      conn.execute(%(ALTER DATABASE "#{db}" OWNER TO #{ROL_APP}))
      puts "✓ Base #{db} traspasada a #{ROL_APP}."
    end

    base = conn.current_database
    conn.execute("GRANT CONNECT ON DATABASE #{base} TO #{ROL_APP}")
    conn.execute("GRANT USAGE, CREATE ON SCHEMA public TO #{ROL_APP}")
    conn.execute("GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO #{ROL_APP}")
    conn.execute("GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO #{ROL_APP}")
    # Para las tablas que creen las migraciones futuras.
    conn.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO #{ROL_APP}")
    conn.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO #{ROL_APP}")
    puts "✓ Permisos otorgados sobre #{base}."

    # El rol pasa a ser DUEÑO de las tablas, y esto es justamente para lo que
    # existe FORCE ROW LEVEL SECURITY.
    #
    # La alternativa —dejar las tablas del usuario original y que la app entre
    # como invitada— también aísla, pero entonces las migraciones no pueden
    # crear políticas ("must be owner of table") y habría que correrlas con otro
    # usuario. Un solo rol, dueño y sometido a sus propias políticas por FORCE,
    # evita ese doble juego de credenciales.
    tablas = conn.select_values(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
    )
    tablas.each { |t| conn.execute(%(ALTER TABLE public."#{t}" OWNER TO #{ROL_APP})) }

    secuencias = conn.select_values(
      "SELECT sequencename FROM pg_sequences WHERE schemaname = 'public'"
    )
    secuencias.each { |s| conn.execute(%(ALTER SEQUENCE public."#{s}" OWNER TO #{ROL_APP})) }

    puts "✓ #{tablas.size} tablas y #{secuencias.size} secuencias pasadas a #{ROL_APP}."
    puts ""
    puts "  Es dueño, pero FORCE ROW LEVEL SECURITY lo somete igual a las políticas."
    puts "  Sin FORCE, un dueño se las saltaría todas."
  end

  desc "Comprueba que el rol de la app no puede saltarse el RLS"
  task verificar: :environment do
    conn = ActiveRecord::Base.connection
    r = conn.select_one(
      "SELECT current_user AS usuario, rolsuper, rolbypassrls " \
      "FROM pg_roles WHERE rolname = current_user"
    )

    puts "Conectado como: #{r['usuario']}"
    puts "  SUPERUSER:  #{r['rolsuper']}"
    puts "  BYPASSRLS:  #{r['rolbypassrls']}"
    puts ""

    if r["rolsuper"] || r["rolbypassrls"]
      abort <<~MSG
        ✗ Este rol SE SALTA el RLS. El aislamiento de la base no está protegiendo nada.

          Corré:  bin/rails rls:crear_rol
          Y apuntá config/database.yml al rol #{ROL_APP}.
      MSG
    end

    puts "✓ El rol está sujeto a las políticas de RLS."
  end
end
