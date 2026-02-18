class Address < ApplicationRecord
  belongs_to :user

  validates :estado, :municipio, :parroquia, :location, presence: true
end
