class EvaluationActivity < ApplicationRecord
  belongs_to :subject
  belongs_to :section
  belongs_to :evaluation_moment

  has_many :activity_grades, dependent: :restrict_with_error

  validates :description, presence: true
  validates :weight_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :date_scheduled, presence: true
  validate :total_weight_must_not_exceed_100

  private

  def total_weight_must_not_exceed_100
    return unless weight_percentage.present? && section_id.present? && subject_id.present? && evaluation_moment_id.present?

    other_weights = EvaluationActivity
      .where(section_id: section_id, subject_id: subject_id, evaluation_moment_id: evaluation_moment_id)
      .where.not(id: id)
      .sum(:weight_percentage)

    if other_weights + weight_percentage > 100
      errors.add(:weight_percentage, "La suma de porcentajes no puede exceder 100% para esta materia/sección/momento (actual: #{other_weights}%, disponible: #{100 - other_weights}%)")
    end
  end
end
