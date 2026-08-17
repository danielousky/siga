# Un lapso tiene fechas, y hasta acá no las tenía (MOR-135).
#
# `evaluation_moments` guardaba nombre y peso. Pero en un colegio venezolano un
# lapso **es** un rango: "Primer lapso, del 16 de septiembre al 20 de diciembre".
# Sin ese dato:
#
#   · no se puede decir cuántos días faltó el alumno EN ESE LAPSO — el boletín
#     del segundo lapso arrastraría las faltas del primero;
#   · no se puede comprobar que una evaluación fechada en marzo no esté colgada
#     del primer lapso, que es un error de carga silencioso y muy fácil de hacer.
#
# Van como opcionales a propósito. Los colegios ya sembrados no las tienen, y
# obligarlas rompería el alta de un lapso antes de que nadie sepa que existen.
# Donde falten, el boletín cuenta la asistencia del año escolar y **lo dice**:
# un número sin su período es un número que no se puede interpretar.
class UnLapsoEsUnRangoDeFechas < ActiveRecord::Migration[8.1]
  def change
    add_column :evaluation_moments, :starts_on, :date
    add_column :evaluation_moments, :ends_on,   :date

    # Buscar los lapsos de un año escolar por fecha es la consulta del boletín.
    add_index :evaluation_moments, [ :academic_period_id, :starts_on ]
  end
end
