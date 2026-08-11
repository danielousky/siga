# Las evaluaciones que un profesor define para su materia, sección y lapso.
#
# ## Quién ve qué
#
#   PROFESOR       las suyas — las materias que dicta en las secciones que tiene
#                  asignadas. Crea, edita y borra.
#   DIRECCIÓN      las de todo el colegio, SOLO LECTURA.
#
# La dirección no edita, y es una decisión deliberada: la ponderación es una
# decisión pedagógica del profesor que evalúa, y cambiarla a mitad de lapso
# altera notas ya cargadas sin que él se entere. Si hace falta intervenir, el
# camino honesto es hablar con el profesor — no un formulario que reescribe su
# criterio en silencio.
#
# Ver MOR-94.
class EvaluationActivitiesController < ApplicationController
  before_action :require_acceso!
  before_action :require_profesor!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_evaluation_activity, only: [:show, :edit, :update, :destroy]

  def index
    actividades = alcance
      .includes(:subject, :evaluation_moment, section: :grade)
      .order("sections.id", "subjects.name", "evaluation_activities.evaluation_moment_id", "evaluation_activities.date_scheduled")

    @lapsos_disponibles = lapsos_del_alcance
    @lapso_filtrado     = @lapsos_disponibles.find { |l| l.id.to_s == params[:lapso] }
    actividades         = actividades.where(evaluation_moment_id: @lapso_filtrado.id) if @lapso_filtrado

    @grupos = resumen_de_ponderacion(actividades)
    @pagy, @evaluation_activities = pagy(actividades)
  end

  def show
    @notas_cargadas = @evaluation_activity.activity_grades.count
    @inscritos      = @evaluation_activity.section.enrollments.count
  end

  def new
    @evaluation_activity = EvaluationActivity.new(date_scheduled: Date.current)
  end

  def edit; end

  def create
    @evaluation_activity = EvaluationActivity.new(evaluation_activity_params)

    if asignacion_elegida.nil?
      @evaluation_activity.errors.add(:base, "Elegí una de tus secciones.")
      return render :new, status: :unprocessable_entity
    end

    if @evaluation_activity.save
      redirect_to @evaluation_activity, notice: "Evaluación creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @evaluation_activity.update(evaluation_activity_params)
      redirect_to @evaluation_activity, notice: "Evaluación actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @evaluation_activity.destroy
      redirect_to evaluation_activities_url, notice: "Evaluación eliminada."
    else
      redirect_to @evaluation_activity, alert: @evaluation_activity.errors.full_messages.to_sentence
    end
  end

  private

  # El conjunto que este usuario puede siquiera nombrar. `find` sale de acá, así
  # que pedir el id de una evaluación ajena da 404 y no 403: no se confirma que
  # exista.
  def alcance
    if profesor?
      EvaluationActivity.dictadas_por(current_user.teacher)
    else
      EvaluationActivity.all
    end
  end

  def set_evaluation_activity
    @evaluation_activity = alcance.find(params[:id])
  end

  # Las asignaciones del profesor: cada par sección–materia que dicta.
  def mis_asignaciones
    @mis_asignaciones ||= current_user.teacher
      .teacher_sections
      .includes(:subject, section: [:grade, :academic_period])
      .sort_by { |ts| [ts.section.grade.name, ts.section.name, ts.subject.name] }
  end
  helper_method :mis_asignaciones

  # La asignación que viene en el formulario, **buscada entre las del profesor**.
  # Que la búsqueda esté acotada a `current_user.teacher` es lo que autoriza: un
  # id de otra sección simplemente no aparece y devuelve nil.
  def asignacion_elegida
    return @asignacion_elegida if defined?(@asignacion_elegida)

    seccion, materia = params.dig(:evaluation_activity, :asignacion).to_s.split(":")
    @asignacion_elegida = current_user.teacher.teacher_sections
                                      .find_by(section_id: seccion, subject_id: materia)
  end

  def evaluation_activity_params
    permitidos = params.require(:evaluation_activity)
                       .permit(:evaluation_moment_id, :description, :weight_percentage, :date_scheduled)

    return permitidos if asignacion_elegida.nil?

    permitidos.merge(
      section_id: asignacion_elegida.section_id,
      subject_id: asignacion_elegida.subject_id
    )
  end

  # Los lapsos de los años escolares que aparecen en el alcance del usuario.
  def lapsos_del_alcance
    periodos = if profesor?
                 mis_asignaciones.map { |ts| ts.section.academic_period_id }.uniq
               else
                 Section.distinct.pluck(:academic_period_id)
               end

    EvaluationMoment.where(academic_period_id: periodos).includes(:academic_period).order(:academic_period_id, :id)
  end

  # Cuánto lleva comprometido cada grupo sección–materia–lapso. Es lo que el
  # profesor necesita ver de un vistazo: dónde le falta cerrar el 100 %.
  def resumen_de_ponderacion(actividades)
    actividades.group_by { |a| [a.section, a.subject, a.evaluation_moment] }
               .map do |(seccion, materia, lapso), grupo|
      {
        seccion: seccion, materia: materia, lapso: lapso,
        usado: grupo.sum(&:weight_percentage), cantidad: grupo.size
      }
    end
  end

  # El peso ya comprometido en cada grupo, para que el formulario lo muestre sin
  # ir al servidor. Un profesor tiene pocas secciones: el mapa es chico.
  def ponderacion_de_mis_asignaciones
    mis_asignaciones.each_with_object({}) do |ts, mapa|
      lapsos = EvaluationMoment.where(academic_period_id: ts.section.academic_period_id).order(:id)

      mapa["#{ts.section_id}:#{ts.subject_id}"] = {
        lapsos: lapsos.map { |l| { id: l.id, nombre: l.name } },
        usado: lapsos.index_with do |lapso|
          EvaluationActivity.peso_usado(
            section_id: ts.section_id, subject_id: ts.subject_id,
            evaluation_moment_id: lapso.id, excepto: @evaluation_activity&.id
          ).to_f
        end.transform_keys(&:id)
      }
    end
  end
  helper_method :ponderacion_de_mis_asignaciones

  def require_acceso!
    return if profesor? || puede_supervisar?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
  end

  def require_profesor!
    return if profesor?

    redirect_to evaluation_activities_path,
                alert: "La ponderación la define el profesor que dicta la materia."
  end

  # Dirección y coordinación ven las evaluaciones del colegio, sin editarlas.
  def puede_supervisar?
    can_manage_sections?
  end
  helper_method :puede_supervisar?
end
