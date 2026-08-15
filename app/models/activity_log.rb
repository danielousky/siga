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

  # `ACTIONS` sale de `LABELS`, no se escribe aparte.
  #
  # Cuando eran dos listas a mano se separaron: `constancia_emitida` tenía
  # etiqueta y **no estaba en ACTIONS**. No rompía nada —la constante no se
  # valida— pero una lista que dice ser "todas las acciones" y no las tiene es
  # peor que no tenerla: se la consulta creyendo que es cierta.
  #
  # ⚠️ Y por eso conviene saber lo otro: de las acciones que hay etiquetadas,
  # **el sistema todavía no emite todas**. Ver `ACCIONES_SIN_EMISOR`.

  # Lo que el sistema TODAVÍA no registra, escrito para no olvidarlo.
  #
  # Un registro de actividad que promete más de lo que cubre es peor que uno
  # chico y honesto: se lo consulta para responder "¿quién hizo esto?" y la
  # respuesta silenciosa es "nadie", que se confunde con "no pasó".
  ACCIONES_SIN_EMISOR = %w[
    logout
    section_created section_updated section_destroyed
    teacher_created teacher_updated teacher_destroyed
    admin_created admin_updated admin_destroyed
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
    # `calificacion_*` y no `grade_*`: en este sistema `Grade` es el GRADO
    # ESCOLAR —1er Año, 2do Año— y una calificación es otra cosa. Con los
    # nombres viejos, "grade_destroyed" se leía como "se borró un grado".
    "calificacion_registrada" => "Calificación registrada",
    "calificacion_modificada" => "Calificación modificada",
    "calificacion_eliminada"  => "Calificación eliminada",
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

  ACTIONS = LABELS.keys.freeze

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
