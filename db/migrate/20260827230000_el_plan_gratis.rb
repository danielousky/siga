# El plan gratuito (MOR-156).
#
# ## Por qué hace falta tocar la base y no alcanza con el enum de Ruby
#
# `subscriptions.plan` tiene un `CHECK` que solo admite 0..3. Es lo correcto —un
# plan inventado en la columna es una factura que nadie sabe emitir— y por eso
# agregar un plan es una migración y no una línea de Ruby: la restricción está
# donde tiene que estar.
#
# ## Qué es «gratis» y qué NO es
#
# NO es «todavía no se facturó». Un colegio SIN fila de suscripción tiene acceso
# completo a propósito: es el piloto, el primer mes, el que se está evaluando de
# la mano de alguien. `gratis` es lo contrario — una decisión escrita, visible
# en la cartera, con funciones acotadas:
#
#     libre          cargar alumnos, profesores, materias, secciones, importar
#     con el plan    calificar, pasar lista, emitir papeles, portal de familias
#
# El corte NO es por número de registros: con matrícula promedio de 360 y tope
# en 200, la importación falla en la fila 201 y el colegio queda a medias, con
# un problema de datos, justo cuando debía sentirse poderoso.
class ElPlanGratis < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :subscriptions, name: "subscriptions_plan_valido"
    add_check_constraint :subscriptions, "plan = ANY (ARRAY[0, 1, 2, 3, 4])",
                         name: "subscriptions_plan_valido"
  end

  def down
    remove_check_constraint :subscriptions, name: "subscriptions_plan_valido"
    add_check_constraint :subscriptions, "plan = ANY (ARRAY[0, 1, 2, 3])",
                         name: "subscriptions_plan_valido"
  end
end
