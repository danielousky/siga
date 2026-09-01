class MomentGrade < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :subject
  belongs_to :evaluation_moment
  llega_al_anio_por enrollment: :section

  derives_school_from :enrollment
  validates_same_school :subject

  # Art. 108: la calificación va del 1 al 20, ambos inclusive.
  validates :final_moment_score, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  validates :evaluation_moment_id, uniqueness: { scope: [:enrollment_id, :subject_id] }

  # De dónde salió esta calificación.
  #
  # `calculada`   la produjo `GradeCalculator` a partir de las actividades del
  #               lapso. Es el caso normal y se rehace sola cada vez que alguien
  #               guarda o borra una nota.
  # `importada`   la trajo el colegio de su sistema anterior. **No tiene
  #               actividades debajo y no las va a tener**: las cinco
  #               evaluaciones que la produjeron están en papel, o se perdieron.
  #
  # ⚠️ La distinción existe porque el calculador BORRA las calificaciones sin
  # respaldo, y hace bien —una nota de lapso huérfana contaría en el promedio
  # anual para siempre—. Lo que faltaba era separar «sin respaldo» de «con un
  # respaldo que no está acá». Ver `GradeCalculator`.
  enum :origen, { calculada: 0, importada: 1 }
end
