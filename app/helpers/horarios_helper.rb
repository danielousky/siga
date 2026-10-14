# Lo que comparten las pantallas de «Horarios» (spec `horarios`).
module HorariosHelper
  # Las pestañas de Académico ▸ Horarios.
  #
  # ⚠️ En la tanda 3 se suma una primera, «Horarios» —verlos por sección, por
  # profesor o por área—, y pasa a ser la que abre el menú. Hasta entonces el
  # menú abre en «Turnos», que es el primer paso del recorrido.
  def pestanas_de_horarios(activa:)
    [
      [ "Turnos", bell_schedules_path, activa == :turnos ],
      [ "Carga horaria", carga_horaria_path, activa == :carga ]
    ]
  end

  # «8 horas al día · de 7:10 a. m. a 1:00 p. m. · receso 9:50 – 10:20»
  def resumen_del_turno(turno)
    horas = turno.horas_de_clase.size
    return "Todavía sin horas" if horas.zero?

    partes = [ "#{contar(horas, 'hora', 'horas')} al día",
               "de #{HoraDelDia.con_meridiano(turno.entrada)} a #{HoraDelDia.con_meridiano(turno.salida)}" ]
    recesos = turno.time_slots.select(&:receso?)
    partes << "#{pluralizar(recesos.size, 'receso', 'recesos')} #{recesos.map(&:rango).to_sentence}" if recesos.any?
    partes.join(" · ")
  end

  # Las opciones de «después de cuál hora va el receso».
  def opciones_del_receso
    [ [ "Sin receso", 0 ] ] +
      (1...TimeSlot::ORDINALES.size).map { |numero| [ "Tras la #{TimeSlot::ORDINALES[numero - 1]} hora", numero ] }
  end
end
