# El panel del profesor (MOR-135).
#
# `MOR-135` lo dejó escrito: el profesor *"entra a CARGAR NOTAS. Semanal, con
# apuro, desde el teléfono."* El panel abría con cuatro conteos —secciones
# asignadas, alumnos en total, materias distintas, secciones que guía— que no
# le sirven para eso ni cambian de una semana a otra.
#
# Ahora lo primero es **lo que le falta corregir**, con el enlace directo a la
# planilla. Los conteos siguen abajo: son contexto, no tarea.
class Dashboards::ProfesorController < ApplicationController
  before_action :require_profesor!

  def index
    @teacher = current_user.teacher

    # ⚠️ Solo el año que está cursando (MOR-165). Sin esto, un profesor con tres
    # años en el colegio abre su panel y lee «12 secciones · 340 alumnos»
    # sumando los tres — y entra a cargar notas de una sección que ya cerró.
    # ⚠️ Del año Y del NIVEL de la sesión (MOR-223): un profesor que da primaria
    # y media veía las dieciséis secciones juntas.
    @teacher_sections = @teacher.teacher_sections
                                .del_anio_de_la_sesion
                                .del_nivel_de_la_sesion
                                .includes(:subject, section: [ :grade, :academic_period, :enrollments ])
                                .to_a
                                .sort_by { |ts| [ ts.section.grade.orden || 99, ts.section.name, ts.subject.name ] }

    # Las secciones de las que es GUÍA — no los grados (MOR-209). El guía es de
    # la sección; el grado, si acaso, tiene un coordinador.
    @led_sections = @teacher.led_sections.del_anio_de_la_sesion.includes(:grade, :enrollments)

    @total_sections = @teacher_sections.size
    @total_students = @teacher_sections.sum { |ts| ts.section.enrollments.size }
    @total_subjects = @teacher_sections.map(&:subject_id).uniq.size

    @sin_corregir = evaluaciones_sin_corregir
    @avances = CargaDeNotas.avance_por_asignacion(@teacher_sections)
    horario_del_profesor
  end

  private

  # Su horario (spec `horarios`): «Ahora · Después» y «Mi semana», solo con lo
  # PUBLICADO (decisión 13). Sin turno o sin clases publicadas, el panel no
  # dice nada de horarios: una tarjeta vacía no le sirve a nadie.
  def horario_del_profesor
    anio = anio_de_trabajo
    turno = TurnoDelAnio.de(anio)
    return unless turno

    clases = Lesson.where(teacher: @teacher, academic_period: anio).joins(:section)
                   .where.not(sections: { timetable_published_at: nil }).includes(:subject, section: :grade).to_a
    return if clases.empty?

    @dia = (params[:dia].presence || HoraDeVenezuela.dia_de_clases).to_i.clamp(1, Lesson::DIAS.size)
    @momento = MomentoDelProfesor.new(clases)
    @semana = RejillaDeHorarios::DelProfesor.new(@teacher, turno, anio, solo_publicadas: true)
  end

  # Las evaluaciones cuya fecha ya pasó y a las que les faltan notas.
  #
  # Se resuelve en DOS consultas y no en una por evaluación: la cuenta de notas
  # cargadas sale de un `group(:evaluation_activity_id).count`, y la de alumnos
  # inscritos ya vino con el `includes` de arriba. Con quince evaluaciones la
  # diferencia no se nota; con las de un año entero, sí — y este panel lo abre
  # un profesor desde el teléfono.
  # ⚠️ El cálculo NO vive acá (MOR-155).
  #
  # La dirección necesita exactamente lo mismo, agregado por profesor, para
  # saber a quién llamarle la atención antes de cerrar el lapso. Con dos copias
  # habría dos definiciones de «atrasado» que se van separando, y el director
  # terminaría reclamándole a alguien que sí cargó.
  def evaluaciones_sin_corregir
    CargaDeNotas.incompletas(@teacher_sections).first(6)
  end

  def require_profesor!
    return if profesor?

    redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para profesores."
  end
end
