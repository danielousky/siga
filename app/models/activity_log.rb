class ActivityLog < ApplicationRecord
  include SchoolScoped

  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

  # El colegio se deduce del rol del usuario. No usa `derives_school_from` porque
  # el origen no es una asociación directa: hay que recorrer los tres roles.
  #
  # Queda OPCIONAL a propósito: un usuario sin rol no tiene colegio, y perder el
  # registro de auditoría sería peor que registrarlo sin escuela. Ver MOR-85.
  belongs_to :school, optional: true
  before_validation :derive_school_from_user_role

  ACTIONS = %w[
    login logout
    enrollment_created enrollment_destroyed
    teacher_assigned teacher_removed
    section_created section_updated section_destroyed
    student_created student_updated student_destroyed
    teacher_created teacher_updated teacher_destroyed
    admin_created admin_updated admin_destroyed
    grade_created grade_updated grade_destroyed
    period_created period_updated period_destroyed
    report_cards_issued
  ].freeze

  LABELS = {
    "login"                => "Inicio de sesión",
    "logout"               => "Cierre de sesión",
    "enrollment_created"   => "Inscripción creada",
    "enrollment_destroyed" => "Inscripción anulada",
    "teacher_assigned"     => "Profesor asignado",
    "teacher_removed"      => "Profesor removido",
    "section_created"      => "Sección creada",
    "section_updated"      => "Sección editada",
    "section_destroyed"    => "Sección eliminada",
    "student_created"      => "Estudiante registrado",
    "student_updated"      => "Estudiante actualizado",
    "student_destroyed"    => "Estudiante eliminado",
    "teacher_created"      => "Profesor registrado",
    "teacher_updated"      => "Profesor actualizado",
    "teacher_destroyed"    => "Profesor eliminado",
    "admin_created"        => "Administrador creado",
    "admin_updated"        => "Administrador actualizado",
    "admin_destroyed"      => "Administrador eliminado",
    "grade_created"        => "Calificación registrada",
    "grade_updated"        => "Calificación modificada",
    "grade_destroyed"      => "Calificación eliminada",
    "period_created"       => "Período académico creado",
    "period_updated"       => "Período académico actualizado",
    "period_destroyed"     => "Período académico eliminado",
    # Un boletín es un documento oficial: queda registrado quién lo emitió.
    "report_cards_issued"  => "Boletines emitidos",
    # La constancia NO se archiva —certifica la situación de hoy, no las
    # calificaciones de un lapso— pero sí queda quién la firmó. Un papel con
    # firma del director del que después nadie sepa quién lo sacó es justo lo
    # que no puede pasar.
    "constancia_emitida"   => "Constancia de estudios emitida"
  }.freeze

  scope :recent,    -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user,   ->(user_id) { where(user_id: user_id) }
  scope :in_range,  ->(from, to) { where(created_at: from.beginning_of_day..to.end_of_day) }

  def label
    LABELS[action] || action.humanize
  end

  private

  def derive_school_from_user_role
    return if school_id.present? || user.blank?

    self.school_id = user.student&.school_id ||
                     user.teacher&.school_id ||
                     user.admin&.school_id
  end
end
