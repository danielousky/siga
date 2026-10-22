# El panel del alumno (MOR-135).
#
# `MOR-135` lo dejó escrito: el alumno *"entra a VER LA NOTA"*. Y el panel
# tenía una tarjeta titulada "Mis notas" que **no mostraba ni una nota**: un
# título, una frase y un botón para ir a otra pantalla.
#
# Ahora las notas del lapso en curso están acá. El botón sigue, para el detalle
# por evaluación y el año completo — pero la respuesta a la pregunta con la que
# entró se ve sin hacer clic.
class Dashboards::EstudianteController < ApplicationController
  include ExigeEstarAlDia

  before_action :require_estudiante!

  def index
    @student = current_user.student

    # ⚠️ El año de la sesión (MOR-165), y ADEMÁS ordenado por año.
    #
    # El alumno no elige año —ve el que está cursando— pero sin el filtro sus
    # inscripciones de todos los años venían juntas, ordenadas por nombre de
    # grado: un muchacho de 5to Año veía las notas de 1er Año de hace tres.
    # El orden queda igual por si un alumno está en dos secciones el mismo año.
    @enrollments = @student.enrollments
                           .where(status: :regular)
                           .del_anio_de_la_sesion
                           .recientes_primero
                           .includes(section: [ :grade, :academic_period,
                                                teacher_sections: [ :teacher, :subject ] ])
                           .order("grades.name, sections.name")

    @total_sections = @enrollments.size
    @current_period = @enrollments.first&.section&.academic_period

    cargar_notas_del_lapso
    cargar_el_horario
  end

  private

  # El horario de su sección (spec `horarios`): solo el publicado (decisión 13).
  def cargar_el_horario
    seccion = @enrollments.first&.section
    return unless seccion&.bell_schedule

    @dia = (params[:dia].presence || HoraDeVenezuela.dia_de_clases).to_i.clamp(1, Lesson::DIAS.size)
    nombre = "#{seccion.grade.name} #{seccion.name}"
    @horario = if seccion.timetable_published_at
      { seccion: nombre, rejilla: RejillaDeHorarios::DeLaSeccion.new(seccion, seccion.bell_schedule, solo_publicada: true),
        ruta_del_dia: ->(dia) { dashboards_estudiante_path(dia: dia) } }
    else
      { seccion: nombre }
    end
  end

  # El lapso en curso de su inscripción principal. Se reutiliza `ReportCardData`,
  # que es el mismo servicio que arma el boletín: si el panel calculara aparte,
  # tarde o temprano diría un número distinto al del papel.
  def cargar_notas_del_lapso
    @inscripcion = @enrollments.first
    return if @inscripcion.nil?

    # La misma deuda que bloquea a su representante lo bloquea a él: es la
    # deuda de SU inscripción, no de quien la mira.
    return if exigir_estar_al_dia!(@inscripcion)

    @lapsos = EvaluationMoment.where(academic_period_id: @inscripcion.section.academic_period_id)
                              .order(:id).to_a
    @lapso  = @lapsos.find { |l| l.id == params[:lapso].to_i } || @lapsos.first
    return if @lapso.nil?

    @boletin = ReportCardData.para(enrollment: @inscripcion, evaluation_moment: @lapso).to_h
  end

  def require_estudiante!
    return if estudiante?

    redirect_to root_path, alert: "Acceso no autorizado. Esta área es solo para alumnos."
  end
end
