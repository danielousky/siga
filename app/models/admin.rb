class Admin < ApplicationRecord
  self.primary_key = :user_id

  enum role: { desarrollador: 0, director: 1, finanzas: 2, coordinador: 3, secretaria: 4 }

  belongs_to :user
  belongs_to :school

  validates :role, presence: true
end
