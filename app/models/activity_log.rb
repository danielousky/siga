class ActivityLog < ApplicationRecord
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true

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
    "period_destroyed"     => "Período académico eliminado"
  }.freeze

  scope :recent,    -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user,   ->(user_id) { where(user_id: user_id) }
  scope :in_range,  ->(from, to) { where(created_at: from.beginning_of_day..to.end_of_day) }

  def label
    LABELS[action] || action.humanize
  end
end
