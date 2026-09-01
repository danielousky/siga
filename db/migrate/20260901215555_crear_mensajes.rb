# El registro de lo que el colegio le escribió a una familia (MOR-186).
#
# ## Por qué una tabla, si ya está en la auditoría
#
# Cuando escribí `MensajesController` dejé anotado que esto «NO es una bandeja:
# no guarda un hilo y no se puede releer un mensaje viejo». Daniel lo leyó al
# revés de como yo lo escribí, y con razón: *«debemos permitir darle seguimiento
# a los correos, ese es otro tema de Gestión importante. Simple, pero que al
# menos diga qué y cuándo se envió»*.
#
# El registro de actividad no sirve para eso. Es una bitácora de QUIÉN HIZO QUÉ,
# ordenada por tiempo y mezclada con altas, bajas y cambios de nota; buscar ahí
# «qué le escribimos a la mamá de Eduardo» es leer trescientas filas. Lo que hace
# falta es la lista de mensajes DE ESA PERSONA, en su ficha.
#
# ## ⚠️ Guarda el CUERPO, y eso es una decisión
#
# En la auditoría deliberadamente NO se guarda —convertiría la bitácora en un
# archivo de correspondencia que ve cualquier administrador—. Acá sí: es
# exactamente lo que se viene a buscar, vive en la ficha de la persona, y quien
# la abre ya podía ver su correo y su teléfono.
class CrearMensajes < ActiveRecord::Migration[8.1]
  def change
    create_table :mensajes do |t|
      t.references :school, null: false, foreign_key: true
      # A quién se le escribió y quién lo escribió. Los dos son `users`: el
      # destinatario puede ser representante hoy y profesor mañana, y el mensaje
      # se le escribió a la PERSONA.
      t.references :destinatario, null: false, foreign_key: { to_table: :users }
      t.references :remitente, null: false, foreign_key: { to_table: :users }

      t.string :asunto, null: false
      t.text :cuerpo, null: false
      # La dirección A LA QUE SE MANDÓ, congelada. Si después se corrige el
      # correo de la persona, el registro tiene que seguir diciendo a dónde fue
      # —que es justo lo que se pregunta cuando alguien dice que no le llegó.
      t.string :correo, null: false

      t.timestamps
    end

    # La consulta es siempre la misma: los mensajes de esta persona, del más
    # nuevo al más viejo.
    add_index :mensajes, [ :destinatario_id, :created_at ]

    # ⚠️ RLS, como las otras 23 tablas de inquilino (MOR-87).
    #
    # Sin esto, `SchoolScoped` sería la ÚNICA capa: un `unscoped`, un
    # `find_by_sql` o una consulta escrita a mano vería la correspondencia de
    # otro colegio con la familia de sus alumnos. Es de las tablas donde la
    # segunda capa más importa.
    #
    # `FORCE` porque el dueño de la tabla no queda exento — es lo que hace que
    # la política se evalúe también para las migraciones y las tareas.
    reversible do |dir|
      dir.up do
        execute "ALTER TABLE mensajes ENABLE ROW LEVEL SECURITY"
        execute "ALTER TABLE mensajes FORCE  ROW LEVEL SECURITY"
        execute <<~SQL.squish
          CREATE POLICY aislamiento_por_colegio ON mensajes
            USING (#{condicion})
            WITH CHECK (#{condicion})
        SQL
      end

      dir.down { execute "DROP POLICY IF EXISTS aislamiento_por_colegio ON mensajes" }
    end
  end

  private

  # La misma condición que las otras tablas (MOR-87).
  def condicion
    <<~SQL.squish
      current_setting('siga.bypass_rls', true) = 'on'
      OR school_id IS NOT DISTINCT FROM NULLIF(current_setting('siga.school_id', true), '')::bigint
    SQL
  end
end
