class FinalGradeBook < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :subject

  derives_school_from :enrollment
  validates_same_school :subject

  validates :subject_id, uniqueness: { scope: :enrollment_id }
  # Art. 108: la calificación va del 1 al 20, ambos inclusive. `nil` sí es válido
  # —es "todavía sin nota", que no es lo mismo que una nota baja.
  validates :annual_average, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
  validates :remedial_exam_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
  validates :final_score, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_nil: true
end
