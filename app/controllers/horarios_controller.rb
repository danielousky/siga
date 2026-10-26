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
#
# La semana de una sección es la misma que la de la pestaña «Horario» de la
# sección (decisión 29): las dos la preparan con `MuestraElHorario`.
#
# ## El PDF (decisión 27)
#
# El de un profesor sale de aquí, con `.pdf`: es lo que se está viendo. El de
# una sección sale de su pestaña (`/secciones/:id/horario.pdf`), y las dos
# puertas lo enlazan ahí.
class HorariosController < ApplicationController
  include EntregaDocumentos
  include MuestraElHorario

  el_nivel_no_aplica "el horario se mira sección por sección, de cualquier nivel"

  VISTAS = %w[secciones profesores areas alumnos].freeze

  # Los de «Inscripciones»: se busca a la persona, palabra por palabra y sin
  # acentos (`MOR-179`, `MOR-183`).
  CAMPOS_DE_BUSQUEDA = %w[users.first_name users.last_name users.second_last_name users.document].freeze

  before_action :solo_la_administracion
  before_action :solo_quien_arma, only: [ :armar, :publicar, :carga ]
  before_action :exigir_un_anio
  before_action :el_anio_sigue_abierto, only: [ :armar, :publicar, :carga ]

  def index
    @ver = params[:ver].presence_in(VISTAS) || "secciones"
    @por_dia = params[:vista] == "dia"
    @turno = TurnoDelAnio.de(@anio) || TurnoDelAnio.de_la_foto(@anio)
    preparar_el_dia_y_los_bloques

    send("ver_#{@ver}")

    respond_to do |formato|
      formato.html
      formato.pdf { el_pdf_del_profesor }
    end
  end

  # El turno nace aquí, con la primera escritura (decisión 20).
  def armar
    seccion = secciones.find(params[:seccion])
    TurnoDelAnio.asegurar!(@anio)
    pendiente = CargaDeLaSeccion.new(seccion.reload).primera_pendiente
    redirect_to al_horario(seccion.id, armar: 1, area: pendiente&.materia&.id)
  end

  def publicar
    seccion = secciones.find(params[:seccion])
    seccion.update!(timetable_published_at: Time.current)
    log_activity(action: "horario_publicado", subject: seccion,
                 message: "#{current_user.nombre_completo} publicó el horario de #{nombre_de(seccion)}")
    flash[:horario] = { "tipo" => "ok",
                        "texto" => "#{nombre_de(seccion)} quedó publicado. Ya lo ven sus profesores, sus alumnos y las familias." }
    redirect_to al_horario(seccion.id)
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

    if nuevas < [ tope, 1 ].max
      llena = hermanas.find(ubicadas.key(tope)) if tope.positive?
      flash[:horario] = { "tipo" => "aviso", "texto" => no_baja(llena, tope, area.materia) }
    else
      area.grade_subject.update!(weekly_hours: [ nuevas, GradeSubject::HORAS_POSIBLES.last ].min)
      flash[:horario] = { "tipo" => "ok",
                          "texto" => "#{area.materia.name}: #{area.grade_subject.weekly_hours} horas a la semana en " \
                                     "#{seccion.grade.name} #{hermanas.map(&:name).sort.to_sentence}." }
    end
    redirect_to al_horario(seccion.id, armar: 1, area: area.materia.id)
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

    preparar_la_semana_de(@seccion, @anio)
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

  def no_baja(llena, tope, materia)
    return "Un área tiene al menos una hora a la semana." unless llena

    "No baja de #{tope}: #{nombre_de(llena)} ya tiene #{tope} horas de #{materia.name} ubicadas. Quite una primero."
  end

  # La semana del profesor que se está viendo, impresa. Las otras miradas no
  # tienen hoja: la de una sección sale de su pestaña.
  def el_pdf_del_profesor
    return head(:not_found) unless @ver == "profesores" && @profesor && !@por_dia

    entregar_el_horario(HorarioPdf::DelProfesor.new(@rejilla, profesor: @profesor, anio: @anio, colegio: Current.school))
  end

  # Decisión 16: un año que terminó queda en solo lectura. Su horario se ve tal
  # como fue; cambiarlo ahora sería reescribir lo que pasó.
  def el_anio_sigue_abierto
    return unless finalizado?(@anio)

    flash[:horario] = { "tipo" => "aviso", "texto" => "#{@anio.name} ya terminó: su horario se ve, y ya no se arma." }
    redirect_to al_horario(params[:seccion].presence)
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
