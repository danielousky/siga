class EvaluationMoment < ApplicationRecord
  include SchoolScoped

  belongs_to :academic_period

  derives_school_from :academic_period

  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :academic_period_id }

  # `weight` describe la ESTRUCTURA del año —cuántos lapsos tiene y qué parte
  # representa cada uno—, pero NO entra en el cálculo de la nota anual: el
  # Artículo 111 del Reglamento manda promedio simple de los lapsos, y esa fue la
  # decisión (MOR-93). Sigue validado para que la estructura declarada cierre.
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate :total_weight_must_not_exceed_100

  private

  # Los pesos suman DENTRO del período, no sobre toda la tabla.
  #
  # Antes esta validación sumaba globalmente, así que si un colegio ocupaba el
  # 100 % ningún otro podía crear un momento de evaluación jamás. No era una fuga:
  # era una denegación de servicio entre inquilinos, y el segundo cliente que
  # entrara al sistema se topaba con ella de inmediato.
  def total_weight_must_not_exceed_100
    return if weight.blank? || academic_period_id.blank?

    otros = EvaluationMoment
      .where(academic_period_id: academic_period_id)
      .where.not(id: id)
      .sum(:weight)

    return if otros + weight <= 100

    errors.add(
      :weight,
      "La suma total de pesos del período no puede exceder 100 % " \
      "(actual: #{otros} %, disponible: #{100 - otros} %)"
    )
  end
end
