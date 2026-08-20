# Las notas del alumno, como las ve el alumno.
#
# Es la superficie más visitada del producto y hasta ahora estaba vacía: cada
# estudiante es un usuario que entra a mirar. Y es lo que le hace visible a la
# familia que el colegio está pagando algo — el director firma el contrato, pero
# quien renueva es un colegio donde las familias usan el sistema.
#
# ## Dos cosas que no se pueden confundir
#
# **Sin nota no es cero.** Un alumno viendo un 0 donde el profesor todavía no
# cargó nada llama al colegio y deja de confiar en el sistema. Acá lo que falta
# se muestra como "pendiente", nunca como número.
#
# **Un promedio de lapso abierto no es la nota del lapso.** Si el profesor cargó
# el 60 % de la ponderación, el 15 que se ve es sobre ese 60 % — y se dice.
#
# ## El aislamiento
#
# No hay ningún id en la URL salvo el lapso, y ese se busca **entre los del
# período del propio alumno**. Todo lo demás sale de `current_user.student`.
#
# Ver MOR-97.
class Dashboards::NotasController < ApplicationController
  before_action :require_estudiante!

  # Una materia con todo lo que el alumno necesita saber de ella en un lapso.
  Materia = Struct.new(:subject, :actividades, :nota_lapso, :peso_cargado, :peso_definido, :libro,
                       keyword_init: true) do
    def pendientes  = actividades.count { |a| a[:nota].nil? }
    def evaluadas   = actividades.count { |a| a[:nota].present? }
    # Parcial mientras el profesor no haya cargado el 100 % de la ponderación.
    def parcial?    = nota_lapso.present? && peso_cargado < 100
    def sin_empezar? = actividades.empty?
  end

  def index
    @student    = current_user.student
    @enrollment = inscripcion_vigente
    return if @enrollment.nil?

    @seccion = @enrollment.section
    @lapsos  = EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id).to_a
    @lapso   = lapso_elegido
    @vista_anual = params[:lapso] == "anual"

    actividades = EvaluationActivity.where(section_id: @seccion.id).includes(:subject, :evaluation_moment).to_a
    notas       = ActivityGrade.where(student_id: @student.id,
                                      evaluation_activity_id: actividades.map(&:id)).index_by(&:evaluation_activity_id)
    lapsos_alumno = MomentGrade.where(enrollment_id: @enrollment.id)
                               .index_by { |mg| [mg.subject_id, mg.evaluation_moment_id] }
    libros = FinalGradeBook.where(enrollment_id: @enrollment.id).index_by(&:subject_id)

    @materias = @seccion.grade.subjects.order(:name).map do |materia|
      del_lapso = actividades.select { |a| a.subject_id == materia.id && a.evaluation_moment_id == @lapso&.id }
                             .sort_by(&:date_scheduled)

      filas = del_lapso.map do |actividad|
        { actividad: actividad, nota: notas[actividad.id]&.score&.to_i }
      end

      Materia.new(
        subject: materia,
        actividades: filas,
        nota_lapso: lapsos_alumno[[materia.id, @lapso&.id]]&.final_moment_score&.to_i,
        peso_cargado: filas.select { |f| f[:nota] }.sum { |f| f[:actividad].weight_percentage },
        peso_definido: del_lapso.sum(&:weight_percentage),
        libro: libros[materia.id]
      )
    end

    # Lo que tiene evaluaciones va primero y con detalle; las materias que el
    # profesor todavía no arrancó se agrupan al final en una línea. Una tarjeta
    # vacía por materia entierra la única que importa entre siete que no dicen
    # nada.
    #
    # En la vista anual NO se separa: ahí no se listan actividades de ningún
    # lapso, así que "sin actividades" sería toda la tabla.
    @sin_evaluaciones = @vista_anual ? [] : @materias.select(&:sin_empezar?)
    @materias        -= @sin_evaluaciones

    @pendientes_totales = @materias.sum(&:pendientes)
    @promedio_general   = promedio_general
  end

  private

  # La inscripción del período más reciente. Un alumno puede arrastrar
  # inscripciones de años anteriores; la que le interesa es la de ahora.
  def inscripcion_vigente
    @student.enrollments
            .where(status: :regular)
            .includes(section: [:grade, :academic_period])
            .max_by { |e| e.section.academic_period.start_date }
  end

  # El lapso sale de la URL, pero se busca ENTRE LOS DEL PERÍODO DEL ALUMNO: un
  # id de otro año simplemente no aparece.
  def lapso_elegido
    return nil if @lapsos.empty?
    return nil if params[:lapso] == "anual"

    @lapsos.find { |l| l.id.to_s == params[:lapso] } || lapso_en_curso
  end

  # El lapso "en curso" es el último que tiene evaluaciones definidas: si el
  # profesor todavía no cargó nada del tercero, lo que el alumno quiere ver es
  # el segundo.
  def lapso_en_curso
    con_actividades = EvaluationActivity.where(section_id: @seccion.id).distinct.pluck(:evaluation_moment_id)
    @lapsos.reverse.find { |l| con_actividades.include?(l.id) } || @lapsos.first
  end

  # El promedio de las materias que YA tienen nota. Las que no, no cuentan como
  # cero — la misma regla que en el cálculo oficial.
  def promedio_general
    notas = if @vista_anual
              @materias.filter_map { |m| m.libro&.final_score }
            else
              @materias.filter_map(&:nota_lapso)
            end
    return nil if notas.empty?

    GradeCalculator.redondear(notas.sum / notas.size.to_d)
  end

  def require_estudiante!
    return if estudiante?

    redirect_to dashboard_path_for_user, alert: "Esta área es solo para estudiantes."
  end
end
