# Cómo se vuelca `db/structure.sql`.
#
# ⚠️ Sin comentarios (`COMMENT ON …`), y es por la extensión `btree_gist`.
#
# `pg_dump` escribe, junto a cada extensión, un `COMMENT ON EXTENSION`. Y un
# comentario sobre una extensión solo lo puede poner su DUEÑO: en una base donde
# la creó otro rol —el superusuario que corrió `bin/setup`, o el de un proveedor
# de PostgreSQL— cargar el esquema como `siga_app` reventaría en esa línea, con
# «must be owner of extension», por un texto que no le sirve a nadie.
#
# El archivo no tenía ningún comentario antes de esto, así que no se pierde nada.
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = [ "--no-comments" ]
