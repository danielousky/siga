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
  include VuelveALaSeccion

  before_action :require_acceso!
  before_action :require_profesor!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_evaluation_activity, only: [:show, :edit, :update, :destroy]

  # ⚠️ Para un PROFESOR, `/evaluaciones` deja de ser destino (etapa ③).
  #
  # Daniel: *«esa vista ya no debe estar, al igual que evaluaciones; volver
  # lleva a evaluaciones sin sección»*. Sus evaluaciones viven en la libreta de
  # cada sección, y un listado que las mezcla todas no dice de cuál es ninguna.
  #
  # ⚠️ A diferencia de `/competencias`, esta pantalla SÍ le sirve a la
  # dirección: es donde contesta «¿este profesor está al día?» sin abrir sus
  # cinco planillas. Por eso redirige solo al profesor.
  #
  # ⚠️ Y lo que ve la dirección es un MAPA de un lapso (`MapaDeEvaluaciones`):
  # una fila por sección, una casilla por área. Eran una barra por sección ×
  # área × lapso de TODOS los años —588 en la muestra— y una tabla paginada con
  # cada evaluación del colegio. Daniel, el 13 de octubre de 2026, eligió el
  # mapa entre tres dibujos. Cada casilla abre el plan de esa sección y esa
  # área, que es donde están las evaluaciones.
  #
  # ⚠️ Del año de la SESIÓN, que la versión anterior no filtraba; con «Todos
  # los años» elegido, del año con clases (`anio_de_trabajo`).
  def index
    return redirect_to(ruta_de_calificar_su_primera)  if profesor? && mis_asignaciones.any?

    @lapsos = anio_de_trabajo ? EvaluationMoment.where(academic_period_id: anio_de_trabajo.id).order(:id).to_a : []
    @lapso  = @lapsos.find { |l| l.id.to_s == params[:lapso] } || MapaDeEvaluaciones.lapso_por_defecto(@lapsos)
    return if @lapso.nil? || profesor?

    @mapa = MapaDeEvaluaciones.new(
      lapso: @lapso,
      secciones: Section.where(academic_period_id: @lapso.academic_period_id).del_nivel_de_la_sesion
    )
  end

  def show
    @notas_cargadas = @evaluation_activity.activity_grades.count
    @inscritos      = @evaluation_activity.section.enrollments.count
  end

  # ⚠️ Nace CON el contexto puesto cuando viene de un enlace (QA del 7 de sept.).
  #
  # Daniel, señalando los dos primeros desplegables: *«vienen del enlace»* —
  # *«este enlace puede llevar ya todas estas características, ¿para qué
  # repedírselas al usuario si vengo de una especificación?»*.
  #
  # Es «no preguntemos lo deducible» en su forma más literal: quien llega desde
  # el plan de 1er Grado B · Matemática · 1er Lapso ya eligió las tres cosas, y
  # volver a preguntárselas no es prudencia, es hacerle repetir. Y peor: puede
  # elegir mal y crear la evaluación en otra sección.
  def new
    @evaluation_activity = EvaluationActivity.new(date_scheduled: fecha_propuesta,
                                                  **atributos_del_enlace)
  end

  def edit; end

  def create
    @evaluation_activity = EvaluationActivity.new(evaluation_activity_params)

    if asignacion_elegida.nil?
      @evaluation_activity.errors.add(:base, "Elija una de sus secciones.")
      return render :new, status: :unprocessable_entity
    end

    # ⚠️ Lo que mide se arma ANTES de guardar, en memoria.
    #
    # No es una preferencia: `mide_una_competencia_y_un_indicador` valida al
    # crear, y una validación no puede mirar filas que todavía no se escriben.
    # Sobre un registro NUEVO esto no escribe nada —Rails guarda las etiquetas
    # después del padre— así que el «una evaluación rechazada dejaba las
    # etiquetas puestas» de `update` no aplica acá.
    etiquetar_lo_que_evalua(@evaluation_activity)

    if @evaluation_activity.save
      # ⚠️ A la LIBRETA de su sección, no a la ficha suelta.
      #
      # Es lo que hace que el `turbo_frame` funcione: el redirect vuelve a la
      # pantalla que contiene el frame «libreta», Turbo lo extrae, y la columna
      # nueva aparece en la tabla mientras el formulario desaparece — todo en
      # una respuesta. Redirigiendo a la ficha, el frame se reemplazaría por
      # una pantalla que no es la libreta.
      redirect_to ruta_de_vuelta(@evaluation_activity), notice: "Evaluación creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ⚠️ La misma acción sirve al formulario COMPLETO y a la edición EN LÍNEA.
  #
  # Daniel, 9 de septiembre: *«para editar dicha evaluación lo haremos desde
  # allí mismo, al hacer clic en el elemento que deseo editar, como lo hace
  # Linear»*. Y con eso el lápiz se retiró: ya no hay una segunda manera.
  #
  # Lo que cambia es la RESPUESTA, no la escritura. Desde el plan llega un solo
  # campo y hay que devolver un pedacito; desde el formulario llegan todos y hay
  # que volver a la pantalla. Un `respond_to` y la misma línea de guardado.
  def update
    # ⚠️ Se comprueba ANTES de escribir nada.
    #
    # Dejarlo para después guardaría el nombre y el peso y recién ahí diría que
    # no: el profesor lee un error habiendo cambiado la mitad de lo que pidió.
    return responder_al_fallo if quiere_quedarse_sin_competencias?

    unless @evaluation_activity.update(evaluation_activity_params)
      return responder_al_fallo
    end

    if params[:evaluation_activity].key?(:competency_ids)
      etiquetar_lo_que_evalua(@evaluation_activity)
    end
    responder_al_exito
  end

  # ⚠️ El fallo vuelve al MISMO sitio, no a la ficha de la evaluación.
  #
  # Una evaluación con notas cargadas no se borra (`restrict_with_error`), y el
  # error redirigía al `show` — una pantalla que NO tiene el frame «plan». Turbo
  # pedía «plan», recibía una respuesta sin él, y escribía «Content missing»
  # donde estaba la planificación entera. Lo reportó Daniel el 8 de septiembre.
  #
  # Es la misma lección que el frame fijo de `new`, del otro lado: dentro de un
  # frame, el destino de un redirect tiene que contener ese frame.
  def destroy
    # ⚠️ La ruta se arma ANTES de borrar: después el objeto ya no puede
    # resolver su sección para armarla.
    volver_a = ruta_de_vuelta(@evaluation_activity) || evaluation_activities_path

    if @evaluation_activity.destroy
      redirect_to volver_a, notice: "Evaluación eliminada."
    else
      redirect_to volver_a, alert: @evaluation_activity.errors.full_messages.to_sentence
    end
  end

  private

  # ⚠️ La fecha nace DENTRO del año escolar, no en «hoy».
  #
  # Nacía en `Date.current`, y en septiembre de 2026 eso cae FUERA del año
  # 2025-2026 —que terminó el 31 de julio—: el campo la rechazaba con «el valor
  # debe ser igual o anterior a 31/07/2026» y el alta no se podía guardar sin
  # tocar la fecha primero. Se ve entrando a un año escolar ya cerrado, que es
  # exactamente lo que hace un profesor al revisar lo del año pasado.
  #
  # Hoy si cabe, y si no el primer día del año: es la misma regla con la que el
  # calendario del plan elige por dónde abrirse.
  def fecha_propuesta
    periodo = asignacion_del_enlace&.section&.academic_period
    return Date.current if periodo.nil?

    Date.current.clamp(periodo.start_date, periodo.end_date)
  end

  # ── Contestar a quien preguntó ────────────────────────────────────────────
  #
  # ⚠️ Editando en línea NO se recarga el plan entero: se devuelven la FILA y la
  # cuenta de la ponderación, que son las dos cosas que cambiaron. Recargar todo
  # se lleva el foco del teclado —y el profesor está tabulando entre campos—,
  # además de cerrar el calendario que acaba de abrir.
  #
  # ⚠️ Y NO se manda un flash. Un aviso por cada campo tocado —tres por
  # evaluación, treinta por plan— convierte la pantalla en una alarma. Acá el
  # feedback es que el valor quedó: la fila vuelve con un destello y la barra
  # ya se movió sola mientras se escribía. Un flash es para lo que no se ve.
  def responder_al_exito
    return redirect_to(ruta_de_vuelta(@evaluation_activity), notice: "Evaluación actualizada.") unless en_linea?

    # ⚠️ Cambiar QUÉ MIDE mueve la fila de sitio —el plan agrupa por
    # competencia— así que devolver la fila en su lugar viejo la dejaría bajo
    # una competencia que ya no mide. Eso se recarga entero.
    return redirect_to(ruta_de_vuelta(@evaluation_activity)) if cambio_el_enganche?

    render turbo_stream: filas_a_refrescar + [
      turbo_stream.replace("cuenta-de-la-ponderacion", partial: "competencies/cuenta",
                                                            locals: { usado: peso_repartido })
    ]
  end

  # ⚠️ El fallo devuelve la MISMA fila, con el valor viejo y el motivo.
  #
  # Sin esto el campo se queda con lo que el profesor escribió y él se va
  # convencido de que quedó guardado — que es la falla clásica de la edición en
  # línea: no hay botón que se quede apretado para delatar que algo no pasó.
  def responder_al_fallo
    return render(:edit, status: :unprocessable_entity) unless en_linea?

    @evaluation_activity.reload
    render turbo_stream: turbo_stream.replace(
      helpers.id_de_la_fila(@evaluation_activity, fila_del_plan[:competencia]),
      partial: "competencies/evaluacion",
      locals: fila_del_plan.merge(error: errores_de_la_fila)
    ), status: :unprocessable_entity
  end

  # ⚠️ El contexto se arma de los PARÁMETROS, no del helper del plan.
  #
  # `contexto` es un `helper_method` de `MuestraElPlan`, que este controller no
  # incluye —ni debe: arrastraría `asignacion`, las hermanas y el año pasado—.
  # La URL ya trae las tres piezas, porque el propio formulario las puso ahí.
  def fila_del_plan
    { evaluacion: @evaluation_activity,
      contexto: params.permit(:asignacion, :lapso, :desde).to_h.symbolize_keys,
      # Bajo qué competencia está dibujada esta fila, para que su chip nombre
      # LAS OTRAS y no repita la de arriba.
      competencia: @evaluation_activity.competencies.find { |c| c.id.to_s == params[:bajo].to_s },
      competencias: Competency.del_plan(@evaluation_activity.section_id,
                                        @evaluation_activity.subject_id,
                                        @evaluation_activity.evaluation_moment_id).to_a }
  end

  # Lo que suma el lapso DESPUÉS de guardar: es lo que la cuenta tiene que
  # confirmar. La barra ya se movió sola con Stimulus mientras se escribía.
  def peso_repartido
    EvaluationActivity.peso_usado(
      section_id: @evaluation_activity.section_id,
      subject_id: @evaluation_activity.subject_id,
      evaluation_moment_id: @evaluation_activity.evaluation_moment_id
    ).to_f
  end

  # ⚠️ TODAS las apariciones de la evaluación, no solo la que se tocó.
  #
  # Una que mide dos competencias sale dos veces, y las dos son el mismo dato:
  # cambiar su peso arriba dejaba el de abajo con el valor viejo —27 % y 22 % en
  # la misma pantalla— sin que ninguno fuera mentira por sí solo.
  #
  # Si no mide ninguna, su única aparición es la del bloque de las sueltas, que
  # no cuelga de ninguna competencia.
  def filas_a_refrescar
    donde = @evaluation_activity.competencies.to_a
    donde = [ nil ] if donde.empty?

    donde.map do |competencia|
      turbo_stream.replace(helpers.id_de_la_fila(@evaluation_activity, competencia),
                           partial: "competencies/evaluacion",
                           locals: fila_del_plan.merge(competencia: competencia, guardada: true))
    end
  end

  def errores_de_la_fila = @evaluation_activity.errors.full_messages.to_sentence.presence

  # ⚠️ Lo dice el FORMULARIO, con un parámetro, y no se deduce del `Accept`.
  #
  # `request.format.turbo_stream?` parecía suficiente y no lo es: Turbo pide
  # turbo_stream en TODO envío, así que el formulario completo del `edit`
  # entraría por acá y contestaría reemplazando una fila que esa pantalla no
  # tiene. Quien sabe de dónde viene es quien lo manda.
  def en_linea? = params[:en_linea].present?

  def cambio_el_enganche? = params[:evaluation_activity].key?(:competency_ids)


  # El conjunto que este usuario puede siquiera nombrar. `find` sale de acá, así
  # que pedir el id de una evaluación ajena da 404 y no 403: no se confirma que
  # exista.
  # ⚠️ Y el NIVEL de la sesión (MOR-223). Un profesor que da primaria y media
  # veía las dos listas mezcladas y sin división. Daniel: *«mira eso: primaria y
  # media juntos y sin división… no trabajas las cosas juntas»*.
  #
  # Va acá y no en `index` para que alcance también a `show`, `edit` y a la
  # planilla de notas: si el listado esconde una sección, entrar a su evaluación
  # por el botón de atrás no puede devolver algo que la pantalla anterior dijo
  # que no existe.
  def alcance
    base = profesor? ? EvaluationActivity.dictadas_por(current_user.teacher) : EvaluationActivity.all

    base.del_nivel_de_la_sesion
  end

  def set_evaluation_activity
    @evaluation_activity = alcance.find(params[:id])
  end

  # Las asignaciones del profesor: cada par sección–materia que dicta.
  #
  # ⚠️ Por el AÑO y por el NIVEL de la sesión, y las dos hacen falta.
  #
  # Sin el AÑO, el desplegable mostraba cada sección DOS VECES —«1er Año A ·
  # Matemática» arriba de «1er Año A · Matemática»— porque un colegio que ya
  # copió su estructura al año siguiente tiene las mismas secciones en los dos.
  # Daniel lo vio en una lista de treinta y dos renglones donde había dieciséis
  # asignaciones. Y no era solo feo: el segundo renglón crea la evaluación en el
  # año que viene, sin que nada lo diga.
  #
  # Sin el NIVEL, el desplegable ofrece lo que el listado esconde, y el profesor
  # crea una evaluación en una sección que su pantalla no le muestra.
  #
  # ⚠️ Ordenadas por el ORDEN OFICIAL del grado, no por su nombre: «10mo» iría
  # antes que «2do» alfabéticamente el día que un colegio cargue esos nombres.
  def mis_asignaciones
    @mis_asignaciones ||= current_user.teacher
      .teacher_sections
      .del_anio_de_la_sesion
      .del_nivel_de_la_sesion
      .includes(:subject, section: [:grade, :academic_period])
      .sort_by { |ts| [ts.section.grade.orden || 99, ts.section.name, ts.subject.name] }
  end
  helper_method :mis_asignaciones

  # Las ÁREAS que dicta este profesor, para el primer select del formulario.
  #
  # ⚠️ Dos selects y no uno (MOR-223). Daniel: *«esto lo separamos en 2 selects:
  # si el profe solo da una materia pues vamos directo, pero si dicta más de
  # una, le colocamos el select previo»*.
  #
  # Con uno solo, el profesor de Matemática con dieciséis secciones abría un
  # desplegable de dieciséis renglones donde tenía que LEER cada uno para
  # elegir, y las quince que no eran la suya solo estorbaban. Partido en área →
  # sección, la primera lista tiene un renglón para él y la segunda tiene las
  # suyas.
  def mis_areas
    @mis_areas ||= mis_asignaciones.map(&:subject).uniq.sort_by(&:name)
  end
  helper_method :mis_areas

  # ⚠️ Con UNA sola área no hay primer select: un desplegable de una opción es
  # un control que no decide nada, y le agrega un paso a quien no tiene nada
  # que elegir. Es la misma regla del selector de nivel y la del año escolar.
  def hay_area_que_elegir? = mis_areas.many?
  helper_method :hay_area_que_elegir?

  # El área elegida, o la única que dicta.
  def area_elegida
    return @area_elegida if defined?(@area_elegida)

    pedida = params.dig(:evaluation_activity, :area).presence || @evaluation_activity&.subject_id
    @area_elegida = mis_areas.find { |s| s.id.to_s == pedida.to_s } || mis_areas.first
  end
  helper_method :area_elegida

  # Las secciones donde dicta ESA área.
  def mis_secciones_del_area
    @mis_secciones_del_area ||= mis_asignaciones.select { |ts| ts.subject_id == area_elegida&.id }
  end
  helper_method :mis_secciones_del_area

  # Las secciones de cada área, para que el segundo select cambie sin ir al
  # servidor. Es el mismo patrón que `ponderacion` y `que-evalua`: la elección
  # ocurre en esta pantalla, así que la respuesta tiene que estar acá.
  def secciones_por_area
    mis_asignaciones.group_by(&:subject_id).transform_values do |asignaciones|
      asignaciones.map do |ts|
        { valor: "#{ts.section_id}:#{ts.subject_id}",
          nombre: "#{ts.section.grade.name} – #{ts.section.name}" }
      end
    end
  end
  helper_method :secciones_por_area

  # ── Lo que llega por el enlace, ya decidido ───────────────────────────────
  #
  # `asignacion` («seccion:materia») y `lapso`, más `competencia` para dejarla
  # marcada. Los tres son opcionales: entrar por «Mis evaluaciones» sigue dando
  # el formulario completo.
  #
  # ⚠️ Se busca ENTRE LAS DEL PROFESOR, igual que `asignacion_elegida`, y eso es
  # lo que autoriza: un id de la sección de otro simplemente no aparece y queda
  # en nil, sin 403 que confirme que existe.
  def asignacion_del_enlace
    return @asignacion_del_enlace if defined?(@asignacion_del_enlace)

    seccion, materia = params[:asignacion].to_s.split(":")
    @asignacion_del_enlace = mis_asignaciones.find do |ts|
      ts.section_id.to_s == seccion && ts.subject_id.to_s == materia
    end
  end
  helper_method :asignacion_del_enlace

  # ⚠️ El lapso se valida contra el AÑO ESCOLAR de esa sección, no contra los del
  # colegio. Un lapso del año que viene sobre una sección de este año crea una
  # evaluación que no existe para nadie.
  def lapso_del_enlace
    return @lapso_del_enlace if defined?(@lapso_del_enlace)

    return @lapso_del_enlace = nil unless asignacion_del_enlace && params[:lapso].present?

    @lapso_del_enlace =
      EvaluationMoment.find_by(id: params[:lapso],
                               academic_period_id: asignacion_del_enlace.section.academic_period_id)
  end
  helper_method :lapso_del_enlace

  # Si el contexto viene entero, la pantalla no lo pregunta: lo muestra.
  def contexto_del_enlace? = asignacion_del_enlace.present? && lapso_del_enlace.present?
  helper_method :contexto_del_enlace?

  def atributos_del_enlace
    return {} unless contexto_del_enlace?

    { section_id: asignacion_del_enlace.section_id,
      subject_id: asignacion_del_enlace.subject_id,
      evaluation_moment_id: lapso_del_enlace.id }
  end

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

  # Qué competencias del plan evalúa esta actividad (MOR-136).
  #
  # ⚠️ Se guarda APARTE del resto de los atributos, y después de guardar la
  # actividad. Con `competency_ids` dentro de `update`, Rails escribe las
  # etiquetas ANTES de validar la actividad: una evaluación rechazada por peso
  # dejaba las etiquetas puestas de todos modos.
  #
  # ⚠️ Y se filtra contra el plan de ESTA sección, materia y lapso. El modelo ya
  # lo valida —`la_competencia_es_del_mismo_plan`— pero ahí es una excepción a
  # mitad de un guardado; acá es simplemente una lista que no incluye lo ajeno.
  def etiquetar_lo_que_evalua(actividad)
    pedidas = Array(params[:evaluation_activity][:competency_ids]).compact_blank.map(&:to_i)

    del_plan = Competency.del_plan(actividad.section_id, actividad.subject_id,
                                   actividad.evaluation_moment_id).pluck(:id)
    actividad.competency_ids = pedidas & del_plan

    # ⚠️ Los indicadores de una competencia que ya no mide SE BORRAN.
    #
    # Sin esto queda un indicador apuntando a una evaluación que no mide su
    # competencia: nadie lo ve, `Indicator` lo rechazaría si alguien lo tocara,
    # y la boleta imprimiría una línea bajo una competencia que esa evaluación
    # no midió.
    #
    # ⚠️ Se borran y no se sueltan, por lo mismo que al borrar la evaluación
    # (22 de septiembre): uno sin evaluación no se imprime ni se ve, así que
    # «conservarlo» sería guardar un dato que nadie va a volver a encontrar.
    return if actividad.new_record?

    actividad.indicators.where.not(competency_id: actividad.competency_ids).destroy_all
  end

  # ⚠️ Los INDICADORES ya no llegan por acá (23 de septiembre).
  #
  # Se marcaban en el alta —una lista de casillas más un textarea de «uno por
  # línea»— y eso era una SEGUNDA manera de hacer lo que la fila del plan ya
  # hacía uno por uno. Daniel: *«¿te parece bien que haya 2 maneras distintas de
  # hacer lo mismo?… parece que fueran desarrollos distintos»*.
  #
  # Ahora la evaluación nace sola y sus indicadores se escriben en su fila, con
  # `IndicatorsController`. Lo que sí queda es SOLTAR los de una competencia que
  # la evaluación deja de medir, arriba.

  # ⚠️ Desmarcar la última competencia deja una evaluación que no mide nada.
  #
  # El chip del plan no puede llegar acá —dibuja «las OTRAS», así que nunca
  # ofrece quitar la única—, pero el formulario completo sí: se desmarcan las
  # casillas y se guarda. La regla es la misma que al crear, y el error se dice
  # con las palabras de esa pantalla.
  # ⚠️ Se mira la lista YA FILTRADA contra el plan, no la que llegó.
  #
  # Con la lista cruda alcanzaba con mandar el id de una competencia ajena —de
  # otro colegio, de otra sección— para que el filtro la dejara en cero y la
  # evaluación terminara sin medir nada. Pasar el filtro acá es además lo que
  # hace que este control y `etiquetar_lo_que_evalua` no puedan discrepar.
  def quiere_quedarse_sin_competencias?
    return false unless params[:evaluation_activity]&.key?(:competency_ids)
    return false unless @evaluation_activity.por_competencias?
    return false if competencias_pedidas_del_plan.any?

    @evaluation_activity.errors.add(:base, "Marque la competencia que mide: sin eso no puede salir en la boleta.")
    true
  end

  def competencias_pedidas_del_plan
    pedidas = Array(params[:evaluation_activity][:competency_ids]).compact_blank.map(&:to_i)
    pedidas & Competency.del_plan(@evaluation_activity.section_id, @evaluation_activity.subject_id,
                                  @evaluation_activity.evaluation_moment_id).pluck(:id)
  end

  # La libreta de la primera sección que dicta. Es a donde va un profesor que
  # llegó a `/evaluaciones` por un enlace viejo: no hay una respuesta mejor que
  # «tu primera sección», y desde el árbol del menú llega a las otras.
  def ruta_de_calificar_su_primera
    primera = mis_asignaciones.min_by { |ts| [ ts.section.grade.orden || 99, ts.section.name ] }

    section_path(primera.section_id, area: primera.subject_id)
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

  # El plan de competencias de cada asignación, para el formulario (MOR-136).
  #
  # ⚠️ Va EMBEBIDO en el formulario, igual que la ponderación, y por la misma
  # razón: la sección y el lapso se eligen ahí mismo, así que las competencias
  # tienen que cambiar mientras la persona elige — no después de enviar.
  #
  # ⚠️ Y solo las secciones de PRIMARIA. Un profesor de bachillerato no tiene
  # plan por competencias, así que su mapa queda vacío y el bloque entero no
  # aparece en la pantalla: no hay nada que ofrecerle. Eso es además lo que
  # mantiene chico el JSON — un maestro de primaria tiene dos o tres secciones,
  # no diecinueve.
  def competencias_de_mis_asignaciones
    return {} if asignaciones_por_competencias.empty?

    planes = Competency.where(section_id: asignaciones_por_competencias.map(&:section_id))
                       .includes(:indicators).order(:orden, :id)

    planes.each_with_object({}) do |competencia, mapa|
      clave = "#{competencia.section_id}:#{competencia.subject_id}:#{competencia.evaluation_moment_id}"
      (mapa[clave] ||= []) << {
        id: competencia.id,
        texto: competencia.descripcion,
        # ⚠️ Solo el TEXTO: van de contexto, para reconocer cuál competencia es
        # cuál cuando dos se parecen. Llegaron a viajar con su estado —libre,
        # quién lo mide— para poder marcarlos acá, y eso duró dos días: marcar
        # indicadores en este formulario era una segunda manera de hacer lo que
        # la fila del plan ya hace.
        indicadores: competencia.indicators.map { |i| { texto: i.descripcion } }
      }
    end
  end
  helper_method :competencias_de_mis_asignaciones

  # Las asignaciones de este profesor que SE EVALÚAN POR COMPETENCIAS.
  #
  # ⚠️ Es la pregunta que decide si el bloque «Qué evalúa» aparece, y **no** es
  # «¿ya tiene competencias escritas?». Con esa otra, el maestro que estrena su
  # primer plan no veía el bloque —ni su botón [+]— justamente cuando iba a
  # escribir la primera. Es el caso del colegio nuevo, que es el caso normal.
  #
  # Un profesor de bachillerato sigue sin verlo: su grado no evalúa por
  # competencias, y un titulito sobre un vacío permanente le enseña a ignorar
  # esa zona del formulario.
  #
  # Se pregunta por `Grade#por_competencias?` y no por «primaria» a mano: es la
  # misma pregunta que hacen `CompetenciesController` y el menú.
  def asignaciones_por_competencias
    return [] unless profesor?

    @asignaciones_por_competencias ||= mis_asignaciones.select { |ts| ts.section.grade.por_competencias? }
  end
  helper_method :asignaciones_por_competencias

  # Las que esta evaluación ya tiene marcadas — más la que trajo el enlace.
  #
  # ⚠️ Quien llega desde «Resuelve problemas de adición… + Registrar una
  # evaluación» viene a medir ESA competencia. Que llegue desmarcada le pide
  # buscarla de nuevo en una lista donde ya sabe cuál es, y si se olvida de
  # marcarla la evaluación no mide nada — que es exactamente el agujero que
  # `MOR-229` vino a tapar.
  #
  # Se filtra contra el plan real, igual que al guardar: un id de la competencia
  # de otro simplemente no está en la lista.
  def competencias_marcadas
    @competencias_marcadas ||= begin
      ya = @evaluation_activity&.competency_ids || []
      ya | competencia_del_enlace
    end
  end
  helper_method :competencias_marcadas



  def competencia_del_enlace
    return [] unless contexto_del_enlace? && params[:competencia].present?

    Competency.del_plan(asignacion_del_enlace.section_id, asignacion_del_enlace.subject_id,
                        lapso_del_enlace.id)
              .where(id: params[:competencia]).pluck(:id)
  end

  def require_acceso!
    return if profesor? || puede_supervisar?

    redirect_to dashboard_path_for_user, alert: "Acceso no autorizado."
  end

  def require_profesor!
    return if profesor?

    redirect_to evaluation_activities_path,
                alert: "La ponderación la define el profesor que dicta el área."
  end

  # Dirección y coordinación ven las evaluaciones del colegio, sin editarlas.
  def puede_supervisar?
    can_manage_sections?
  end
  helper_method :puede_supervisar?
end
