class MomentGrade < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :subject
  belongs_to :evaluation_moment
  llega_al_anio_por enrollment: :section
  llega_al_nivel_por enrollment: { section: :grade }
  derives_school_from :enrollment
  validates_same_school :subject

  # Art. 108: la calificación va del 1 al 20, ambos inclusive.
  # ⚠️ Una fila tiene NÚMERO o TEXTO, según el nivel — nunca las dos cosas.
  #
  # En Educación Inicial la calificación es descriptiva. Daniel, 10 de
  # septiembre: *«los niños en Inicial no sacan ni A, ni B, ni C, ni PC, ni AP,
  # ni 5, ni 20, entonces la calificación es descriptiva»*.
  #
  #     PRIMARIA · MEDIA          INICIAL
  #     ────────────────          ───────
  #     final_moment_score 16     descripcion «Se integró al grupo…»
  #     descripcion        nil    final_moment_score nil
  #
  # El 1 al 20 del Artículo 108 sigue siendo obligatorio donde aplica: lo que
  # cambia es que Inicial no está bajo ese artículo.
  def con_texto? = enrollment&.section&.grade&.califica_con_texto?

  validates :final_moment_score, presence: true, unless: :con_texto?
  validates :final_moment_score,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 },
            allow_nil: true
  validates :descripcion, presence: true, if: :con_texto?

  # ⚠️ Y la exclusión en las dos direcciones: una nota de primaria no puede
  # llevar texto, ni una de Inicial un número. Sin esto, una fila con las dos
  # cosas pasaría las validaciones de arriba y la boleta tendría que elegir.
  validate :numero_o_texto, :nunca_los_dos
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

  private

  def numero_o_texto
    return if final_moment_score.present? || descripcion.present?

    errors.add(:base, "hay que poner la nota o la valoración")
  end

  def nunca_los_dos
    return unless final_moment_score.present? && descripcion.present?

    errors.add(:base, "una calificación es un número o una valoración, no las dos")
  end
end
