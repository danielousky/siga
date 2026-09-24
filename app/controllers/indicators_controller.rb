# Los indicadores de una competencia, editables uno por uno (QA del 9 de sept).
#
# Daniel: *«elevar el modelo que aplicamos a evaluaciones a competencias e
# indicadores»* — cada cosa se edita donde se lee, sin lápiz y sin pantalla
# aparte.
#
# ## ⚠️ Uno por uno, y cada uno DENTRO de la evaluación que lo mide
#
# Daniel, 21 de septiembre: *«al crear un nuevo indicador debe estar asociado a
# su respectiva evaluación; ahorita al agregarlo queda suelto, asociado
# únicamente al componente»*.
#
#     COMPONENTE
#       EVALUACIÓN                 ← el campo vacío vive ACÁ
#         · indicador
#         · escribe un indicador…
#
# Un indicador sin evaluación no se imprime en la boleta —solo salen los
# medidos— y desde esta jerarquía tampoco se ve en pantalla: era un dato
# invisible. Por eso la evaluación es OBLIGATORIA al crear.
#
# ⚠️ Y se busca entre las que miden ESTA competencia (`@competency
# .evaluation_activities`), que es lo que autoriza: el id de una evaluación de
# otra competencia simplemente no aparece y el alta se rechaza.
class IndicatorsController < ApplicationController
  include MuestraElPlan
  include VuelveALaSeccion

  before_action :require_profesor!
  before_action :set_competency
  before_action :set_indicator, only: [ :update, :destroy ]

  # El campo vacío del final: escribir en él crea uno nuevo, como en una lista
  # de tareas. No hay botón «agregar» porque no hace falta uno.
  def create
    nuevo = @competency.indicators.new(descripcion: params.dig(:indicator, :descripcion),
                                       evaluation_activity: la_evaluacion_que_lo_mide,
                                       orden: siguiente_orden)
    nuevo.errors.add(:base, "Falta la evaluación que lo mide.") if nuevo.evaluation_activity.nil?
    nuevo.save if nuevo.errors.empty?

    # ⚠️ `recien:` solo en el alta. La pantalla lo usa para desvanecer HACIA
    # ADENTRO el que acaba de aparecer, y en un `update` no aparece nada: el
    # indicador ya estaba ahí y animarlo diría que es nuevo.
    devolver_la_competencia(nuevo, recien: nuevo.id)
  end

  def update
    @indicator.update(descripcion: params.dig(:indicator, :descripcion))
    devolver_la_competencia(@indicator)
  end

  def destroy
    @indicator.destroy
    devolver_la_competencia
  end

  private

  # ⚠️ Se devuelve la COMPETENCIA entera, no el indicador.
  #
  # Agregar uno cambia la lista, borrarlo también, y hasta corregir el texto
  # puede cambiar el alto del bloque. Devolver solo el indicador obligaría a
  # tres respuestas distintas para lo mismo; el bloque es una sola.
  # ⚠️ Y con el motivo si algo no se guardó.
  #
  # `create`/`update` sin `!` devuelven false en silencio, así que un indicador
  # repetido desaparecía sin dejar rastro —o reventaba con la excepción de
  # PostgreSQL, según lo que fallara primero—. El bloque vuelve con el error
  # escrito, que es la única señal que hay en la edición en línea.
  def devolver_la_competencia(registro = nil, recien: nil)
    error = registro&.errors&.full_messages&.to_sentence.presence

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@competency), partial: "competencies/competencia",
      locals: { competencia: @competency.reload, contexto: contexto,
                competencias: competencias_del_lapso,
                guardada: error.nil?, error: error, recien: (recien if error.nil?) }
    ), status: (error ? :unprocessable_entity : :ok)
  end

  # ⚠️ El alcance es `del_plan`, que ya filtra por sección, área y lapso de ESTE
  # profesor: un id de otra competencia no se encuentra y da 404, sin tener que
  # comprobar nada a mano.
  def set_competency
    @competency = Competency.del_plan(asignacion&.section_id, asignacion&.subject_id, lapso&.id)
                            .find(params[:competency_id])
  end

  def set_indicator = @indicator = @competency.indicators.find(params[:id])

  # ⚠️ Entre las evaluaciones que MIDEN esta competencia, y eso es lo que
  # autoriza: un id de la evaluación de otra competencia —o de otra sección— no
  # está en la lista, así que el alta se rechaza sin tener que comprobar nada a
  # mano. Es el mismo patrón que `set_competency`.
  def la_evaluacion_que_lo_mide
    return nil if params[:evaluacion].blank?

    @competency.evaluation_activities.find_by(id: params[:evaluacion])
  end

  # ⚠️ El orden es DENTRO de la evaluación, no de la competencia.
  #
  # Con el máximo de la competencia entera, el primer indicador de la segunda
  # evaluación nacía con `orden: 3` y la lista de esa evaluación empezaba en el
  # cuarto lugar — invisible, porque el orden solo se nota cuando hay dos.
  def siguiente_orden
    actuales = @competency.indicators.where(evaluation_activity_id: la_evaluacion_que_lo_mide&.id)
    (actuales.maximum(:orden) || -1) + 1
  end

  # Las asignaciones del profesor: el MISMO método de los otros dos
  # controllers del plan, y acotar a `current_user.teacher` es lo que autoriza.
  def mis_asignaciones
    @mis_asignaciones ||= current_user.teacher
      .teacher_sections
      .del_anio_de_la_sesion
      .del_nivel_de_la_sesion
      .includes(:subject, section: [ :grade, :academic_period ])
  end

  def asignacion
    return @asignacion if defined?(@asignacion)

    seccion, materia = params[:asignacion].to_s.split(":")
    @asignacion = mis_asignaciones.find do |ts|
      ts.section_id.to_s == seccion && ts.subject_id.to_s == materia
    end
  end

  def desde_donde = params[:desde]

  def require_profesor!
    return if profesor?

    redirect_to dashboard_path_for_user, alert: "El plan lo escribe el profesor que dicta la materia."
  end
end
