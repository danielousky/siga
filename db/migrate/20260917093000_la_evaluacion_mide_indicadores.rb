# Qué INDICADORES mide una evaluación (MOR-136, segunda mitad).
#
# Daniel: *«la idea es que la profesora, a una nueva evaluación, pueda asignarle
# competencias ya creadas y a su vez agregar también otros indicadores»* — y
# después, la regla que decide la forma: *«los indicadores no se repiten entre
# evaluaciones»*.
#
#     HOY     Competency ──1:N──► Indicator
#                  │
#                  │ N:N vía activity_competencies
#                  ▼
#             EvaluationActivity          el indicador NO sabe de la evaluación
#
#     AHORA   Indicator ──N:1──► EvaluationActivity   (opcional)
#
# ## ⚠️ Una COLUMNA y no una tabla intermedia
#
# La primera versión de esto era `activity_indicators`, una N:N. Sobra: si un
# indicador lo mide una sola evaluación, la relación es 1:N y vive en la fila
# del indicador. Una tabla intermedia para una N:1 admite el estado que la
# regla prohíbe —el mismo indicador en dos evaluaciones— y obliga a defenderlo
# con un índice único que la columna ya trae de nacimiento.
#
#     Resuelve problemas de adición
#       ∘ Suma con reagrupación      ──►  Examen del lapso   40 %
#       ∘ Estima antes de calcular   ──►  Examen del lapso
#       ∘ Resuelve en dos pasos      ──►  Taller en equipo   30 %
#       ∘ Compara dos estrategias    ──►  libre
#
# La competencia se repite entre evaluaciones; el indicador la REPARTE.
#
# ## ⚠️ Nulo, y no `null: false`
#
# Un indicador nace en el plan antes de que exista la evaluación que lo mida —
# así se escribe el plan: competencia, indicadores, y después las evaluaciones.
# Nulo es «todavía no lo mide ninguna», que es el estado normal de septiembre y
# además lo que hace visible el trabajo que falta.
#
# Y por eso al borrar una evaluación sus indicadores se SUELTAN, no se borran:
# el texto lo escribió la maestra, la evaluación solo decía cuál medía.
#
# ⚠️ No hace falta política de RLS: `indicators` ya la tiene. Lo que se agrega
# es una columna, no una tabla.
class LaEvaluacionMideIndicadores < ActiveRecord::Migration[8.1]
  def change
    add_reference :indicators, :evaluation_activity, foreign_key: true, null: true
  end
end
