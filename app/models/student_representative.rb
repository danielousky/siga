# El vínculo entre un representante y un alumno (MOR-110).
class StudentRepresentative < ApplicationRecord
  include SchoolScoped

  derives_school_from :representative

  belongs_to :representative
  belongs_to :student, primary_key: :user_id

  # El representante y el alumno tienen que ser del mismo colegio. Sin esto se
  # podría vincular al hijo de otro inquilino y el portal se lo mostraría —
  # exactamente la fuga que el concern existe para impedir (MOR-89).
  validates_same_school :student

  enum :parentesco, { madre: 0, padre: 1, representante: 2, otro: 3 }

  ETIQUETAS = {
    "madre" => "Madre", "padre" => "Padre",
    "representante" => "Representante legal", "otro" => "Otro"
  }.freeze

  validates :student_id, uniqueness: { scope: :representative_id,
                                       message: "ya está vinculado a este representante" }

  # Un alumno tiene UN representante principal, o ninguno. Dos principales es lo
  # mismo que ninguno: nadie sabe a quién llamar.
  validate :un_solo_principal_por_alumno

  scope :principales, -> { where(principal: true) }

  def etiqueta = ETIQUETAS.fetch(parentesco, parentesco)

  private

  def un_solo_principal_por_alumno
    return unless principal?

    otro = StudentRepresentative.where(student_id: student_id, principal: true)
                                .where.not(id: id).exists?
    return unless otro

    errors.add(:principal, "ya hay otro representante principal para este alumno")
  end
end
