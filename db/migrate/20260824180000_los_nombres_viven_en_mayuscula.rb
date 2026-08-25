# Los nombres se guardan en MAYÚSCULA (MOR-126).
#
# Es la forma de los documentos: la cédula, la partida de nacimiento y las
# planillas del MPPE vienen así, y la planilla que manda un colegio también.
#
# Sin esto, el importador dejaría a los alumnos que llegan por planilla en
# MAYÚSCULA y a los cargados a mano en Tipo Título — desparejos en el mismo
# listado, y sin forma de saber cuál es cuál.
#
# Lo que se VE no cambia: `nombre_completo`, `apellidos` y `apellidos_y_nombres`
# devuelven Tipo Título, así que las pantallas y los PDFs se ven igual que
# antes. Lo que cambia es qué hay en la columna.
#
# `upper()` de PostgreSQL respeta los acentos en UTF-8: `upper('josé')` da
# `'JOSÉ'`, no `'JOSé'`.
class LosNombresVivenEnMayuscula < ActiveRecord::Migration[8.1]
  COLUMNAS = %w[first_name last_name second_last_name].freeze

  def up
    COLUMNAS.each do |columna|
      execute "UPDATE users SET #{columna} = upper(#{columna}) WHERE #{columna} IS NOT NULL"
    end
  end

  # Irreversible a propósito, y no por pereza: de «DE LA CRUZ» no se puede
  # recuperar si la persona lo había escrito «de la Cruz» o «De La Cruz». La
  # información de la caja original se perdió al subirla.
  def down
    raise ActiveRecord::IrreversibleMigration,
          "La caja original de cada nombre no se guardó en ningún lado."
  end
end
