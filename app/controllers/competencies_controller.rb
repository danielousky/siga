# El plan de evaluación de una sección: sus competencias e indicadores (MOR-136).
#
# Spec congelado: `docs/specs/mor-136-evaluacion-de-primaria.md`.
#
# ## Qué resuelve
#
# Cyndi Montoya, maestra con 19 años de aula: *«nosotros todos los lapsos
# tenemos que estar cargando competencias e indicadores… y eso es algo que pasa
# con todos los sistemas. Es de verdad una pérdida de tiempo muy grande»*.
#
# Un colegio de primaria escribe ~620 competencias al año y las tira al
# terminar. Esta pantalla existe para que eso pase **una sola vez**.
#
# ## ⚠️ El plan es de la SECCIÓN, y lo maneja SU profesor
#
# Corroborado con Cyndi. Cada profesor es autónomo: dos secciones del mismo
# grado pueden tener planes distintos, aunque lo normal sea copiarlos — y
# copiar es un ATAJO, no un vínculo.
#
# Por eso el alcance es el mismo de `EvaluationActivitiesController`: las
# materias que dicta, en las secciones que tiene asignadas. Un plan ajeno no
# aparece, así que pedirlo por id da 404 y no 403.
class CompetenciesController < ApplicationController
  before_action :require_acceso!
  before_action :require_profesor!, except: [ :index ]
  before_action :set_competency, only: [ :edit, :update, :destroy ]

  def index
    return if asignacion.nil? || lapso.nil?

    @competencias = Competency.del_plan(asignacion.section_id, asignacion.subject_id, lapso.id)
                              .includes(:indicators)
    # ⚠️ Solo se ofrece traer el plan viejo si NO hay uno. Ofrecerlo con el plan
    # escrito invita a duplicarlo, y el índice único lo rechazaría a la mitad.
    @sugerido = plan_del_ano_pasado if @competencias.empty? && profesor?
  end

  def new
    @competency = Competency.new
  end

  def edit; end

  def create
    @competency = Competency.new(datos_del_plan)

    if @competency.save
      redirect_to plan_path, notice: "Competencia agregada al plan."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ⚠️ Los indicadores se REEMPLAZAN, no se agregan.
  #
  # Llegan como un textarea —uno por línea— así que lo que la maestra ve al
  # editar es la lista completa: si borró una línea, esa línea tiene que
  # desaparecer. Con `indicators_attributes` a secas se agregarían los tres de
  # nuevo y quedarían seis.
  def update
    @competency.indicators.destroy_all

    if @competency.update(datos_de_la_competencia)
      redirect_to plan_path, notice: "Competencia actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @competency.destroy
      redirect_to plan_path, notice: "Competencia borrada del plan."
    else
      # ⚠️ Una competencia que ya etiqueta evaluaciones NO se borra: cambiaría
      # lo que dice una boleta hacia atrás.
      redirect_to plan_path, alert: @competency.errors.full_messages.to_sentence
    end
  end

  # Traer el plan del año pasado, del mismo grado y la misma materia.
  #
  # ⚠️ Se COPIA el texto, no se referencia. El plan de 2025 tiene que poder
  # corregirse este año sin reescribir la boleta que ya salió — es la misma
  # razón por la que el boletín guarda un snapshot.
  def sugerido
    return redirect_to(plan_path, alert: "Elige tu sección y el lapso.") if asignacion.nil? || lapso.nil?

    copiadas = copiar_competencias(plan_del_ano_pasado, a: asignacion, lapso: lapso)

    redirect_to plan_path,
                notice: "Se trajeron #{contar(copiadas, 'competencia', 'competencias')}. " \
                        "Revísalas y ajusta lo que haga falta."
  end

  # Copiar este plan a las otras secciones donde ESTE profesor dicta la misma
  # materia. Daniel: *«darle la opción de copiar el plan al resto de las
  # secciones que él dicta»*.
  def copiar
    return redirect_to(plan_path, alert: "Elige tu sección y el lapso.") if asignacion.nil? || lapso.nil?

    plan = Competency.del_plan(asignacion.section_id, asignacion.subject_id, lapso.id)
    hechas = otras_secciones.sum { |destino| copiar_competencias(plan, a: destino, lapso: lapso).size }

    redirect_to plan_path,
                notice: "Copiado a #{contar(otras_secciones.size, 'sección', 'secciones')} " \
                        "(#{contar(hechas, 'competencia', 'competencias')})."
  end

  private

  # ── El alcance: lo que este usuario puede siquiera nombrar ────────────────

  def set_competency
    @competency = Competency.del_plan(asignacion&.section_id, asignacion&.subject_id, lapso&.id)
                            .find(params[:id])
  end

  # Las asignaciones del profesor: cada par sección–materia que dicta.
  # Es el MISMO método de `EvaluationActivitiesController`, y acotar la búsqueda
  # a `current_user.teacher` es lo que autoriza.
  def mis_asignaciones
    return @mis_asignaciones if defined?(@mis_asignaciones)
    return @mis_asignaciones = [] unless profesor?

    @mis_asignaciones = current_user.teacher.teacher_sections
                                    .includes(:subject, section: [ :grade, :academic_period ])
                                    .sort_by { |ts| [ ts.section.grade.name, ts.section.name, ts.subject.name ] }
  end
  helper_method :mis_asignaciones

  def asignacion
    return @asignacion if defined?(@asignacion)

    seccion, materia = params[:asignacion].to_s.split(":")
    @asignacion = mis_asignaciones.find do |ts|
      ts.section_id.to_s == seccion && ts.subject_id.to_s == materia
    end
    @asignacion ||= mis_asignaciones.first
  end
  helper_method :asignacion

  def lapsos
    return [] if asignacion.nil?

    @lapsos ||= EvaluationMoment.where(academic_period_id: asignacion.section.academic_period_id)
                                .order(:id)
  end
  helper_method :lapsos

  def lapso
    @lapso ||= lapsos.find { |l| l.id.to_s == params[:lapso] } || lapsos.first
  end
  helper_method :lapso

  def otras_secciones
    @otras_secciones ||= mis_asignaciones.select do |ts|
      ts.subject_id == asignacion.subject_id && ts.section_id != asignacion.section_id
    end
  end
  helper_method :otras_secciones

  def plan_path
    competencies_path(asignacion: "#{asignacion&.section_id}:#{asignacion&.subject_id}",
                      lapso: lapso&.id)
  end
  helper_method :plan_path

  # ── El plan del año pasado ────────────────────────────────────────────────

  def plan_del_ano_pasado
    return Competency.none if asignacion.nil? || lapso.nil?

    Competency.para_sugerir(section: asignacion.section, subject: asignacion.subject,
                            evaluation_moment: lapso).includes(:indicators)
  end

  # ⚠️ Idempotente: la que ya está en el plan se salta. Copiar dos veces no
  # duplica nada, que es la misma regla de `CopiarLaEstructura` (MOR-166).
  def copiar_competencias(origen, a:, lapso:)
    ya_estan = Competency.del_plan(a.section_id, a.subject_id, lapso.id)
                         .pluck(:descripcion_canonica).to_set

    origen.reject { |c| ya_estan.include?(c.descripcion_canonica) }.filter_map do |vieja|
      nueva = Competency.new(section_id: a.section_id, subject_id: a.subject_id,
                             evaluation_moment_id: lapso.id,
                             descripcion: vieja.descripcion, orden: vieja.orden)
      # ⚠️ Cada una en su SAVEPOINT: una que falle no puede tumbar las otras
      # veinte. Es la lección de `CopiarLaEstructura`.
      ActiveRecord::Base.transaction(requires_new: true) do
        nueva.save!
        vieja.indicators.each { |i| nueva.indicators.create!(descripcion: i.descripcion, orden: i.orden) }
        ya_estan << nueva.descripcion_canonica
        nueva
      end
    rescue ActiveRecord::RecordInvalid
      nil
    end
  end

  # ── Lo que llega del formulario ───────────────────────────────────────────

  def datos_del_plan
    return {} if asignacion.nil? || lapso.nil?

    datos_de_la_competencia.merge(section_id: asignacion.section_id,
                                  subject_id: asignacion.subject_id,
                                  evaluation_moment_id: lapso.id)
  end

  # ⚠️ Los indicadores entran como TEXTO, uno por línea, y no como campos que se
  # agregan de a uno con JavaScript.
  #
  # Una maestra escribiendo tres indicadores en un teléfono los escribe de un
  # tirón; obligarla a tocar «+ Agregar» entre cada uno es tres toques y una
  # pantalla que salta. Y sin JS, funciona con la conexión caída.
  def datos_de_la_competencia
    permitidos = params.require(:competency).permit(:descripcion, :orden)
    lineas = params[:competency][:indicadores].to_s.lines.map(&:strip).compact_blank

    permitidos.merge(indicators_attributes: lineas.each_with_index.map { |texto, i|
      { descripcion: texto, orden: i }
    })
  end

  # ── Quién entra ───────────────────────────────────────────────────────────
  #
  # ⚠️ El mensaje es propio y no un `require_profesor!` compartido, aunque la
  # pregunta sea la misma que en `EvaluationActivitiesController`. Lo que cambia
  # entre pantallas no es el guarda: es lo que hay que decirle a quien llegó.
  # «Acceso no autorizado» no explica por qué la dirección puede MIRAR el plan y
  # no escribirlo.

  def require_acceso!
    return if profesor? || puede_supervisar?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
  end

  # La dirección VE el plan y no lo toca, por la misma razón que no toca la
  # ponderación: es la decisión pedagógica de quien evalúa. Si hay que
  # intervenir, el camino honesto es hablar con el profesor.
  def require_profesor!
    return if profesor?

    redirect_to competencies_path,
                alert: "El plan de evaluación lo escribe el profesor que dicta la materia."
  end

  def puede_supervisar? = can_manage_sections?

  def contar(cantidad, singular, plural) = helpers.contar(cantidad, singular, plural)
end
