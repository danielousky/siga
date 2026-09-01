class EvaluationMoment < ApplicationRecord
  include SchoolScoped

  belongs_to :academic_period
  llega_al_anio_por

  derives_school_from :academic_period

  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :academic_period_id }

  # Las fechas son opcionales —los lapsos ya sembrados no las tienen— pero si
  # hay una tiene que haber la otra, y en orden: medio rango no sirve para nada
  # y da la falsa impresión de que el dato está cargado.
  validate :el_rango_esta_completo_y_en_orden
  validate :el_rango_cabe_en_el_ano_escolar

  # El rango del lapso, o el del año escolar si el colegio no lo cargó. Nunca
  # nil: quien pregunta necesita un rango para contar algo.
  def rango
    return starts_on..ends_on if starts_on && ends_on

    academic_period.start_date..academic_period.end_date
  end

  def fechas_propias? = starts_on.present? && ends_on.present?

  private

  def el_rango_esta_completo_y_en_orden
    if starts_on.present? ^ ends_on.present?
      errors.add(:base, "Si carga una fecha del lapso, cargue las dos")
    elsif starts_on && ends_on && ends_on < starts_on
      errors.add(:ends_on, "no puede ser anterior al inicio del lapso")
    end
  end

  # Un lapso fuera de su año escolar es un error de carga que después aparece
  # como asistencia contada de menos, sin que nada avise.
  def el_rango_cabe_en_el_ano_escolar
    return unless fechas_propias? && academic_period

    ano = academic_period.start_date..academic_period.end_date
    return if ano.cover?(starts_on) && ano.cover?(ends_on)

    errors.add(:base, "El lapso tiene que caer dentro de #{academic_period.name} " \
                      "(#{I18n.l(ano.first, format: :long)} a #{I18n.l(ano.last, format: :long)})")
  end
end
