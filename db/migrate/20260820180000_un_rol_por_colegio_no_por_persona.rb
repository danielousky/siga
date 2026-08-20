# Una persona podía ser alumno en UN SOLO colegio de toda la plataforma.
#
# No fue una decisión: es la consecuencia de que `students` usara `user_id` como
# clave primaria. Con eso, `has_one :student` en `User` es literal — no caben dos
# filas para la misma persona, ni aunque sean de colegios distintos.
#
# `representatives` ya tenía la forma correcta (`id` propio + ÚNICO
# `(user_id, school_id)`), así que una madre con hijos en dos planteles sí podía
# ser representante en los dos. La misma pregunta estaba respondida de dos formas
# dentro del mismo modelo; esta migración aplica a los otros tres roles el patrón
# que ya funcionaba.
#
# Un alumno que se cambia de colegio es el caso NORMAL en Venezuela, no el raro:
# la cédula escolar existe justamente porque el alumno la conserva al mudarse de
# plantel. Sin esto, el importador del colegio nuevo choca contra una fila que el
# RLS le impide ver.
#
# ── El orden, que es lo único delicado ──────────────────────────────────────
#
# Cinco claves foráneas apuntan hoy a la PK vieja:
#
#     enrollments.student_id  activity_grades.student_id
#     student_representatives.student_id
#     grades.leader_teacher_id  teacher_sections.teacher_id
#
# Se agrega la columna nueva y se rellena ANTES de mover ninguna FK, para que en
# ningún momento exista una referencia colgando. Recién cuando todas apuntan a la
# columna nueva se cambia la clave primaria.
#
# El RLS no entra en esto: sus políticas filtran por `school_id`, no por la PK.
#
# Ver MOR-138.
class UnRolPorColegioNoPorPersona < ActiveRecord::Migration[8.1]
  # tabla de rol => las FK que la referencian
  ROLES = {
    students: {
      enrollments: :student_id,
      activity_grades: :student_id,
      student_representatives: :student_id
    },
    teachers: {
      grades: :leader_teacher_id,
      teacher_sections: :teacher_id
    },
    admins: {}
  }.freeze

  def up
    ROLES.each do |rol, referencias|
      # 1 · soltar las FK que dependen de la PK vieja.
      #
      #     PostgreSQL no deja borrar una clave primaria mientras algo la
      #     referencie: `cannot drop constraint students_pkey because other
      #     objects depend on it`. Las columnas y sus valores se quedan; lo único
      #     que se va es la restricción.
      referencias.each { |tabla, columna| remove_foreign_key tabla, column: columna }

      # 2 · mover la clave primaria a una columna propia.
      #     `user_id` sigue existiendo con sus datos, solo deja de ser la clave.
      execute "ALTER TABLE #{rol} DROP CONSTRAINT #{rol}_pkey"
      add_column rol, :id, :primary_key

      # 3 · remapear cada FK de `user_id` al `id` nuevo, con una columna auxiliar.
      referencias.each do |tabla, columna|
        add_column tabla, :rol_id_nuevo, :bigint
        execute <<~SQL
          UPDATE #{tabla} t
             SET rol_id_nuevo = r.id
            FROM #{rol} r
           WHERE r.user_id = t.#{columna}
        SQL

        # Si una fila TENÍA valor y no se mapeó, es preferible que la migración
        # muera acá y no que se descubra después con notas huérfanas.
        #
        # La condición mira `#{columna} IS NOT NULL`: hay FK opcionales
        # —`grades.leader_teacher_id`, que son los grados sin profesor guía— y ahí
        # el nulo es un dato legítimo, no una fila perdida.
        huerfanas = select_value(
          "SELECT count(*) FROM #{tabla} WHERE #{columna} IS NOT NULL AND rol_id_nuevo IS NULL"
        )
        raise "#{tabla}.#{columna}: #{huerfanas} filas sin mapear" if huerfanas.to_i.positive?

        admite_nulos = columns(tabla).find { |c| c.name == columna.to_s }.null

        remove_column tabla, columna
        rename_column tabla, :rol_id_nuevo, columna
        change_column_null tabla, columna, false unless admite_nulos
      end

      # 4 · la persona sigue siendo única DENTRO de cada colegio, que es lo que la
      #     PK vieja garantizaba de más: antes lo era en toda la plataforma.
      add_index rol, [ :user_id, :school_id ], unique: true

      referencias.each { |tabla, columna| add_foreign_key tabla, rol, column: columna }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Volver atrás exigiría decidir qué colegio conserva a cada persona con " \
          "más de un rol, y eso no es una decisión que pueda tomar una migración."
  end
end
