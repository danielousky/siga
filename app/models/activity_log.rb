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
  # Quedó vacía, y esa es la idea: cuando se escribió tenía trece entradas
  # —secciones, profesores, administradores y períodos, todas con etiqueta y sin
  # emisor—. Si vuelve a tener contenido, es que alguien agregó una etiqueta
  # antes que su registro.
  #
  # `logout` no está y es a propósito: para la pregunta "¿quién estuvo adentro
  # y cuándo?" sirve el `login`. Registrar además la salida duplicaría el
  # volumen del log para responder lo mismo, y la mayoría de las sesiones no
  # terminan en un "cerrar sesión" sino en cerrar la pestaña — o sea que la
  # mitad de las filas faltaría igual. Por eso tampoco tiene etiqueta.
  ACCIONES_SIN_EMISOR = [].freeze

  LABELS = {
    "matricula_importada" => "Matrícula importada",
    # ⚠️ Token propio y no `period_updated`: lo que pasó no es que alguien editó
    # un año escolar, es que trajo diez secciones y ochenta asignaciones de otro
    # (MOR-166). En la pantalla de auditoría son dos hechos muy distintos.
    "estructura_copiada"  => "Estructura del año escolar copiada",
    "certificacion_emitida" => "Certificación de calificaciones emitida",
    "documento_de_primaria_emitido" => "Documento de primaria emitido",
    "pensum_importada"     => "Materias y profesores importados",
    "login"                => "Inicio de sesión",
    "enrollment_created"   => "Inscripción creada",
    "enrollment_destroyed" => "Inscripción anulada",
    "teacher_assigned"     => "Profesor asignado",
    "teacher_removed"      => "Profesor removido",
    "section_created"      => "Sección creada",
    "section_updated"      => "Sección editada",
    "section_destroyed"    => "Sección eliminada",
    "student_created"      => "Alumno registrado",
    "student_updated"      => "Alumno actualizado",
    "student_destroyed"    => "Alumno eliminado",
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
    "department_created"   => "Departamento creado",
    "department_updated"   => "Departamento actualizado",
    "department_destroyed" => "Departamento eliminado",
    "evaluation_moment_created"   => "Lapso creado",
    "evaluation_moment_updated"   => "Lapso actualizado",
    "evaluation_moment_destroyed" => "Lapso eliminado",
    "enrollment_updated"   => "Inscripción modificada",
    # La visita de soporte de SIGA a un colegio (MOR-133). Es el registro que
    # convierte un acceso amplio en algo defendible frente al cliente: entró,
    # el colegio lo vio en el momento, y queda en su historial.
    "soporte_siga_entro"   => "Soporte de SIGA entró al colegio",
    "period_created"       => "Año escolar creado",
    "period_updated"       => "Año escolar actualizado",
    "period_destroyed"     => "Año escolar eliminado",
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
