# La escala del Artículo 108, también en la base.
#
# > La expresión cuantitativa de la calificación […] se expresará mediante un
# > número entero comprendido en la **escala del uno (1) al veinte (20)**, ambos
# > inclusive.
#
# Las validaciones del modelo ya la exigen, y esto es lo mismo que se hizo con el
# aislamiento (MOR-87): la capa de la app evita el error, la de la base hace que
# el error no tenga consecuencias. Un `update_column`, un `insert_all` o un script
# de importación se saltan las validaciones de ActiveRecord; no se saltan un CHECK.
#
# Importa más de lo que parece porque `MOR-126` va a traer un importador de
# matrícula desde el sistema anterior del colegio, y ese es exactamente el camino
# por el que entra una nota con un 0 o un 25.
#
# `NULL` sigue siendo válido en las columnas que lo admiten: "todavía sin nota"
# no es una nota baja.
#
# Ver MOR-93.
class EnforceGradeScaleOneToTwenty < ActiveRecord::Migration[8.1]
  ESCALA = {
    "activity_grades"   => %w[score],
    "moment_grades"     => %w[final_moment_score],
    "final_grade_books" => %w[annual_average remedial_exam_score final_score]
  }.freeze

  def up
    ESCALA.each do |tabla, columnas|
      columnas.each do |columna|
        add_check_constraint tabla,
                             "#{columna} IS NULL OR (#{columna} >= 1 AND #{columna} <= 20)",
                             name: "#{tabla}_#{columna}_escala_1_20"
      end
    end
  end

  def down
    ESCALA.each do |tabla, columnas|
      columnas.each do |columna|
        remove_check_constraint tabla, name: "#{tabla}_#{columna}_escala_1_20"
      end
    end
  end
end
