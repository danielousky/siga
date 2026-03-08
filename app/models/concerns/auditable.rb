module Auditable
  # Registra una actividad en el log de auditoría.
  # Llamar explícitamente desde los controllers para tener control total.
  #
  # Uso:
  #   log_activity(action: "enrollment_created",
  #                message: "#{current_user.full_name} inscribió a ...",
  #                subject: @enrollment)
  def log_activity(action:, message:, subject: nil, metadata: {})
    ActivityLog.create!(
      user:       current_user,
      action:     action,
      message:    message,
      subject:    subject,
      metadata:   metadata,
      ip_address: request.remote_ip
    )
  rescue => e
    Rails.logger.warn("[Auditable] No se pudo registrar actividad '#{action}': #{e.message}")
  end
end
