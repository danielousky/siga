class School < ApplicationRecord
  # El logotipo del colegio: su identidad, y tiene que aparecer en todos lados
  # —incluidos los documentos oficiales que la familia se lleva en la mano.
  #
  # Un boletín con el escudo del colegio ES el boletín del colegio. Sin él, el
  # papel parece de la empresa de software, y lo que el colegio está entregando
  # es SU documento.
  #
  # ## Por qué archivo adjunto y no una URL
  #
  # Una URL apunta a un servidor ajeno: el día que el colegio rehace su web, el
  # logo desaparece de todos los boletines ya emitidos. Y en un PDF hace falta
  # el archivo, no un enlace — Prawn dibuja bytes.
  has_one_attached :logo

  FORMATOS_DE_LOGO = %w[image/png image/jpeg].freeze
  PESO_MAXIMO_DEL_LOGO = 2.megabytes

  validate :logo_dibujable

  # Lo que Prawn puede dibujar en un PDF, o `nil`.
  #
  # Devuelve `nil` en vez de explotar a propósito: un documento oficial no se
  # puede caer porque alguien subió un logo raro. Sale sin escudo, que es feo
  # pero sirve; sin boletín, la familia se queda sin nada.
  def logo_para_pdf
    return nil unless logo.attached?
    return nil unless FORMATOS_DE_LOGO.include?(logo.blob.content_type)

    StringIO.new(logo.blob.download)
  rescue StandardError
    nil
  end

  private

  def logo_dibujable
    return unless logo.attached?

    unless FORMATOS_DE_LOGO.include?(logo.blob.content_type)
      errors.add(:logo, "tiene que ser PNG o JPG: son los formatos que se pueden imprimir en el boletín")
    end

    return unless logo.blob.byte_size > PESO_MAXIMO_DEL_LOGO

    errors.add(:logo, "no puede pesar más de 2 MB — un escudo no lo necesita, y la conexión de un colegio sí")
  end
  enum :school_type, { primary: 0, secondary: 1 }

  has_one_attached :logo

  has_many :departments, dependent: :restrict_with_error
  has_many :students, dependent: :restrict_with_error
  has_many :teachers, dependent: :restrict_with_error
  has_many :admins, dependent: :restrict_with_error
  has_many :academic_periods, dependent: :restrict_with_error
  has_many :grades, dependent: :restrict_with_error
  has_many :subjects, dependent: :restrict_with_error

  validates :dea_code, presence: true, uniqueness: true
  validates :name, :location, :school_type, presence: true
end
