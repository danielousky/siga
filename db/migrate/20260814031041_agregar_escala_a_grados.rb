# Con qué escala califica cada grado (MOR-129).
#
# No cuelga del colegio y eso es la decisión, no un detalle: un mismo colegio
# tiene primaria por literal y bachillerato por número, y Cyndi lo describe como
# un problema real —"que vengas de primaria hablando cualitativamente y después
# boom, pases a bachillerato"—. Con la escala en `schools` ese colegio no se
# puede representar.
#
# `grades.level` ya existía, pero dice **a qué nivel pertenece** el grado, no
# **cómo se califica**. No son lo mismo: la certificación EMG de media general
# tiene dos áreas por literal (Orientación y Convivencia, y Participación en
# Grupos de Creación). El nivel da el valor por defecto; la escala se declara.
class AgregarEscalaAGrados < ActiveRecord::Migration[8.1]
  def up
    add_column :grades, :escala, :integer, null: false, default: 0

    # Los grados que ya existen arrancan con la escala que les corresponde por
    # nivel: primaria por literal, media por número.
    execute <<~SQL.squish
      UPDATE grades SET escala = 1 WHERE level = 0
    SQL

    add_check_constraint :grades, "escala IN (0, 1)", name: "grades_escala_valida"
  end

  def down
    remove_check_constraint :grades, name: "grades_escala_valida"
    remove_column :grades, :escala
  end
end
