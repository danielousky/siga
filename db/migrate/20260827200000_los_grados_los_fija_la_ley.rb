# El orden de los grados sale del catálogo oficial (MOR-153).
#
# ## Por qué hace falta una columna y no alcanza con ordenar por nombre
#
# Un colegio completo tiene catorce grados. Alfabéticamente salen así:
#
#     1er Año · 1er Grado · 1er Nivel · 2do Año · 2do Grado · 2do Nivel · …
#
# Los tres niveles entreverados, que no es una lista: es un acertijo. Y no se
# puede ordenar en Ruby porque el listado se pagina, y Pagy ordena en SQL.
#
# `orden` sale de `GradoOficial` y lo mantiene el modelo. No es un campo que
# alguien llene.
class LosGradosLosFijaLaLey < ActiveRecord::Migration[8.1]
  def up
    add_column :grades, :orden, :integer
    add_index  :grades, [ :school_id, :orden ]

    # ⚠️ SQL crudo y no `Grade.find_each`: `Grade` es `SchoolScoped` y su
    # `default_scope` filtra por `Current.school_id`, que en una migración es
    # nil. Con el modelo, esto recorrería CERO filas y el backfill no se haría
    # —en silencio, que es lo peor—.
    #
    # La normalización se hace en Ruby, con el mismo método que usa el modelo:
    # PostgreSQL no trae `unaccent` instalado y no vale la pena una extensión
    # para catorce comparaciones.
    filas = select_all("SELECT id, name FROM grades").to_a

    filas.each do |fila|
      entrada = GradoOficial.para(fila["name"])
      next if entrada.nil?

      execute "UPDATE grades SET orden = #{entrada.orden} WHERE id = #{fila['id'].to_i}"
    end
  end

  def down
    remove_column :grades, :orden
  end
end
