class EvaluationMoment < ApplicationRecord
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error

  validates :name, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate :total_weight_must_not_exceed_100

  private

  def total_weight_must_not_exceed_100
    return unless weight.present?

    other_weights = EvaluationMoment.where.not(id: id).sum(:weight)
    if other_weights + weight > 100
      errors.add(:weight, "La suma total de pesos no puede exceder 100% (actual: #{other_weights}%, disponible: #{100 - other_weights}%)")
    end
  end
end
