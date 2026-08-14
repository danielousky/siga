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
  #
  # El obligatorio es el TELÉFONO, no el correo (MOR-135). En un colegio
  # venezolano la conversación ocurre por WhatsApp; el correo institucional, si
  # existe, lo abre la secretaria cuando puede. Pedir como requisito el canal
  # muerto y como opcional el vivo es perder al prospecto en el formulario.
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :institution, presence: true, length: { minimum: 2, maximum: 200 }
  validates :phone, presence: true, format: {
    with: /\A[0-9\-\+\(\)\s]{7,}\z/,
    message: "debe tener al menos 7 dígitos"
  }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :message, length: { maximum: 1000 }
  validates :current_system_detail, length: { maximum: 120 }

  # Normalizar email a minúsculas
  before_validation :normalize_email
  before_validation :normalize_current_system_detail
  before_validation :fijar_telefono_normalizado

  # Registrar una solicitud que llega del formulario público.
  #
  # ## Insistir no es un error
  #
  # Antes esto era `DemoRequest.create`, con `validates :email, uniqueness`
  # detrás. Una directora que escribía en marzo y volvía a escribir en junio
  # recibía **"Email ya está en uso"** — el sistema contestándole que se
  # callara, justo al prospecto más caliente que hay.
  #
  #     ANTES                              AHORA
  #     ─────                              ─────
  #     1.ª vez  → gracias                 1.ª vez  → gracias · veces = 1
  #     2.ª vez  → ✗ "ya está en uso"      2.ª vez  → gracias · veces = 2 ↑
  #
  # La identidad del prospecto es el TELÉFONO, no el correo: el correo puede
  # faltar, y dos personas del mismo colegio son dos prospectos distintos con
  # dos números. Se comparan los últimos 10 dígitos, así `0424-1234567`,
  # `+58 424 1234567` y `(0424) 123 45 67` son la misma persona.
  #
  # Una solicitud ya cerrada (`completado` / `rechazado`) NO se reabre: quien
  # ya tuvo su demo y vuelve a escribir un año después está pidiendo otra cosa,
  # y pisar el historial de la primera borraría lo que pasó.
  def self.registrar(atributos)
    solicitud = nueva_o_insistencia(atributos)
    solicitud.save
    solicitud
  end

  # Los últimos 10 dígitos, y nada más. Un número venezolano se escribe de media
  # docena de formas —`0424-1234567`, `+58 424 1234567`, `0424 123 45 67`— y las
  # tres terminan en `4241234567`. Comparar por ahí es lo que hace que la segunda
  # solicitud de la misma directora se reconozca como insistencia.
  def self.normalizar_telefono(phone)
    digitos = phone.to_s.gsub(/\D/, "")
    digitos.length >= 7 ? digitos.last(10) : nil
  end

  def self.nueva_o_insistencia(atributos)
    numero   = normalizar_telefono(atributos[:phone])
    anterior = numero && where(telefono_normalizado: numero)
                           .where(status: [ :pendiente, :contactado ])
                           .order(created_at: :desc).first

    return new(atributos) unless anterior

    # Lo que trae de nuevo pisa lo viejo; lo que viene en blanco no borra lo que
    # ya se sabía. Alguien que la segunda vez no puso el correo no debería
    # perder el que dio la primera.
    anterior.assign_attributes(atributos.compact_blank)
    anterior.veces += 1
    anterior
  end
  private_class_method :nueva_o_insistencia

  # Insistió: el prospecto más caliente del panel.
  def insistente? = veces > 1

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

  def fijar_telefono_normalizado
    self.telefono_normalizado = self.class.normalizar_telefono(phone)
  end
end
