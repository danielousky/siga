# Los pasos que un colegio decidió NO hacer (MOR-154).
#
# ## Por qué esta columna es la única del arranque
#
# La puesta en marcha no guarda progreso: se DEDUCE de los datos. ¿Hay grados?
# ¿Hay período? ¿Hay alumnos? Una bandera `pasos_completados` se rompe el primer
# día —la secretaria carga las materias por el menú y el tablero sigue diciendo
# «pendiente»—, y se rompe en silencio.
#
# Pero hay una cosa que no se puede deducir: **«no aplica»**. Un colegio sin
# departamentos se ve idéntico a uno que todavía no los cargó. Eso sí hay que
# preguntarlo y recordarlo.
#
# Es jsonb y no una columna por paso porque los pasos opcionales van a cambiar,
# y no vale una migración cada vez. Es un arreglo de claves, nada más.
class LoUnicoQueElArranqueGuarda < ActiveRecord::Migration[8.1]
  def change
    add_column :schools, :pasos_omitidos, :jsonb, default: [], null: false
  end
end
