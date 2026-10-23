# La semana de UNA sección, con «Armar» adentro, lista para dibujar (spec
# `horarios`, decisión 29).
#
# ⚠️ Existe porque es la MISMA pantalla con dos puertas, como el plan de
# evaluación (`MuestraElPlan`):
#
#     Académico ▸ Horarios ▸ Secciones    /horarios?seccion=12       elige la sección
#     la pestaña «Horario» de la sección  /secciones/12/horario      ya viene elegida
#
# Daniel, el 23 de octubre de 2026: *«la pestaña horario va a la sección»*.
# Escrita dos veces, la rejilla de una puerta diría una cosa y la de la otra,
# otra.
#
# ## ⚠️ Lo que se toca vuelve por donde se entró
#
# Ubicar, quitar, la carga, el timbre y publicar viven en sus controladores y
# terminan en un redirect. Desde la pestaña, sus formularios llevan
# `desde=seccion` (`HorariosHelper#desde_la_seccion`), y `al_horario` contesta
# con la pestaña: volver a «Horarios» sacaría al director de la sección en la
# que estaba trabajando —y Turbo escribiría en el marco la pantalla de la otra
# puerta, con su selector de secciones adentro—.
module MuestraElHorario
  extend ActiveSupport::Concern

  included do
    helper_method :finalizado?
  end

  private

  # El día que se mira en el teléfono (hoy, o el lunes en un fin de semana) y
  # si el armador ubica de a dos horas: se elige una vez y se recuerda.
  def preparar_el_dia_y_los_bloques
    @dia = (params[:dia].presence || HoraDeVenezuela.dia_de_clases).to_i.clamp(1, Lesson::DIAS.size)
    session[:horario_en_bloques] = params[:bloques] == "1" if params.key?(:bloques)
    @en_bloques = session.fetch(:horario_en_bloques, true)
  end

  # ⚠️ `solo_publicada` es la decisión 13: el borrador lo ve quien administra.
  # El profesor que abre la pestaña de su sección ve la rejilla publicada, o
  # que todavía no lo está.
  def preparar_la_semana_de(seccion, anio, solo_publicada: false)
    @seccion = seccion
    @turno = TurnoDelAnio.de(anio) || TurnoDelAnio.de_la_foto(anio)
    @armando = params[:armar] == "1" && can_manage_sections? && seccion.bell_schedule.present? && !finalizado?(anio)
    @rejilla = RejillaDeHorarios::DeLaSeccion.new(seccion, seccion.bell_schedule || @turno,
                                                  armando: @armando, elegida: params[:area], marcada: casilla_tocada,
                                                  solo_publicada:)
    @hora_editada = @rejilla.turno.time_slots.find { |hora| hora.id == params[:hora].to_i } if @armando
    @mensaje = @armando ? mensaje_del_armador : mensaje_suelto
  end

  # A dónde vuelve lo que se escribió desde la rejilla: a la puerta por donde
  # se entró. `seccion` es el id —puede venir de un parámetro—.
  def al_horario(seccion, **resto)
    return horario_section_path(seccion, **resto) if params[:desde] == "seccion" && seccion.present?

    horarios_path(seccion: seccion.presence, **resto)
  end

  # La hoja del horario, en otra pestaña (`EntregaDocumentos`): lo que se ve,
  # impreso.
  def entregar_el_horario(pdf)
    entregar_pdf(pdf, pdf.nombre_de_archivo)
  end

  def finalizado?(anio) = anio.situacion == :finalizado

  # «2-5»: el martes, la 6ta hora. Es la casilla rayada que se acaba de tocar.
  def casilla_tocada
    dia, numero = params[:porque].to_s.split("-").map(&:to_i)
    [ dia, numero ] if dia&.between?(1, Lesson::DIAS.size) && numero
  end

  # Lo que dice la barra del armador. Brinca cuando viene de tocar la rejilla:
  # de ubicar o quitar (`flash`) o de una casilla rayada (`porque`).
  def mensaje_del_armador
    if (flash_horario = flash[:horario])
      return { texto: flash_horario["texto"], tipo: flash_horario["tipo"], brinca: true }
    end

    if (casilla = casilla_tocada)
      celda = @rejilla.celda(*casilla)
      if celda.tipo == :bloqueada
        otra = celda.datos[:otra]
        motivo = "#{ChoquesDeHorario.apellido_de(celda.datos[:profesor])} está en " \
                 "#{ChoquesDeHorario.nombre_de(otra.section)} dando #{otra.subject.name}"
        texto = ChoquesDeHorario.frase(dia: casilla.first, desde: @rejilla.horas[casilla.last].hora.starts_min, motivo:)
        return { texto:, tipo: "aviso", brinca: true }
      end
    end

    { texto: instruccion, tipo: "info", brinca: false }
  end

  # Fuera de «Armar», la barra aparece solo para contar algo que acaba de pasar
  # —publicar—: el `notice` de siempre se dibuja fuera del marco y no se vería.
  def mensaje_suelto
    return unless (flash_horario = flash[:horario])

    { texto: flash_horario["texto"], tipo: flash_horario["tipo"], brinca: true }
  end

  def instruccion
    area = @rejilla.elegida
    return "Elija un área de arriba y toque una casilla con +." if area.nil?
    return "#{area.materia.name} todavía no tiene horas a la semana: súbalas con +." if area.sin_horas?
    return "#{area.materia.name} ya tiene sus #{area.horas} horas. Para ponerle otra, súbale la carga con +." if area.completa?

    profesor = area.profesor ? ChoquesDeHorario.apellido_de(area.profesor) : "sin profesor"
    "#{area.materia.name} · #{profesor} · #{area.ubicadas} de #{area.horas} horas. Toque una casilla con +; " \
      "las rayadas no se pueden, y al tocarlas se ve por qué."
  end
end
