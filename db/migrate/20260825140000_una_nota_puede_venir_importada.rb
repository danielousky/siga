# Una calificación puede venir importada, y entonces nadie la recalcula (MOR-126, tanda 3).
#
# ## El problema, medido antes de escribir esto
#
# Un colegio que llega a SIGA trae «Matemática · 1er lapso 15 · 2do 14 · 3er 16».
# Lo que NO trae son las cinco evaluaciones que produjeron cada lapso: eso está
# en papel, o se perdió. Así que la nota histórica no tiene actividades debajo.
#
# Y `GradeCalculator` borra exactamente eso:
#
#     nota histórica cargada:   1
#     tras UN recálculo:        0     ← destruida
#
# No es un bug: es la regla que hace que «sin nota» no sea cero. Una calificación
# de lapso sin actividades que la respalden es basura —quedaría contando en el
# promedio anual para siempre— y por eso se borra. La regla está bien; lo que
# faltaba era distinguir «sin respaldo» de «con un respaldo que no está acá».
#
# ## Por qué una columna y no deducirlo
#
# Se podría inferir del año escolar («si el período ya terminó, no recalcules»),
# pero eso protegería también notas que SÍ hay que borrar, y haría que la regla
# cambie sola con el paso del tiempo. Explícito y grepeable, como
# `Current.sin_aislamiento`: si algún día alguien se pregunta por qué esta nota
# no se recalcula, la respuesta está en la fila.
class UnaNotaPuedeVenirImportada < ActiveRecord::Migration[8.1]
  def change
    # `calculada` es 0 para que las filas que ya existen queden bien sin tocarlas:
    # todo lo que hay hoy lo produjo el cálculo.
    add_column :moment_grades,     :origen, :integer, null: false, default: 0
    add_column :final_grade_books, :origen, :integer, null: false, default: 0

    # Buscar «qué notas de este colegio son importadas» es la pregunta que se
    # hace al revisar un import, y sin índice recorre la tabla entera.
    add_index :moment_grades,     [ :school_id, :origen ]
    add_index :final_grade_books, [ :school_id, :origen ]
  end
end
