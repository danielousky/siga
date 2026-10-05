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
  include MuestraElPlan
  include VuelveALaSeccion

  before_action :require_acceso!
  before_action :require_profesor!, except: [ :index ]
  before_action :set_competency, only: [ :edit, :update, :destroy ]

  # ⚠️ `/competencias` DEJÓ DE SER UNA PANTALLA (etapa ③).
  #
  # Daniel, al caer acá cancelando un formulario: *«cancelar me lleva a
  # competencias solo… esa vista ya no debe estar»*.
  #
  # Y al ir a arreglarlo apareció la razón de fondo: esta pantalla **solo
  # funcionaba para profesores**. Su escalera —grado → área → sección → lapso—
  # se alimenta de `mis_asignaciones`, que para la dirección está vacía: un
  # director que entraba veía «todavía no tienes secciones asignadas».
  #
  # O sea que, con el profesor entrando por el árbol del menú —que ya trae las
  # cuatro cosas—, la pantalla no le servía a nadie. Lo que queda es un
  # redirector:
  #
  #     PROFESOR    → la pestaña «Planificar» de su sección
  #     DIRECCIÓN   → el listado de secciones, para elegir a cuál entrar
  #
  # ⚠️ Las OTRAS acciones de este controller siguen vivas —crear, editar,
  # copiar, traer—: lo que se retira es el índice, no el plan.
  def index
    return redirect_to(ruta_de_planificar(asignacion, lapso)) if asignacion

    redirect_to sections_path,
                notice: "El plan de evaluación se abre desde su sección, en la pestaña «Planificar»."
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

  # ⚠️ Editar una competencia YA NO toca sus indicadores.
  #
  # Había un `destroy_all` condicional para el textarea del formulario completo,
  # que los reemplazaba enteros. Ese campo se retiró: los indicadores cuelgan de
  # su evaluación y se editan ahí, uno por uno. Borrarlos desde esta acción
  # ahora sería borrar el trabajo de tres evaluaciones por corregir una tilde.
  def update
    unless @competency.update(datos_de_la_competencia)
      return en_linea? ? fila_con_el_error : render(:edit, status: :unprocessable_entity)
    end

    return redirect_to(plan_path, notice: "Competencia actualizada.") unless en_linea?

    render turbo_stream: turbo_stream.replace(helpers.dom_id(@competency),
                                              partial: "competencies/competencia",
                                              locals: bloque_de_la_competencia(guardada: true))
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
  #
  # ⚠️ Y viene TODO: competencias, indicadores y evaluaciones, con la fecha
  # corrida un año. Daniel: *«copiamos competencias, indicadores y evaluaciones,
  # se le coloca el mismo mes y día del año pasado pero con el año actual»*.
  #
  # Es lo que pedía Cyndi, que es de donde sale MOR-136: *«nosotros todos los
  # lapsos tenemos que estar cargando competencias e indicadores… es de verdad
  # una pérdida de tiempo muy grande»*.
  def sugerido
    return redirect_to(plan_path, alert: "Elige tu sección y el lapso.") if asignacion.nil? || lapso.nil?

    origen = origen_del_ano_pasado
    return redirect_to(plan_path, alert: "No hay un plan del año pasado que traer.") if origen.nil?

    hecho = ReplicarLaPlanificacion.del_ano_pasado(
      desde: origen[:asignacion], lapso_de_origen: origen[:lapso],
      hacia: asignacion, lapso: lapso,
      # ⚠️ Las evaluaciones solo si ESTE profesor dictaba esa sección el año
      # pasado. Ver `MuestraElPlan#plan_sugerido_con_evaluaciones?`.
      con_evaluaciones: origen[:mismo_profesor]
    )

    redirect_to plan_path, notice: resumen_de_lo_traido(hecho),
                           alert: hecho.avisos.presence&.join(" ")
  end

  # Qué evaluaciones MIDEN esta competencia (MOR-136).
  #
  # ## El enganche existía y no se descubría
  #
  # Al crear una evaluación se marca qué evalúa, y eso está desde el principio.
  # Pero solo funciona en esa dirección, y **el orden real del trabajo es el
  # contrario**: el profesor escribe su plan, arma sus evaluaciones, y si se
  # olvidó de marcar no tenía forma de arreglarlo salvo editando una por una —
  # sin saber cuáles le faltaban.
  #
  # Daniel: *«no sé cómo asociamos las evaluaciones con los indicadores.
  # RECUERDA UX, debe ser un proceso fácil y fluido»*.
  #
  # ⚠️ Reemplaza, no suma: la lista que llega es la lista completa. Es lo mismo
  # que hacen los indicadores al editar una competencia, y por la misma razón —
  # la persona ve todas las casillas, así que desmarcar tiene que quitar.
  # Copiar este plan a las otras secciones donde ESTE profesor dicta la misma
  # materia. Daniel: *«darle la opción de copiar el plan al resto de las
  # secciones que él dicta»*.
  # ⚠️ Copia la planificación ENTERA, no solo las competencias.
  #
  # Daniel: *«él puede clonar o copiar esa planificación de esa sección… debería
  # haber una opción de replicar a las otras secciones hermanas»*. Copiar solo
  # las competencias dejaba la mitad del trabajo: un profesor con tres secciones
  # hermanas escribía las mismas cuatro evaluaciones doce veces.
  def copiar
    return redirect_to(plan_path, alert: "Elige tu sección y el lapso.") if asignacion.nil? || lapso.nil?

    resultados = otras_secciones.map do |destino|
      ReplicarLaPlanificacion.para(desde: asignacion, hacia: destino, lapso: lapso)
    end

    redirect_to plan_path, notice: resumen_de_la_copia(resultados),
                           alert: resultados.flat_map(&:avisos).presence&.join(" ")
  end

  private

  # ── La edición en su sitio ────────────────────────────────────────────────
  #
  # Misma mecánica que la evaluación: lo dice el formulario con un parámetro y
  # no se deduce del `Accept`, porque Turbo pide turbo_stream en TODO envío y el
  # formulario completo entraría por acá.
  def en_linea? = params[:en_linea].present?

  def bloque_de_la_competencia(guardada: false)
    { competencia: @competency, contexto: contexto,
      competencias: competencias_del_lapso, guardada: guardada,
      error: (@competency.errors.full_messages.to_sentence.presence unless guardada) }
  end

  # ⚠️ Vuelve el bloque con el valor VIEJO y el motivo. Sin esto el campo se
  # queda con lo que el profesor escribió y él se va convencido de que quedó
  # guardado: en la edición en línea no hay botón que se quede apretado para
  # delatar que algo no pasó.
  def fila_con_el_error
    errores = @competency.errors.full_messages.to_sentence
    @competency.reload

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@competency), partial: "competencies/competencia",
      locals: bloque_de_la_competencia.merge(error: errores)
    ), status: :unprocessable_entity
  end

  # ── El alcance: lo que este usuario puede siquiera nombrar ────────────────

  def set_competency
    @competency = Competency.del_plan(asignacion&.section_id, asignacion&.subject_id, lapso&.id)
                            .find(params[:id])
  end

  # Las asignaciones del profesor: cada par sección–materia que dicta.
  # Es el MISMO método de `EvaluationActivitiesController`, y acotar la búsqueda
  # a `current_user.teacher` es lo que autoriza.
  # ⚠️ Del AÑO y del NIVEL de la sesión.
  #
  # Un colegio que ya copió su estructura al año siguiente tiene las MISMAS
  # secciones dos veces —«1er Año A» de 2025-2026 y «1er Año A» de 2026-2027—
  # y sin filtrar salían las veinte. Se vio en pantalla como «Copiar a 1er Año
  # A, B y B»: dos secciones B, la de este año y la del pasado.
  #
  # Lo cosmético era lo de menos. Copiar hacia el año anterior escribe un plan
  # en un lapso ya cerrado, y el profesor no tiene selector de año para darse
  # cuenta (`LlevaElAnioEscolar`: «los docentes solo ven lo que están
  # calificando»).
  #
  # ⚠️ Y solo los grados que EVALÚAN POR COMPETENCIAS. Ver `Grade#por_competencias?`.
  #
  # ⚠️ El NIVEL de la sesión también (MOR-223): un profesor que da primaria y
  # media veía las dieciséis secciones juntas en la escalera de grados. Daniel:
  # *«no trabajas las cosas juntas, primero haces primaria y luego media»*.
  #
  # ⚠️ Ordenadas por el ORDEN OFICIAL del grado, no por su nombre: «10mo» iría
  # antes que «2do» alfabéticamente el día que un colegio cargue esos nombres.
  def mis_asignaciones
    return @mis_asignaciones if defined?(@mis_asignaciones)
    return @mis_asignaciones = [] unless profesor?

    @mis_asignaciones = current_user.teacher.teacher_sections
                                    .del_anio_de_la_sesion
                                    .del_nivel_de_la_sesion
                                    .includes(:subject, section: [ :grade, :academic_period ])
                                    .select { |ts| ts.section.grade.por_competencias? }
                                    .sort_by { |ts| [ ts.section.grade.orden || 99, ts.section.name, ts.subject.name ] }
  end
  helper_method :mis_asignaciones

  # Todo lo que dicta este profesor, sin el filtro de competencias.
  #
  # Sirve para distinguir dos vacíos que se ven igual y no lo son: «todavía no
  # te asignaron nada» y «lo tuyo es bachillerato, que no se evalúa así». El
  # segundo no es un problema que el profesor pueda resolver, y decirle que
  # espere a que la dirección le asigne una materia sería mentirle.
  def dicta_solo_media?
    return false unless profesor?

    mis_asignaciones.empty? &&
      current_user.teacher.teacher_sections.del_anio_de_la_sesion.exists?
  end
  helper_method :dicta_solo_media?

  # La asignación elegida. Puede venir entera —`sección:materia`, que es lo que
  # guardan los enlaces— o deducirse de las pastillas de grado y área.
  #
  # ⚠️ La búsqueda va SIEMPRE contra `mis_asignaciones`, y eso es lo que
  # autoriza: un id de la sección de otro profesor no está en la lista y
  # devuelve nil, así que no hace falta comprobar permisos aparte.
  # ⚠️ La búsqueda va contra TODO lo que el profesor dicta, no contra
  # `mis_asignaciones`, que además filtra los grados que evalúan POR
  # COMPETENCIAS.
  #
  # Ese filtro es de la ESCALERA —lo que se ofrece elegir en `/competencias`,
  # que es primaria— y nunca fue una regla de permisos. Desde que Educación
  # Media planifica en la misma pantalla (10 de septiembre), su botón «Duplicar
  # en 1er Año B» apuntaba acá con una sección que la lista filtrada NO
  # contiene:
  #
  #     POST /competencias/copiar?asignacion=85:240&lapso=306
  #       └─► asignacion = nil
  #           └─► Redirected to /competencias?asignacion=:   ← sin ids
  #               └─► Redirected to /secciones  →  «Content missing»
  #
  # Se leyó en el log del servidor de Daniel.
  #
  # ⚠️ Lo que AUTORIZA sigue siendo la lista: es la de ESTE profesor, así que un
  # id de la sección de otro no está y devuelve nil.
  def asignacion
    return @asignacion if defined?(@asignacion)

    seccion, materia = params[:asignacion].to_s.split(":")
    @asignacion = todo_lo_que_dicta.find do |ts|
      ts.section_id.to_s == seccion && ts.subject_id.to_s == materia
    end

    @asignacion ||= por_pastillas
  end

  # El plan —y sus hermanas— trabajan sobre TODO lo que dicta, no sobre la lista
  # filtrada de la escalera. Sin esto, una sección de Media no tenía hermanas y
  # «Duplicar en 1er Año B» respondía bien sin copiar nada.
  def asignaciones_del_plan = todo_lo_que_dicta

  # Todo lo que dicta, del año y el nivel de la sesión — sin el filtro de
  # competencias, que es de la escalera.
  def todo_lo_que_dicta
    return [] unless profesor?

    @todo_lo_que_dicta ||= current_user.teacher.teacher_sections
                                       .del_anio_de_la_sesion
                                       .del_nivel_de_la_sesion
                                       .includes(:subject, section: [ :grade, :academic_period ])
                                       .to_a
  end

  helper_method :asignacion

  # ⚠️ La SECCIÓN también entra en la deducción (QA de Daniel).
  #
  # Antes la escalera llegaba hasta el lapso y la sección se elegía sola: la
  # primera del grado. Daniel: *«no me queda claro y evidente en la vista que lo
  # que estoy editando son las competencias de la sección A… tampoco tengo desde
  # acá la posibilidad de editar las competencias de la sección B»*.
  #
  # Ahora es la cuarta pregunta de la escalera y viaja en la URL como las otras.
  def por_pastillas
    del_grado = mis_asignaciones.select { |ts| ts.section.grade_id == grado_pedido&.id }
    del_grado = mis_asignaciones if del_grado.empty?

    del_area = del_grado.select { |ts| ts.subject_id.to_s == params[:area] }
    candidatas = del_area.presence || del_grado

    de_la_seccion = candidatas.select { |ts| ts.section_id.to_s == params[:seccion] }
    (de_la_seccion.presence || candidatas).first
  end

  # El grado pedido, sin pasar por `asignacion` — o sería una recursión.
  def grado_pedido
    @grado_pedido ||= mis_asignaciones.map { |ts| ts.section.grade }
                                      .find { |g| g.id.to_s == params[:grado] }
  end




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


  def mis_areas
    @mis_areas ||= mis_asignaciones.select { |ts| ts.section.grade_id == grado&.id }
                                   .map(&:subject).uniq.sort_by(&:name)
  end
  helper_method :mis_areas

  # ⚠️ Con UNA sola área en este grado, la fila de pastillas no se dibuja.
  #
  # Daniel: *«si es una sola materia que dicto, no debería aparecer la opción de
  # selección sino ir directo al siguiente nivel, es redundante»*. Es la misma
  # regla que ya siguen el selector de nivel, el de año escolar y el del área en
  # el formulario de evaluación: un control de una opción no decide nada y
  # agrega un renglón que hay que leer.
  def hay_area_que_elegir? = mis_areas.many?
  helper_method :hay_area_que_elegir?

  # Las secciones de este grado donde dicto esta área — incluida la que estoy
  # mirando. Son las pestañas.
  #
  # ⚠️ Se ordena por el identificador, que es como el colegio las nombra: «A»,
  # «B», «U1». Sin orden, dos cargas de la misma pantalla las ponen distinto.
  def mis_secciones_del_area
    @mis_secciones_del_area ||= mis_asignaciones
                                .select { |ts| ts.section.grade_id == grado&.id &&
                                               ts.subject_id == asignacion&.subject_id }
                                .sort_by { |ts| ts.section.name }
  end
  helper_method :mis_secciones_del_area

  def hay_seccion_que_elegir? = mis_secciones_del_area.many?
  helper_method :hay_seccion_que_elegir?




  # ⚠️ Para un PROFESOR, siempre la pestaña de su sección.
  #
  # La primera versión miraba `params[:desde]`, y por eso «Cancelar» —que no lo
  # llevaba— lo dejaba en `/competencias` a secas. Daniel: *«cancelar me lleva a
  # competencias solo; esa vista ya no debe estar»*.
  #
  # La bandera sobraba: si el trabajo del profesor es por sección, no hay un
  # caso en que quiera volver al listado global. La dirección sí, y ahí `plan_path`
  # sigue siendo el listado.
  def plan_path
    return ruta_de_planificar(asignacion, lapso) if profesor? && asignacion

    competencies_path(asignacion: "#{asignacion&.section_id}:#{asignacion&.subject_id}",
                      lapso: lapso&.id)
  end
  helper_method :plan_path

  # ⚠️ Dice qué llegó, separando las dos cosas: el plan y las evaluaciones que
  # lo miden. «Se trajeron 3 competencias» callaba que además vinieron cuatro
  # evaluaciones con su peso y su fecha, que es la mitad del ahorro.
  def resumen_de_lo_traido(hecho)
    return "El plan del año pasado ya estaba completo acá." if hecho.nada?

    partes = []
    partes << helpers.contar(hecho.competencias, "competencia", "competencias") if hecho.competencias.positive?
    partes << helpers.contar(hecho.evaluaciones, "evaluación", "evaluaciones") if hecho.evaluaciones.positive?

    # ⚠️ El cierre cambia según haya venido o no la ponderación: sin
    # evaluaciones, «revisa las fechas» habla de algo que no llegó, y lo que
    # sigue es otra cosa — armarlas.
    cierre = hecho.evaluaciones.positive? ? "Revisa las fechas y ajusta lo que haga falta." : "Ahora arma tus evaluaciones sobre ese plan."
    "Se trajo #{partes.join(' y ')} del año pasado. #{cierre}"
  end

  # ⚠️ Idempotente: la que ya está en el plan se salta. Copiar dos veces no
  # duplica nada, que es la misma regla de `CopiarLaEstructura` (MOR-166).
  # ⚠️ El resumen dice QUÉ QUEDÓ, no «copiado».
  #
  # «Listo» obliga a mirar la pantalla para saber qué pasó. Y separa las dos
  # cosas que se copiaron, porque son dos trabajos distintos: el plan y las
  # evaluaciones que lo miden.
  def resumen_de_la_copia(resultados)
    competencias = resultados.sum(&:competencias)
    evaluaciones = resultados.sum(&:evaluaciones)
    donde = helpers.contar(otras_secciones.size, "sección", "secciones")

    return "Nada que copiar: #{donde} ya tenían todo." if competencias.zero? && evaluaciones.zero?

    partes = []
    partes << helpers.contar(competencias, "competencia", "competencias") if competencias.positive?
    partes << helpers.contar(evaluaciones, "evaluación", "evaluaciones") if evaluaciones.positive?

    "Copiado a #{donde}: #{partes.join(' y ')}."
  end

  # ── Lo que llega del formulario ───────────────────────────────────────────

  def datos_del_plan
    return {} if asignacion.nil? || lapso.nil?

    datos_de_la_competencia.merge(section_id: asignacion.section_id,
                                  subject_id: asignacion.subject_id,
                                  evaluation_moment_id: lapso.id,
                                  orden: siguiente_orden)
  end

  # ⚠️ La competencia nueva va AL FINAL del plan.
  #
  # `competencies.orden` tiene `DEFAULT 0` y el alta no lo mandaba, así que toda
  # competencia nueva nacía con cero — y `order(:orden, :id)` la ponía entre las
  # que ya tenían 0 y las que tenían 1. Daniel lo vio al agregar la tercera y
  # aparecer de segunda: *«el orden de las competencias debe ser por creación,
  # supongo»*. Sí: se escriben en el orden en que se planifica.
  #
  # ⚠️ Se respeta el `orden` que venga en el formulario, si viene: la columna
  # existe para poder reordenarlas, y pisarla acá cerraría esa puerta antes de
  # abrirla.
  def siguiente_orden
    pedido = params.dig(:competency, :orden)
    return pedido if pedido.present?

    ultimo = Competency.del_plan(asignacion.section_id, asignacion.subject_id, lapso.id)
                       .maximum(:orden)
    (ultimo || -1) + 1
  end

  # ⚠️ Solo la descripción: los indicadores NO se escriben desde acá.
  #
  # Entraban como texto, uno por línea, pensado para pegar los cinco que la
  # maestra ya tenía escritos. Desde el 21 de septiembre un indicador cuelga de
  # la EVALUACIÓN que lo mide, así que lo que naciera acá quedaría sin ninguna:
  # sin salir en la boleta —solo se imprimen los medidos— y sin aparecer en el
  # plan, que los dibuja dentro de su evaluación. Un segundo lugar donde
  # escribirlos era un segundo lugar donde perderlos.
  def datos_de_la_competencia
    params.require(:competency).permit(:descripcion, :orden)
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
                alert: "El plan de evaluación lo escribe el profesor que dicta el área."
  end

  def puede_supervisar? = can_manage_sections?

  def contar(cantidad, singular, plural) = helpers.contar(cantidad, singular, plural)
end
