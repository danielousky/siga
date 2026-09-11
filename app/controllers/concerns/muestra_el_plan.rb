# El plan de evaluación de una asignación, listo para dibujar.
#
# ⚠️ Existe porque el MISMO plan se muestra en dos lugares: en `/competencias`
# —donde hay que elegir grado → área → sección → lapso— y en la pestaña
# «Planificar» de la sección, donde la sección y el área ya vienen del árbol del
# menú y solo queda el lapso (etapa ③).
#
# Daniel, sobre por qué la pestaña no puede sacarte de la sección: *«no me
# gustan ni Asistencia ni Planificación como URL, se descontextualiza todo, se
# supone que estoy en mi espacio de trabajo —la Sección— no para salir de él…
# no es solo "fingir" sino realmente estar en la sección»*.
#
# ## Lo que cada controller tiene que definir
#
#     asignacion        el par sección–área del que se habla
#     mis_asignaciones  todo lo que este profesor dicta (es lo que AUTORIZA:
#                       un id ajeno no está en la lista y devuelve nil)
#     plan_path         a dónde vuelven los formularios de esta pantalla
#
# El resto —los lapsos, el contexto de los enlaces, las secciones hermanas y
# las evaluaciones que pueden medir una competencia— sale de esos tres.
module MuestraElPlan
  extend ActiveSupport::Concern

  # ⚠️ Los `helper_method` van acá y no sueltos entre las definiciones: dentro
  # de un concern, `helper_method` en el cuerpo del módulo no existe todavía —
  # es un método de clase del controller, y el módulo no es uno.
  included do
    helper_method :lapsos, :lapso, :otras_secciones, :contexto,
                  :hermanas_con_plan, :hermanas_sin_plan, :evaluaciones_del_lapso,
                  :evaluaciones_de, :evaluaciones_sueltas, :peso_del_lapso,
                  :competencias_del_lapso,
                  :peso_libre, :periodo_del_plan, :con_competencias?
  end

  private

  # ⚠️ El plan cuelga de la SECCIÓN y el ÁREA, no de la asignación del profesor.
  #
  # Colgaba de `asignacion`, que un admin NO tiene: `mis_asignaciones` sale de
  # `current_user.teacher`, y un director no dicta. Resultado: la dirección
  # abría «Planificar» con su área elegida y rebotaba con «Elige primero un
  # área» — o, peor, veía las competencias sin ninguna evaluación y la
  # ponderación en 0 %.
  #
  # Un plan a medias es peor que no verlo: quien mira concluye que el profesor
  # no armó su ponderación, y va a preguntarle por algo que sí hizo.
  #
  # Los dos controllers llegan a lo mismo por caminos distintos —el profesor
  # por su asignación, la dirección por la sección que abrió— así que lo que se
  # comparte es el DESTINO, y cada uno dice cómo llega.
  # ⚠️ Si este grado planifica CON competencias, o solo con evaluaciones.
  #
  # En Educación Media el plan de evaluación son las evaluaciones y su
  # ponderación —el 70/30 del Artículo 111—, y no hay competencias. La pantalla
  # es la misma: lo que cambia es que no se dibuja esa lista.
  #
  # Antes, «Planificar» rebotaba a Media con «esto es de primaria, ve a
  # Calificar» — y allá el botón de alta se había retirado el 10 de septiembre,
  # así que las dos pestañas se mandaban la una a la otra y un profesor de
  # bachillerato no podía crear ninguna evaluación.
  #
  # Se pregunta por `Grade#por_competencias?` y no por «primaria» a mano: es la
  # misma pregunta que hacen el menú y el formulario de evaluación.
  def con_competencias? = seccion_del_plan&.grade&.por_competencias?

  def seccion_del_plan = asignacion&.section

  def area_del_plan = asignacion&.subject

  def lapsos
    return [] if seccion_del_plan.nil?

    @lapsos ||= EvaluationMoment.where(academic_period_id: seccion_del_plan.academic_period_id)
                                .order(:id)
  end

  def lapso
    @lapso ||= lapsos.find { |l| l.id.to_s == params[:lapso] } || lapsos.first
  end

  # Las secciones HERMANAS: mismo grado, misma materia, otra sección.
  #
  # ⚠️ El grado también, y faltaba: sin él, «copiar a mis otras secciones»
  # ofrecía las DIECINUEVE donde este profesor dicta Matemática, de 1er a 5to
  # Año. Una competencia de 1er Año no tiene nada que hacer en 5to, y copiarla
  # allá es basura que después alguien tiene que borrar a mano.
  # ⚠️ Las hermanas salen de `asignaciones_del_plan`, no de `mis_asignaciones`.
  #
  # En `CompetenciesController`, `mis_asignaciones` filtra los grados que evalúan
  # POR COMPETENCIAS —es la lista de la escalera— y con eso una sección de
  # Educación Media no tenía hermanas: «Duplicar en 1er Año B» respondía bien y
  # no copiaba nada. Es el mismo filtro que dejaba `asignacion` en nil.
  def asignaciones_del_plan = mis_asignaciones

  def otras_secciones
    @otras_secciones ||= asignaciones_del_plan.select do |ts|
      ts.subject_id == asignacion.subject_id &&
        ts.section.grade_id == asignacion.section.grade_id &&
        ts.section_id != asignacion.section_id
    end
  end

  # Las secciones de ESTE grado donde dicto ESTA materia. Es lo que decide si
  # hay hermanas a las que copiar.
  # El contexto de la pantalla, para los enlaces que tienen que volver acá.
  #
  # ⚠️ Sale de `asignacion`, no de `params`. Con las pastillas, la asignación se
  # DEDUCE de grado+área, así que `params[:asignacion]` viene vacío la primera
  # vez y todos los enlaces perdían la sección — «Registrar competencia» abría
  # el formulario de otra.
  # ⚠️ `desde` viaja en el contexto, y es lo que impide que copiar o traer un
  # plan te expulse de la sección.
  #
  # Los formularios de «Copiar a mis otras secciones» y «Traer el plan del año
  # pasado» hacen POST a `CompetenciesController`, que redirige a SU
  # `plan_path` — o sea, a `/competencias`. Desde la pestaña de la sección eso
  # es exactamente la descontextualización que Daniel rechazó, con un paso más.
  #
  # No es un `volver_a` con la URL adentro a propósito: eso sería un redirect
  # abierto. Es una bandera, y quien redirige arma la ruta.
  def contexto
    return {} if seccion_del_plan.nil? || area_del_plan.nil?

    { asignacion: "#{seccion_del_plan.id}:#{area_del_plan.id}",
      lapso: lapso&.id, desde: desde_donde }.compact
  end

  # `nil` en `/competencias`; `"seccion"` en la pestaña. Lo sobreescribe quien
  # dibuja el plan dentro de otra pantalla.
  def desde_donde = nil

  # Cuáles de las hermanas YA tienen plan en este lapso.
  #
  # ⚠️ Es lo que apaga el botón de copiar. Daniel: *«si la sección ya tiene
  # competencia, se deshabilita esta opción con mensaje indicativo»* — y tenía
  # razón por partida doble: copiar dos veces no duplicaba nada (la copia es
  # idempotente) pero el botón seguía ahí, invitando a una acción que ya no
  # hacía nada. Un control que no hace nada al tocarlo enseña a desconfiar del
  # resto.
  def hermanas_con_plan
    @hermanas_con_plan ||= begin
      ids = otras_secciones.map(&:section_id)
      Competency.where(section_id: ids, subject_id: asignacion&.subject_id,
                       evaluation_moment_id: lapso&.id)
                .distinct.pluck(:section_id).to_set
    end
  end

  # Las que todavía no lo tienen: a esas sí se puede copiar.
  def hermanas_sin_plan
    @hermanas_sin_plan ||= otras_secciones.reject { |ts| hermanas_con_plan.include?(ts.section_id) }
  end

  # Las evaluaciones que pueden medir una competencia: las de su mismo plan.
  #
  # ⚠️ Se carga UNA vez para toda la pantalla, no una por competencia. Un lapso
  # con cinco competencias y cinco evaluaciones son veinticinco consultas si se
  # pregunta por fila.
  # ── El plan ANIDADO: cada evaluación bajo la competencia que mide ─────────
  #
  # Decisión de Daniel, 8 de septiembre: *«¿será que colocamos las competencias
  # y evaluaciones juntas?»* — sí, y anidadas.
  #
  #     1 ▸ Resuelve problemas de adición
  #           Examen del lapso     40 %    8 nov
  #           Taller en clase      20 %   22 nov
  #     2 ▸ Interpreta gráficos
  #           ⚠ sin evaluaciones — no tendrá nivel en la boleta
  #
  # Antes eran dos pantallas y el enganche entre ellas era una lista de chips.
  # Que una competencia no tenga con qué medirse es la falla más común del plan
  # —sale SIN nivel en la boleta (`MOR-229`)— y era justamente lo que había que
  # abrir otra pantalla para descubrir.
  #
  # ⚠️ Una evaluación que mide DOS competencias sale DOS veces, a propósito.
  # Daniel, sobre el mismo caso en las secciones: *«no importa que se dupliquen
  # …es entendible y no se siente como un bug»*. La alternativa —repartirla— es
  # peor: la evaluación tiene UN peso y mostrar la mitad bajo cada competencia
  # inventa un número que no existe. Por eso la suma del 100 % va en su barra
  # arriba, contando cada evaluación UNA vez.
  def evaluaciones_de(competencia)
    por_competencia[competencia.id]
  end

  # Las que no miden nada. No es un error —el profesor puede querer una
  # evaluación suelta— pero sí algo que hay que ver: en la boleta esa nota
  # cuenta para el promedio y no describe ninguna competencia.
  def evaluaciones_sueltas
    @evaluaciones_sueltas ||= evaluaciones_del_lapso.reject { |e| e.competencies.any? }
  end

  # ⚠️ Se suma sobre `evaluaciones_del_lapso`, NUNCA sobre el anidado: ahí una
  # evaluación de dos competencias está dos veces y el 40 % se contaría 80.
  def peso_del_lapso = evaluaciones_del_lapso.sum(&:weight_percentage)

  # Todas las del plan, para ofrecer las que una evaluación TODAVÍA no mide.
  # Es la misma lista que dibuja el plan, así que se lee una vez.
  def competencias_del_lapso
    return [] if seccion_del_plan.nil? || area_del_plan.nil? || lapso.nil?

    @competencias_del_lapso ||= Competency.del_plan(seccion_del_plan.id, area_del_plan.id, lapso.id).to_a
  end

  # Lo que falta para cerrar el lapso: es lo que el alta propone, porque el
  # profesor casi siempre reparte lo que queda. Pedirle una resta que el sistema
  # ya tiene hecha es hacerle la cuenta a mano.
  def peso_libre = [ 100 - peso_del_lapso.to_f, 1 ].max

  # El año escolar de la sección: acota el calendario del alta a sus meses, como
  # ya hace la fecha de una evaluación existente.
  def periodo_del_plan = seccion_del_plan&.academic_period

  def por_competencia
    @por_competencia ||= evaluaciones_del_lapso.each_with_object(Hash.new { |h, k| h[k] = [] }) do |e, mapa|
      e.competencies.each { |c| mapa[c.id] << e }
    end
  end

  def evaluaciones_del_lapso
    return [] if seccion_del_plan.nil? || area_del_plan.nil? || lapso.nil?

    @evaluaciones_del_lapso ||= EvaluationActivity
                                .where(section_id: seccion_del_plan.id,
                                       subject_id: area_del_plan.id,
                                       evaluation_moment_id: lapso.id)
                                # ⚠️ `activity_grades` va precargada porque la
                                # fila pregunta cuántas notas tiene —una
                                # evaluación con notas NO se puede borrar— y
                                # sin esto son treinta consultas en un plan de
                                # treinta evaluaciones.
                                .includes(:competencies, :activity_grades)
                                .order(:date_scheduled, :id)
                                .to_a
  end
end
