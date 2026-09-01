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
  end

  private

  # El lapso en curso de su inscripción principal. Se reutiliza `ReportCardData`,
  # que es el mismo servicio que arma el boletín: si el panel calculara aparte,
  # tarde o temprano diría un número distinto al del papel.
  def cargar_notas_del_lapso
    @inscripcion = @enrollments.first
    return if @inscripcion.nil?

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
