class AcademicPeriod < ApplicationRecord
  include SchoolScoped

  belongs_to :school

  has_many :sections, dependent: :restrict_with_error
  has_many :evaluation_moments, dependent: :restrict_with_error

  validates :name, :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  scope :en_curso, -> { where(start_date: ..Date.current, end_date: Date.current..) }
  scope :por_comenzar, -> { where(start_date: Date.current...).order(:start_date) }

  # El año escolar que el colegio está viviendo hoy.
  #
  # No hay bandera de "activo" y es a propósito: el año escolar lo definen sus
  # fechas, y una bandera se queda vieja el día que nadie se acuerda de moverla
  # — justo el día que la pantalla la muestra.
  #
  # Entre julio y septiembre **no hay ninguno en curso**, y ahí lo que le importa
  # al colegio es el que viene, que es el que está preparando. Por eso el orden
  # es: el de hoy, el próximo, y si no, el último que hubo.
  def self.vigente
    en_curso.first || por_comenzar.first || order(start_date: :desc).first
  end

  # Cómo se para el período frente a hoy. Se devuelve el símbolo y no el texto
  # para que la vista decida cómo escribirlo — y para que no haya que mirar una
  # cadena en castellano para saber si el año está corriendo.
  def situacion
    return :por_comenzar if start_date > Date.current
    return :finalizado   if end_date < Date.current

    :en_curso
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end
end
