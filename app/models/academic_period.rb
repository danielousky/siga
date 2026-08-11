class AcademicPeriod < ApplicationRecord
  include SchoolScoped

  belongs_to :school

  has_many :sections, dependent: :restrict_with_error
  has_many :evaluation_moments, dependent: :restrict_with_error

  validates :name, :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end
end
