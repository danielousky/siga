# Una importación es de matrícula o de pensum (MOR-126).
#
# Son planillas distintas y producen cosas distintas:
#
#   matrícula   una fila = un ALUMNO      → alumno, representante, inscripción
#   pensum      una fila = una MATERIA    → materia, pensum del grado, profesor,
#               dictada en una sección       y su asignación
#
# Lo que comparten es todo lo demás: el lector, el mapeo de columnas, la
# previsualización y el reporte. Por eso es un campo y no otra tabla.
class UnaImportacionTieneTipo < ActiveRecord::Migration[8.1]
  def change
    add_column :importaciones, :tipo, :integer, null: false, default: 0
    add_check_constraint :importaciones, "tipo IN (0, 1)", name: "importaciones_tipo_valido"
  end
end
