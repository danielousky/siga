class DemoRequest < ApplicationRecord
  # Enums para el estado de la solicitud
  enum :status, {
    pendiente: 0,
    contactado: 1,
    demo_programado: 2,
    completado: 3,
    rechazado: 4
  }

  # Qué usa hoy la institución. Opcional.
  # Preguntamos por la FORMA de la solución, no por el proveedor: el corte que
  # predice la venta es "sin acceso web" vs "con portal", y así el formulario
  # no le hace publicidad gratis a la competencia. El nombre del sistema, si lo
  # saben, entra por current_system_detail.
  enum :current_system, {
    ninguno: 0,
    planillas: 1,
    escritorio: 2,
    portal_web: 3,
    otro: 4
  }, prefix: :sistema

  CURRENT_SYSTEM_LABELS = {
    "ninguno"    => "Ninguno, todo en papel",
    "planillas"  => "Cuadernos y hojas de cálculo",
    "escritorio" => "Un sistema instalado en las computadoras del colegio (funciona sin internet)",
    "portal_web" => "Un sistema al que se entra por internet, desde cualquier lugar (necesita internet)",
    "otro"       => "Otro"
  }.freeze

  # Versión corta para tablas y gráficos del panel.
  CURRENT_SYSTEM_SHORT = {
    "ninguno"    => "Papel",
    "planillas"  => "Cuadernos y Excel",
    "escritorio" => "Instalado · sin internet",
    "portal_web" => "Web · con internet",
    "otro"       => "Otro"
  }.freeze

  # Los que ya pagan software pero no tienen acceso web: el mejor prospecto.
  scope :sin_acceso_web, -> { where(current_system: [:escritorio, :planillas]) }

  # Validaciones
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :institution, presence: true, length: { minimum: 2, maximum: 200 }
  validates :phone, format: { with: /\A[0-9\-\+\(\)\s]+\z/, allow_blank: true }
  validates :message, length: { maximum: 1000 }
  validates :current_system_detail, length: { maximum: 120 }

  # Normalizar email a minúsculas
  before_validation :normalize_email
  before_validation :normalize_current_system_detail

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: :pendiente) }
  scope :answered_system, -> { where.not(current_system: nil) }

  def current_system_label
    CURRENT_SYSTEM_LABELS[current_system] || "Sin responder"
  end

  def current_system_short
    CURRENT_SYSTEM_SHORT[current_system] || "Sin responder"
  end

  # Para la tabla del panel: etiqueta corta + el nombre que hayan indicado.
  def current_system_summary
    return current_system_short if current_system_detail.blank?

    "#{current_system_short} (#{current_system_detail})"
  end

  # Distribución de respuestas, para dimensionar cuántos vienen sin sistema.
  def self.current_system_distribution
    answered = answered_system.group(:current_system).count
    total    = answered.values.sum
    return {} if total.zero?

    answered
      .sort_by { |_system, count| -count }
      .to_h { |system, count| [system, { count: count, percent: (count * 100.0 / total).round(1) }] }
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def normalize_current_system_detail
    self.current_system_detail = current_system_detail.strip.presence if current_system_detail.present?
  end
end
