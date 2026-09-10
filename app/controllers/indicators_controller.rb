# Los indicadores de una competencia, editables uno por uno (QA del 9 de sept).
#
# Daniel: *«elevar el modelo que aplicamos a evaluaciones a competencias e
# indicadores»* — cada cosa se edita donde se lee, sin lápiz y sin pantalla
# aparte.
#
# ## ⚠️ Uno por uno, y no un textarea con saltos de línea
#
# El formulario completo los recibe todos juntos, separados por líneas, y los
# REEMPLAZA enteros. Eso está bien para escribir el plan de cero —y para pegar
# los que uno ya tiene—, pero no es editar donde se lee: es un formulario
# disfrazado de texto.
#
# Acá cada indicador es su propio registro con su propio campo. Corregir una
# palabra en el tercero no vuelve a escribir los otros dos, que es justo lo que
# hacía el reemplazo: tres `INSERT` y tres `DELETE` por una tilde.
#
# ⚠️ Y por eso el `destroy_all` de `competencies#update` pasó a ser condicional.
# Era incondicional, así que una petición con la descripción sola —la que manda
# la edición en línea— le habría borrado los tres indicadores sin decir nada.
class IndicatorsController < ApplicationController
  include MuestraElPlan
  include VuelveALaSeccion

  before_action :require_profesor!
  before_action :set_competency
  before_action :set_indicator, only: [ :update, :destroy ]

  # El campo vacío del final: escribir en él crea uno nuevo, como en una lista
  # de tareas. No hay botón «agregar» porque no hace falta uno.
  def create
    nuevo = @competency.indicators.create(descripcion: params.dig(:indicator, :descripcion),
                                          orden: siguiente_orden)
    devolver_la_competencia(nuevo)
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
  def devolver_la_competencia(registro = nil)
    error = registro&.errors&.full_messages&.to_sentence.presence

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@competency), partial: "competencies/competencia",
      locals: { competencia: @competency.reload, contexto: contexto,
                competencias: competencias_del_lapso,
                guardada: error.nil?, error: error }
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

  def siguiente_orden = (@competency.indicators.maximum(:orden) || -1) + 1

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
