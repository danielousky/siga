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

  # La asignación elegida. Puede venir entera —`sección:materia`, que es lo que
  # guardan los enlaces— o deducirse de las pastillas de grado y área.
  #
  # ⚠️ La búsqueda va SIEMPRE contra `mis_asignaciones`, y eso es lo que
  # autoriza: un id de la sección de otro profesor no está en la lista y
  # devuelve nil, así que no hace falta comprobar permisos aparte.
  def asignacion
    return @asignacion if defined?(@asignacion)

    seccion, materia = params[:asignacion].to_s.split(":")
    @asignacion = mis_asignaciones.find do |ts|
      ts.section_id.to_s == seccion && ts.subject_id.to_s == materia
    end
    @asignacion ||= por_pastillas
  end
  helper_method :asignacion

  def por_pastillas
    del_grado = mis_asignaciones.select { |ts| ts.section.grade_id == grado_pedido&.id }
    del_grado = mis_asignaciones if del_grado.empty?

    del_area = del_grado.select { |ts| ts.subject_id.to_s == params[:area] }
    (del_area.presence || del_grado).first
  end

  # El grado pedido, sin pasar por `asignacion` — o sería una recursión.
  def grado_pedido
    @grado_pedido ||= mis_asignaciones.map { |ts| ts.section.grade }
                                      .find { |g| g.id.to_s == params[:grado] }
  end

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

  # Las secciones HERMANAS: mismo grado, misma materia, otra sección.
  #
  # ⚠️ El grado también, y faltaba: sin él, «copiar a mis otras secciones»
  # ofrecía las DIECINUEVE donde este profesor dicta Matemática, de 1er a 5to
  # Año. Una competencia de 1er Año no tiene nada que hacer en 5to, y copiarla
  # allá es basura que después alguien tiene que borrar a mano.
  def otras_secciones
    @otras_secciones ||= mis_asignaciones.select do |ts|
      ts.subject_id == asignacion.subject_id &&
        ts.section.grade_id == asignacion.section.grade_id &&
        ts.section_id != asignacion.section_id
    end
  end
  helper_method :otras_secciones

  # ── Los tres niveles de la elección, en pastillas ────────────────────────
  #
  # Idea de Cyndi Montoya: primero el GRADO, después el ÁREA DE APRENDIZAJE, y
  # solo entonces el LAPSO. Es el orden en que ella piensa el trabajo, y además
  # rompe el «chorrero»: un profesor de bachillerato con veinte asignaciones
  # veía un desplegable de veinte renglones donde tenía que leer para elegir.
  #
  #     GRADO    1er Año · 2do Año · 3er Año …
  #     ÁREA     Matemática · Castellano …        ← solo las de ESE grado
  #     LAPSO    1er · 2do · 3er                  ← solo los de ESE año escolar
  def mis_grados
    @mis_grados ||= mis_asignaciones.map { |ts| ts.section.grade }.uniq
                                    .sort_by { |g| [ g.orden || 99, g.name ] }
  end
  helper_method :mis_grados

  def grado
    @grado ||= mis_grados.find { |g| g.id.to_s == params[:grado] } ||
               asignacion&.section&.grade || mis_grados.first
  end
  helper_method :grado

  # Las secciones de ESTE grado donde dicto ESTA materia. Es lo que decide si
  # hay hermanas a las que copiar.
  # El contexto de la pantalla, para los enlaces que tienen que volver acá.
  #
  # ⚠️ Sale de `asignacion`, no de `params`. Con las pastillas, la asignación se
  # DEDUCE de grado+área, así que `params[:asignacion]` viene vacío la primera
  # vez y todos los enlaces perdían la sección — «Registrar competencia» abría
  # el formulario de otra.
  def contexto
    return {} if asignacion.nil?

    { asignacion: "#{asignacion.section_id}:#{asignacion.subject_id}", lapso: lapso&.id }
  end
  helper_method :contexto

  def mis_areas
    @mis_areas ||= mis_asignaciones.select { |ts| ts.section.grade_id == grado&.id }
                                   .map(&:subject).uniq.sort_by(&:name)
  end
  helper_method :mis_areas

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
