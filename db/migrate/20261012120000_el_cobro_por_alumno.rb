# El cobro pasa a ser POR ALUMNO (spec: `docs/specs/del-registro-al-cobro.md`).
#
# ## Qué cambia en la tabla
#
#     plan               basico · estandar · premium · a_convenir · gratis
#                   ──►  gratis · por_alumno
#     precio_mensual     entero  ──►  decimal: 0,30 por alumno da centavos
#                                     (347 alumnos son 104,10 $)
#     precio_por_alumno  nuevo, y CONGELADO: el colegio conserva el precio con
#     minimo_mensual     que entró aunque la constante suba (decisión 17)
#
# Las bandas murieron el 12 de octubre de 2026: el alumno 151 duplicaba la
# factura, y el colegio de 800 pagaba menos por alumno que el de 150. Sus
# valores —0 a 3— no se reusan: el `CHECK` los deja fuera.
#
# ## ⚠️ Y ningún colegio queda sin fila (decisión 16)
#
# Hasta hoy «sin suscripción» era acceso completo y sin fecha: es lo que recibía
# el colegio dado de alta desde `/siga`. Era la puerta por la que se entraba a
# todo, gratis y para siempre. Cada colegio sin fila nace aquí en `gratis`,
# igual que el que se registra.
#
# ⚠️ En producción no hay suscripciones. En una base local, las sembradas por
# bandas pasan a `por_alumno` con el precio de hoy: nadie pagó con las bandas,
# así que no hay precio viejo que respetar.
class ElCobroPorAlumno < ActiveRecord::Migration[8.1]
  def up
    # ⚠️ El RLS también filtra a quien migra si no es superusuario —en
    # producción, el rol de la app—, y un UPDATE sin colegio en contexto no toca
    # NINGUNA fila y no avisa. El bypass va LOCAL: muere con la transacción de
    # la migración.
    execute "SET LOCAL siga.bypass_rls = 'on'"

    remove_check_constraint :subscriptions, name: "subscriptions_plan_valido"

    change_column :subscriptions, :precio_mensual, :decimal, precision: 10, scale: 2
    add_column :subscriptions, :precio_por_alumno, :decimal, precision: 6, scale: 2
    add_column :subscriptions, :minimo_mensual, :decimal, precision: 8, scale: 2

    execute <<~SQL.squish
      UPDATE subscriptions
         SET plan = 5, precio_por_alumno = 0.30, minimo_mensual = 39
       WHERE plan IN (0, 1, 2, 3)
    SQL

    execute <<~SQL.squish
      INSERT INTO subscriptions (school_id, plan, status, precio_mensual, vigente_desde,
                                 dias_de_gracia, notas, created_at, updated_at)
      SELECT schools.id, 4, 0, 0, CURRENT_DATE, 15,
             'Gratis: el colegio no tenía suscripción el día del cobro por alumno.',
             NOW(), NOW()
        FROM schools
       WHERE NOT EXISTS (SELECT 1 FROM subscriptions WHERE subscriptions.school_id = schools.id)
    SQL

    add_check_constraint :subscriptions, "plan = ANY (ARRAY[4, 5])",
                         name: "subscriptions_plan_valido"
  end

  # Vuelve a la forma de antes, no a los datos de antes: `por_alumno` cae en
  # `estandar`, la banda del colegio promedio, y las filas `gratis` que se
  # crearon se quedan. Ningún colegio queda sin suscripción por deshacer esto.
  def down
    execute "SET LOCAL siga.bypass_rls = 'on'"

    remove_check_constraint :subscriptions, name: "subscriptions_plan_valido"
    execute "UPDATE subscriptions SET plan = 1 WHERE plan = 5"

    remove_column :subscriptions, :minimo_mensual
    remove_column :subscriptions, :precio_por_alumno
    change_column :subscriptions, :precio_mensual, :integer,
                  using: "ROUND(precio_mensual)::integer"

    add_check_constraint :subscriptions, "plan = ANY (ARRAY[0, 1, 2, 3, 4])",
                         name: "subscriptions_plan_valido"
  end
end
