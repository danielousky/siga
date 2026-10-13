# En qué orden se pueden borrar las tablas sin violar una clave foránea.
#
# ## Por qué se CALCULA y no se escribe
#
# `demo:limpiar` tenía la lista a mano, y falló dos veces contra producción:
#
#     1er intento   faltaba `siga_staffs`, que también apunta a `users`
#     2do intento   `importaciones` estaba DESPUÉS de `academic_periods`
#
# Y le faltaban además las cinco tablas de `MOR-136` y `MOR-216`
# —`competencies`, `indicators`, `activity_competencies`, `rubrics`,
# `informes`—, que nacieron después de escribirla. O sea que el tercer intento
# también habría fallado, y el cuarto.
#
# Una lista de dependencias escrita a mano es una copia del esquema que se
# despareja sola. PostgreSQL ya sabe qué apunta a qué: se le pregunta.
#
# ## ⚠️ La maquinaria no se toca
#
# `solid_queue_*` es la cola de trabajos y `schema_migrations` es de Rails.
# Borrarlas no limpia una demo: rompe la instalación.
#
# ## ⚠️ Y los ajustes de la plataforma tampoco
#
# `siga_settings` guarda las cuentas con que cobra SIGA, y `setup` su WhatsApp y
# la dirección de la muestra (spec `del-registro-al-cobro`, decisiones 20, 21 y
# 35). No son de la demo ni de ningún colegio: limpiar una demo y quedarse sin a
# dónde pagar sería borrar la caja registradora junto con la mercancía de
# muestra. Su única clave foránea —quién los cambió— se pone en nulo sola al
# borrarse esa persona.
module OrdenDeBorrado
  NO_SE_TOCAN = %w[
    ar_internal_metadata schema_migrations
    active_storage_attachments active_storage_blobs active_storage_variant_records
    siga_settings setup
  ].freeze

  PREFIJOS_DE_MAQUINARIA = %w[solid_queue_ solid_cache_ solid_cable_].freeze

  class Ciclo < StandardError; end

  def self.calcular(conexion = ActiveRecord::Base.connection)
    tablas = conexion.tables.reject { |t| se_salta?(t) }

    # Qué tabla apunta a qué otra. Una FK a sí misma se ignora: dentro de una
    # tabla el orden lo resuelve el `DELETE`, no nosotros.
    apunta_a = tablas.index_with do |tabla|
      conexion.foreign_keys(tabla).map(&:to_table).uniq
              .select { |otra| tablas.include?(otra) && otra != tabla }
    end

    ordenar(tablas, apunta_a)
  end

  def self.se_salta?(tabla)
    NO_SE_TOCAN.include?(tabla) || tabla.start_with?(*PREFIJOS_DE_MAQUINARIA)
  end

  # Orden topológico por capas: primero las que nadie referencia —las HIJAS—,
  # después las que quedan libres al sacarlas, y así. Por capas y no por
  # recursión para que el resultado sea estable y legible: dos corridas dan la
  # misma lista, que es lo que hace que se pueda revisar en un diff.
  def self.ordenar(tablas, apunta_a)
    orden = []
    pendientes = tablas.dup

    while pendientes.any?
      listas = pendientes.reject do |tabla|
        pendientes.any? { |otra| otra != tabla && apunta_a[otra].include?(tabla) }
      end

      # ⚠️ Sin ninguna lista hay un CICLO, y adivinar ahí es peor que parar.
      if listas.empty?
        raise Ciclo, "ciclo de claves foráneas entre: #{pendientes.sort.join(', ')}"
      end

      orden.concat(listas.sort)
      pendientes -= listas
    end

    orden
  end
end
