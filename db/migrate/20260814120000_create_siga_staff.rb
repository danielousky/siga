# El equipo de SIGA deja de pertenecer a un colegio (MOR-133).
#
# ## El problema que resuelve
#
# Hasta ahora "la gente de SIGA" era un `Admin` con rol `desarrollador`, y un
# `Admin` **cuelga de un colegio**:
#
#     Admin.create!(user: yo, school: school_bolivar, role: :desarrollador)
#                                    ↑
#                          ¿por qué el equipo de SIGA
#                          pertenece a un colegio?
#
# Esa confusión no era teórica: produjo **cuatro agujeros** en dos días. El
# controller de `/demo_requests`, la vista del panel que seguía contando las
# solicitudes pendientes, el `School.all` de los formularios y la columna
# "Escuela" de los listados. Cada uno se tapó por separado, y el siguiente
# apareció en otra pantalla.
#
# ## Sin `school_id`, y eso es todo el punto
#
# Esta tabla **no lleva colegio** — como `demo_requests` y como `users`. No es
# dato DE un inquilino: es dato de la plataforma. Por eso tampoco lleva RLS: no
# hay `school_id` que filtrar, y ponerle una política sería fingir que pertenece
# a alguien.
#
# El test estructural de `MOR-90` solo exige RLS a las tablas que TIENEN
# `school_id`, así que esta pasa sin excepciones escritas a mano. Que el
# criterio se sostenga solo es lo que hace que no haya que recordarlo.
class CreateSigaStaff < ActiveRecord::Migration[8.1]
  def change
    create_table :siga_staffs do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # Qué puede hacer dentro de la administración de SIGA. Nada que ver con
      # los roles de un colegio (director, secretaria…): son dos ejes distintos,
      # y meterlos en el mismo enum fue exactamente lo que produjo el agujero.
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :siga_staffs, "role IN (0, 1)", name: "siga_staffs_role_valido"
  end
end
