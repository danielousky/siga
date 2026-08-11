# Las migraciones corren sin contexto de colegio, y con el RLS activo eso
# significa que verían CERO filas: una migración de datos que hiciera un UPDATE
# no actualizaría nada, en silencio.
#
# No alcanza con "que las migraciones sean DDL": las de MOR-82 a MOR-85 hacen
# backfill, y las que vengan probablemente también.
#
# Así que cada migración corre dentro de `Current.sin_aislamiento`. Es explícito
# y acotado: solo la migración, no la aplicación.
#
# ⚠️ Esto NO es un permiso general. La regla sigue siendo que sin contexto no se
# ve nada; esta es la excepción declarada para el único lugar donde mirar todos
# los colegios es la tarea.
#
# Ver MOR-87.
Rails.application.config.to_prepare do
  ActiveRecord::Migration.prepend(
    Module.new do
      def exec_migration(conn, direction)
        Current.sin_aislamiento { super }
      end
    end
  )
end
