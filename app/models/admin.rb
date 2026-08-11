class Admin < ApplicationRecord
  include SchoolScoped

  self.primary_key = :user_id

  enum :role, { desarrollador: 0, director: 1, finanzas: 2, coordinador: 3, secretaria: 4 }

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  validates :role, presence: true
end
