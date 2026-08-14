class Grade < ApplicationRecord
  include SchoolScoped

  enum :level, { primaria: 0, secundaria: 1 }

  # Con qué escala se califica este grado (MOR-129).
  #
  # Cuelga del GRADO y no del colegio: un mismo colegio tiene primaria por
  # literal y bachillerato por número, y las dos escalas conviven adentro. Con
  # esto en `School` ese colegio —que es el caso común— no se podría representar.
  #
  # `level` da el valor por defecto y nada más. Son preguntas distintas: `level`
  # es a qué nivel pertenece el grado, `escala` es cómo se escribe su nota. La
  # certificación EMG de media general tiene dos áreas por literal, así que ni
  # siquiera dentro de un nivel la respuesta es única.
  enum :escala, { numerica: 0, literal: 1 }, prefix: :escala

  belongs_to :school
  belongs_to :leader_teacher, class_name: "Teacher", primary_key: :user_id, optional: true

  # El profesor guía tiene que ser del mismo colegio que el grado.
  validates_same_school :leader_teacher

  has_many :grade_subjects, dependent: :destroy
  has_many :subjects, through: :grade_subjects
  has_many :sections, dependent: :restrict_with_error

  # El nombre es único dentro del colegio, no en toda la plataforma: dos colegios
  # tienen cada uno su "1er Año" sin saber que el otro existe.
  validates :name, presence: true, uniqueness: { scope: :school_id }
  validates :level, presence: true

  # Un grado nuevo nace con la escala que le corresponde por nivel, y quien
  # quiera lo cambia. Sin esto, cada grado de primaria que alguien cree se
  # llevaría el default de la columna —numérica— y el colegio volvería al
  # problema que este issue arregla, de a un grado por vez.
  after_initialize :escala_por_defecto_del_nivel, if: :new_record?

  private

  def escala_por_defecto_del_nivel
    return if attribute_present?(:escala) && escala_changed?

    self.escala = primaria? ? :literal : :numerica
  end
end
