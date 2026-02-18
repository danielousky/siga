class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :address, dependent: :destroy
  has_one :student, dependent: :destroy
  has_one :teacher, dependent: :destroy
  has_one :admin, dependent: :destroy

  validates :id_card, uniqueness: true, allow_nil: true
  validates :name, :last_name, presence: true
end
