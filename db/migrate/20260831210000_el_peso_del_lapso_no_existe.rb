# El peso de un lapso no significa nada (MOR-164).
#
# ## Por qué se borra
#
# El Artículo 111 del Reglamento de la LOE es explícito: la calificación
# definitiva **se obtiene del promedio** de las calificaciones de los tres
# lapsos. Promedio, no promedio ponderado. Los tres pesan igual porque son un
# promedio, no porque tengan un peso de 33,33 % cada uno.
#
# Daniel lo dijo en una línea: *«el porcentaje de los lapsos no importa; al final
# lo que voy a guardar es la nota de cada estudiante en cada lapso, y el total lo
# obtengo de calcular el promedio»*.
#
# La columna ya estaba declarada como decorativa en `GradeCalculator` —«no
# interviene en ningún cálculo»— y aun así:
#
#   · se le pedía al usuario en el formulario del lapso
#   · se validaba `presence` y `> 0`
#   · tenía una validación de que los pesos del período sumaran ≤ 100
#
# O sea: un campo que no hace nada podía **impedir crear un lapso**. Y ya había
# causado un incidente: la validación de la suma miraba TODOS los períodos de la
# plataforma, así que un colegio que llegara a 100 % dejaba a los demás sin poder
# crear momentos de evaluación. Se arregló acotándola al período; el arreglo
# correcto es que la columna no exista.
#
# ## Lo que sí es 70/30, y no es esto
#
# El mismo Artículo 111 dice que la nota de un lapso se forma con 70 % de
# evaluaciones parciales más 30 % de la evaluación final del lapso. Eso vive en
# `EvaluationActivity#weight_percentage`, que sí entra en el cálculo y se queda.
class ElPesoDelLapsoNoExiste < ActiveRecord::Migration[8.1]
  def up
    remove_column :evaluation_moments, :weight
  end

  # Al volver atrás, los lapsos de cada período reparten 100 entre sí — que es
  # lo único que ese número podía significar.
  def down
    add_column :evaluation_moments, :weight, :decimal, precision: 5, scale: 2

    execute <<~SQL
      UPDATE evaluation_moments AS em
         SET weight = ROUND(100.0 / (
               SELECT count(*) FROM evaluation_moments AS otros
                WHERE otros.academic_period_id = em.academic_period_id), 2)
    SQL
  end
end
