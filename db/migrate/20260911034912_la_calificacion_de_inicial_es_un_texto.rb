# En Educación Inicial la calificación es un TEXTO, no un número.
#
# Daniel, 10 de septiembre de 2026: *«los niños en Inicial no sacan ni A, ni B,
# ni C, ni PC, ni AP, ni 5, ni 20, entonces la calificación es descriptiva»*.
#
#     LO QUE NO HAY                 LO QUE SÍ HAY
#     ─────────────                 ─────────────
#     ponderación                   un TEXTO por área y lapso
#     evaluaciones con peso         el resultado del año: aprobó, directo
#     escala de ningún tipo           «prácticamente con asistir al colegio»
#
# ⚠️ Va en `moment_grades` y NO en una tabla aparte: la boleta, el historial, la
# promoción y la certificación 31059 leen esta tabla. Con dos, cada una de esas
# pantallas tendría que preguntar de qué nivel es el alumno antes de saber dónde
# mirar.
#
# ⚠️ El precio es que una columna que hoy NUNCA es nula pasa a poder serlo. Todo
# lo que haga cuentas con `final_moment_score` sin comprobar que existe se rompe
# con el primer alumno de Inicial. Se recorrió entero; ver el spec, § 7.
#
# ⚠️ Curiosidad: el CHECK **ya** contemplaba el nulo —`score IS NULL OR score
# BETWEEN 1 AND 20`— y era la columna la que lo prohibía. Acá solo se quita ese
# `NOT NULL`.
class LaCalificacionDeInicialEsUnTexto < ActiveRecord::Migration[8.1]
  def change
    change_column_null :moment_grades, :final_moment_score, true
    add_column :moment_grades, :descripcion, :text

    # Una fila tiene número **o** texto, nunca las dos cosas ni ninguna. El
    # modelo lo valida según el nivel; esto lo sostiene también para lo que
    # entre por otra puerta —el importador, una tarea, un `update_column`—.
    add_check_constraint :moment_grades,
                         "(final_moment_score IS NOT NULL AND descripcion IS NULL) OR " \
                         "(final_moment_score IS NULL AND descripcion IS NOT NULL)",
                         name: "moment_grades_numero_o_texto"
  end
end
