# Tres índices únicos se perdieron al cambiar la clave primaria de los roles.
#
# `MOR-138` remapeó las FK con la técnica de columna auxiliar: agregar
# `rol_id_nuevo`, copiar, BORRAR la columna vieja, renombrar. Y borrar una
# columna se lleva puesto TODO índice que la mencione — incluidos tres que no
# tenían nada que ver con esa migración:
#
#   enrollments             (section_id, student_id)
#   activity_grades         (evaluation_activity_id, student_id)
#   student_representatives (representative_id, student_id)
#
# Los dos primeros son los que duelen: sin ellos se puede inscribir dos veces al
# mismo alumno en una sección, y cargarle DOS notas a la misma evaluación. El
# cálculo del promedio las sumaría las dos.
#
# La lección, y por eso queda escrita: al recrear una columna hay que mirar qué
# ÍNDICES la mencionaban, no solo qué claves foráneas la referenciaban. Las FK
# las restauramos porque estaban en la lista; los índices no estaban en ninguna.
class RestaurarLosIndicesUnicosQueSePerdieron < ActiveRecord::Migration[8.1]
  def change
    add_index :enrollments, [ :section_id, :student_id ],
              unique: true, name: "index_enrollments_on_section_id_and_student_id"

    add_index :activity_grades, [ :evaluation_activity_id, :student_id ],
              unique: true, name: "index_activity_grades_on_activity_and_student"

    add_index :student_representatives, [ :representative_id, :student_id ],
              unique: true, name: "index_student_representatives_unicos"
  end
end
