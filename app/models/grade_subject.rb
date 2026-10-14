class GradeSubject < ApplicationRecord
  include SchoolScoped
  llega_al_nivel_por :grade

  belongs_to :grade
  belongs_to :subject

  derives_school_from :grade
  validates_same_school :subject

  validates :subject_id, uniqueness: { scope: :grade_id }

  # La CARGA HORARIA: cuántas horas a la semana lleva esta área en este grado
  # (spec `horarios`). Es contra lo que el horario de una sección cuenta sus
  # «2 de 4».
  #
  # Opcional: vacía quiere decir «todavía nadie lo dijo», que no es cero.
  # `CargaHorariaOficial` propone la del plan de 2017 y el colegio la corrige.
  #
  # ⚠️ No tiene año, como el pensum del que cuelga. Cambiarla mueve el «faltan»
  # también de los años anteriores, y se acepta: es un aviso de planificación,
  # no un documento emitido.
  HORAS_POSIBLES = (1..60)

  validates :weekly_hours, numericality: { only_integer: true, in: HORAS_POSIBLES,
                                           message: "va de #{HORAS_POSIBLES.first} a #{HORAS_POSIBLES.last}" },
                           allow_nil: true
end
