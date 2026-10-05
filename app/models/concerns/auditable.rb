# El registro de auditoría, desde los controllers.
#
# ## Por qué se llama a mano y no por callback del modelo
#
# Un `after_save` en el modelo registraría también lo que hace un seed, una
# migración, un job o la consola — y ninguna de esas cosas tiene un usuario
# detrás. La pregunta que este registro contesta es *"¿quién hizo esto?"*, así
# que solo tiene sentido donde hay un quién: la petición.
module Auditable
  # Registra una actividad en el log de auditoría.
  #
  #   log_activity(action: "enrollment_created",
  #                message: "#{current_user.first_name} inscribió a ...",
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

  # La forma corta para el alta / edición / baja de siempre.
  #
  # Existe porque la forma larga son seis líneas por sitio, con el mensaje
  # escrito a mano cada vez — y eso es exactamente por qué **la mitad de las
  # acciones nunca se escribieron**: `ActivityLog` tenía etiquetas para
  # secciones, profesores, administradores y períodos, y ningún controller las
  # emitía. Una lista de "todo lo que el sistema audita" que en realidad
  # audita la mitad es peor que una lista corta y cierta.
  #
  #   registrar_cambio(:creado, @section, "1er Año – A")
  #   → "Ramón Díaz creó la sección 1er Año – A"
  #
  # `nombre` va explícito y no deducido del modelo: cómo se llama una sección
  # para una persona —"1er Año – A"— no es ninguna columna, y adivinarlo con
  # `to_s` o `try(:name)` produce mensajes como "Section #513" justo el día que
  # alguien los necesita.
  VERBOS = {
    creado:      { sufijo: "created",   verbo: "creó" },
    actualizado: { sufijo: "updated",   verbo: "actualizó" },
    eliminado:   { sufijo: "destroyed", verbo: "eliminó" }
  }.freeze

  ARTICULOS = {
    "section"         => "la sección",
    "teacher"         => "al profesor",
    "admin"           => "al administrador",
    "academic_period" => "el año escolar",
    "subject"         => "el área de aprendizaje",
    "grade"           => "el grado",
    "department"      => "el departamento"
  }.freeze

  def registrar_cambio(que, registro, nombre, tipo: nil)
    forma = VERBOS.fetch(que)
    clave = tipo || registro.class.name.underscore
    # `academic_period` audita como `period_*`: el token viene de antes y
    # cambiarlo dejaría huérfanas las filas ya escritas.
    token = clave == "academic_period" ? "period" : clave

    log_activity(
      action:  "#{token}_#{forma[:sufijo]}",
      subject: (registro if que != :eliminado),
      message: "#{current_user.nombre_completo} #{forma[:verbo]} " \
               "#{ARTICULOS.fetch(clave, 'el registro')} #{nombre}"
    )
  end
end
