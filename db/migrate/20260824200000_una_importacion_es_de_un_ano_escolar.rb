# Una importación carga la matrícula de UN año escolar (MOR-126).
#
# Sin decirlo, se adivinaba mal. En agosto, `AcademicPeriod.vigente` devuelve el
# año que ESTÁ POR EMPEZAR —que es lo correcto para el resto de la app, porque
# es el que el colegio está preparando—, pero las secciones que la planilla
# nombra pueden ser las del año que acaba de terminar.
#
# El efecto no era un error: era una importación partida. Los alumnos cuya
# sección ya existía caían en 2025-2026 y los de una sección nueva en 2026-2027,
# sin que nadie lo viera.
class UnaImportacionEsDeUnAnoEscolar < ActiveRecord::Migration[8.1]
  def change
    add_reference :importaciones, :academic_period, foreign_key: true
  end
end
