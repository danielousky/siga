class DemoRequest < ApplicationRecord
  # Enums para el estado de la solicitud
  enum status: {
    pendiente: 0,
    contactado: 1,
    demo_programado: 2,
    completado: 3,
    rechazado: 4
  }

  # Validaciones
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :institution, presence: true, length: { minimum: 2, maximum: 200 }
  validates :phone, format: { with: /\A[0-9\-\+\(\)\s]+\z/, allow_blank: true }
  validates :message, length: { maximum: 1000 }

  # Normalizar email a minúsculas
  before_validation :normalize_email

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: :pendiente) }

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
