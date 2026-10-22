# Académico ▸ Horarios: el horario de cada sección, y las otras miradas sobre
# la misma tabla de clases (spec `horarios`, decisiones 19 a 24).
#
#    ?ver=secciones   la semana de una sección —la puerta— o todas, un mismo día
#    ?ver=profesores  la semana de un profesor, o todos, un mismo día
#    ?ver=areas       un área en todo el colegio
#    ?ver=alumnos     buscar a un alumno: su horario es el de su sección
#
# ## ⚠️ Mirar no escribe
#
# En un año sin turno, la rejilla se dibuja con el timbre de la foto sin
# guardarlo. El turno nace al tocar «Armar» (un POST): un GET no cambia nada,
# y un colegio en solo lectura mira sin crear filas (`TurnoDelAnio`).
#
# ## Armar vive dentro de un `turbo_frame`
#
# Tocar una casilla, elegir un área o corregir una hora vuelve a ESTA pantalla
# y Turbo cambia solo el marco «horario»: la página no salta arriba, y el
# mensaje —que viene en `flash[:horario]`— brinca al llegar (decisión 24).
class HorariosController < ApplicationController
  el_nivel_no_aplica "el horario se mira sección por sección, de cualquier nivel"

  VISTAS = %w[secciones profesores areas alumnos].freeze

  # Los de «Inscripciones»: se busca a la persona, palabra por palabra y sin
  # acentos (`MOR-179`, `MOR-183`).
  CAMPOS_DE_BUSQUEDA = %w[users.first_name users.last_name users.second_last_name users.document].freeze

  before_action :solo_la_administracion
  before_action :solo_quien_arma, only: [ :armar, :publicar, :carga ]
  before_action :exigir_un_anio

  def index
    @ver = params[:ver].presence_in(VISTAS) || "secciones"
    @por_dia = params[:vista] == "dia"
    @dia = (params[:dia].presence || HoraDeVenezuela.dia_de_clases).to_i.clamp(1, Lesson::DIAS.size)
    @turno = TurnoDelAnio.de(@anio) || TurnoDelAnio.de_la_foto(@anio)
    session[:horario_en_bloques] = params[:bloques] == "1" if params.key?(:bloques)
    @en_bloques = session.fetch(:horario_en_bloques, true)

    send("ver_#{@ver}")
  end

  # El turno nace aquí, con la primera escritura (decisión 20).
  def armar
    seccion = secciones.find(params[:seccion])
    TurnoDelAnio.asegurar!(@anio)
    pendiente = CargaDeLaSeccion.new(seccion.reload).primera_pendiente
    redirect_to horarios_path(seccion: seccion.id, armar: 1, area: pendiente&.materia&.id)
  end

  def publicar
    seccion = secciones.find(params[:seccion])
    seccion.update!(timetable_published_at: Time.current)
    log_activity(action: "horario_publicado", subject: seccion,
                 message: "#{current_user.nombre_completo} publicó el horario de #{nombre_de(seccion)}")
    flash[:horario] = { "tipo" => "ok",
                        "texto" => "#{nombre_de(seccion)} quedó publicado. Ya lo ven sus profesores, sus alumnos y las familias." }
    redirect_to horarios_path(seccion: seccion.id)
  end

  # El − y el + de «Por ubicar»: la carga del área para el grado entero
  # (decisión 21). Nunca baja de lo ya ubicado en alguna sección del grado.
  def carga
    seccion = secciones.find(params[:seccion])
    area = CargaDeLaSeccion.new(seccion).areas.find { |a| a.grade_subject.id == params[:grade_subject_id].to_i }
    return head :not_found unless area

    nuevas = area.horas.to_i + (params[:delta].to_i.negative? ? -1 : 1)
    hermanas = Section.where(grade_id: seccion.grade_id, academic_period: @anio)
    ubicadas = Lesson.where(subject_id: area.materia.id, section_id: hermanas.select(:id)).group(:section_id).count
    tope = ubicadas.values.max.to_i

    flash[:horario] = if nuevas < [ tope, 1 ].max
      llena = hermanas.find(ubicadas.key(tope)) if tope.positive?
      { "tipo" => "aviso",
        "texto" => llena ? "No baja de #{tope}: #{nombre_de(llena)} ya tiene #{tope} horas de #{area.materia.name} " \
                           "ubicadas. Quite una primero." : "Un área tiene al menos una hora a la semana." }
    else
      area.grade_subject.update!(weekly_hours: [ nuevas, GradeSubject::HORAS_POSIBLES.last ].min)
      { "tipo" => "ok",
        "texto" => "#{area.materia.name}: #{area.grade_subject.weekly_hours} horas a la semana en " \
                   "#{seccion.grade.name} #{hermanas.map(&:name).sort.to_sentence}." }
    end
    redirect_to horarios_path(seccion: seccion.id, armar: 1, area: area.materia.id)
  end

  private

  def ver_secciones
    @secciones = secciones.includes(:grade).sort_by { |s| [ s.grade.orden || 99, s.grade.name, s.name ] }
    @seccion = la_seccion_a_mostrar
    return if @seccion.nil?

    session[:horario_seccion] = @seccion.id

    if @por_dia
      clases = Lesson.where(section_id: @secciones.map(&:id), day: @dia).includes(:subject, teacher: :user).group_by(&:section_id)
      @matriz = RejillaDeHorarios::DelDia.new(@turno, @secciones) { |seccion| clases.fetch(seccion.id, []) }
      return
    end

    @armando = params[:armar] == "1" && can_manage_sections? && @seccion.bell_schedule.present?
    @rejilla = RejillaDeHorarios::DeLaSeccion.new(@seccion, @seccion.bell_schedule || @turno,
                                                  armando: @armando, elegida: params[:area], marcada: casilla_tocada)
    @hora_editada = @rejilla.turno.time_slots.find { |hora| hora.id == params[:hora].to_i } if @armando
    @mensaje = @armando ? mensaje_del_armador : mensaje_suelto
  end

  def ver_profesores
    @profesores = Teacher.joins(:user).includes(:user)
                         .where(id: TeacherSection.where(section_id: secciones.select(:id)).select(:teacher_id))
                         .sort_by { |t| [ t.user.last_name.to_s, t.user.first_name.to_s ] }
    @profesor = @profesores.find { |t| t.id == params[:profesor].to_i } || @profesores.first
    @horas_por_profesor = Lesson.where(academic_period: @anio).group(:teacher_id).count
    return if @profesor.nil?

    if @por_dia
      clases = Lesson.where(academic_period: @anio, day: @dia, teacher_id: @profesores.map(&:id))
                     .includes(:subject, section: :grade).group_by(&:teacher_id)
      @matriz = RejillaDeHorarios::DelDia.new(@turno, @profesores) { |profesor| clases.fetch(profesor.id, []) }
    else
      @rejilla = RejillaDeHorarios::DelProfesor.new(@profesor, @turno, @anio)
    end
  end

  def ver_areas
    @areas = Subject.where(id: GradeSubject.where(grade_id: secciones.select(:grade_id)).select(:subject_id)).order(:name).to_a
    @area = @areas.find { |a| a.id == params[:area].to_i } || @areas.first
    @rejilla = RejillaDeHorarios::DelArea.new(@area, @turno, @anio) if @area
  end

  def ver_alumnos
    @busqueda = params[:q].to_s.squish
    inscripciones = Enrollment.where(section_id: secciones.select(:id)).includes(student: :user, section: :grade)
                              .joins(student: :user)
    inscripciones = inscripciones.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, @busqueda)) if @busqueda.present?
    @inscripciones = inscripciones.sort_by { |i| i.student.user.apellidos_y_nombres }.first(30)
    @inscripcion = @inscripciones.find { |i| i.student_id == params[:alumno].to_i }
    return unless @inscripcion

    seccion = @inscripcion.section
    @rejilla = RejillaDeHorarios::DeLaSeccion.new(seccion, seccion.bell_schedule || @turno)
  end

  # La pedida; si no, la última que se miró; si no, la primera que ya tiene
  # clases, o la primera de Media —para la que se pensó esto (decisión 14)—.
  # Abrir en una sección vacía de Primaria haría creer que no hay nada.
  def la_seccion_a_mostrar
    pedida = params[:seccion].presence || session[:horario_seccion]
    @secciones.find { |s| s.id == pedida.to_i } ||
      @secciones.find { |s| s.id.in?(con_clases) } ||
      @secciones.find { |s| s.grade.secundaria? || s.grade.media_tecnica? } ||
      @secciones.first
  end

  def con_clases = @con_clases ||= Lesson.where(section_id: @secciones.map(&:id)).distinct.pluck(:section_id)

  # Las secciones con horario: las del año, menos Inicial (decisión 14).
  def secciones
    Section.where(academic_period: @anio).where(grade_id: Grade.where.not(level: :preescolar).select(:id))
  end

  def nombre_de(seccion) = "#{seccion.grade.name} #{seccion.name}"

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

  def exigir_un_anio
    @anio = anio_de_trabajo
    return if @anio

    redirect_to dashboard_path_for_user, alert: "Antes hace falta registrar el año escolar: un horario es de un año."
  end

  def solo_la_administracion
    return if administrador?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores."
  end

  def solo_quien_arma
    return if administrador? && can_manage_sections?

    redirect_to horarios_path, alert: "Armar el horario es de quien administra las secciones."
  end
end
