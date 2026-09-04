# El profesor guía es de la SECCIÓN, no del grado (MOR-209).
#
# ## La confusión, y por qué importa
#
# `grades.leader_teacher_id` se llamaba «profesor guía» y colgaba del GRADO. En
# un colegio venezolano el guía es de la sección: «1er Año A» tiene su guía y
# «1er Año B» tiene el suyo. Del grado, si acaso, cuelga un COORDINADOR.
#
# No era un nombre mal puesto: tenía consecuencia. La asistencia se filtraba con
#
#     Section.where(grade: Grade.where(leader_teacher_id: ...))
#
# o sea que el guía de «1er Año» pasaba lista de A, B y C — de alumnos que no
# son suyos—, y a los guías de B y C no les aparecía su propia sección.
#
# ## Qué hace esta migración
#
#     grades.leader_teacher_id  →  grades.coordinator_teacher_id   (lo que ya era)
#     sections.leader_teacher_id                                   (nuevo, opcional)
#
# ## ⚠️ Y por qué COPIA el guía del grado a sus secciones
#
# Sin copiar, al terminar la migración ninguna sección tiene guía y **la
# asistencia deja de aparecerle a nadie**: los profesores abren la pantalla y ven
# «Sin secciones a cargo». Un colegio que hoy pasa lista dejaría de hacerlo, sin
# ningún error que lo avise.
#
# La copia no es una adivinanza: es exactamente lo que el sistema hace HOY. El
# guía de «1er Año» ya toma la asistencia de A y de B, así que dejarlo como guía
# de las dos conserva el comportamiento tal cual, y el colegio lo corrige por
# sección cuando quiera. Es lo contrario de adivinar — es no cambiar nada que no
# se haya pedido cambiar.
class ElProfesorGuiaEsDeLaSeccion < ActiveRecord::Migration[8.1]
  def up
    # `coordinator`, no `coordinator_teacher` a secas ni `coordinador`: el enum
    # de `Admin#role` ya tiene un `coordinador` que es otra cosa —un rol
    # administrativo del colegio— y la columna nombra a un `Teacher`.
    rename_column :grades, :leader_teacher_id, :coordinator_teacher_id

    add_column :sections, :leader_teacher_id, :bigint
    add_index  :sections, :leader_teacher_id
    add_foreign_key :sections, :teachers, column: :leader_teacher_id

    # Conservar lo que la app hace hoy. Ver la nota de arriba.
    execute <<~SQL
      UPDATE sections s
         SET leader_teacher_id = g.coordinator_teacher_id
        FROM grades g
       WHERE g.id = s.grade_id
         AND g.coordinator_teacher_id IS NOT NULL
    SQL
  end

  def down
    remove_foreign_key :sections, column: :leader_teacher_id
    remove_column :sections, :leader_teacher_id
    rename_column :grades, :coordinator_teacher_id, :leader_teacher_id
  end
end
