# A dónde vuelve un profesor (etapa ③).
#
# ⚠️ Para un profesor, `/competencias` y `/evaluaciones` DEJARON DE SER
# DESTINO.
#
# Daniel, después de cancelar un formulario y caer en el listado global: *«esa
# vista ya no debe estar, al igual que evaluaciones; volver lleva a evaluaciones
# sin sección»*. Y es la conclusión de toda la etapa ③: si el trabajo del
# profesor es por sección, un listado que no dice de cuál es exactamente la
# descontextualización que las pestañas vinieron a evitar — con el agravante de
# que ahí hay que volver a elegir grado, área, sección y lapso.
#
# Las pantallas **siguen existiendo**: son la entrada de la DIRECCIÓN, que
# supervisa el colegio entero y para quien «todas las evaluaciones» sí es una
# pregunta. Lo que cambia es que un profesor nunca aterriza ahí.
#
#     PROFESOR      cualquier vuelta → la pestaña de SU sección
#     DIRECCIÓN     los listados siguen siendo suyos
module VuelveALaSeccion
  extend ActiveSupport::Concern

  included do
    helper_method :frame_que_pregunta, :vengo_del_plan?, :ruta_de_vuelta
  end

  private

  # ⚠️ La misma pantalla se abre desde DOS frames, y tiene que contestar en el
  # que preguntó.
  #
  #     Planificar  ──►  «Agregar evaluación»  ──►  frame «plan»
  #     Calificar   ──►  «Agregar evaluación»  ──►  frame «libreta»
  #
  # Escribiendo el frame a mano —`turbo_frame_tag "libreta"` fijo, que es como
  # estaba— la respuesta del plan llega en un frame que ESA página no tiene, y
  # Turbo escribe «Content missing» donde iba el formulario. Es el error que
  # reportó Daniel, y no falla por ningún lado: la petición devuelve 200.
  #
  # Turbo manda en `Turbo-Frame` cuál pidió, así que la vista no necesita saber
  # de dónde viene: contesta a quien preguntó. Sin parámetro que pasar de mano
  # en mano y sin `if` en la vista.
  #
  # ⚠️ Va contra una LISTA BLANCA. El encabezado lo escribe el cliente, y sin
  # filtro cualquiera elige en qué frame se pinta la respuesta. El daño se
  # queda en su propia pantalla, pero un id llegado de afuera no se copia a un
  # atributo sin mirarlo.
  FRAMES = %w[plan libreta].freeze

  # ⚠️ Y los frames del ALTA EN LÍNEA, que son uno por competencia.
  #
  # Daniel: *«el "+ agregar evaluación" no debe ir a otra vista, puede agregarse
  # ahí mismo desplegando hacia abajo un panel»*. Cada botón carga su formulario
  # en un frame propio, debajo de él, así que el id lleva el número de la
  # competencia — o `nueva` para el del final, que no cuelga de ninguna.
  #
  # Se admite por PATRÓN y no por lista: los ids dependen de los datos. El
  # patrón es cerrado, que es lo que importa — un id llegado del cliente no se
  # copia a un atributo sin mirarlo.
  ALTA = /\Aalta_(evaluacion|competencia)_(\d+|nueva)\z/

  def frame_que_pregunta(por_defecto)
    pedido = request.headers["Turbo-Frame"].to_s

    FRAMES.include?(pedido) || pedido.match?(ALTA) ? pedido : por_defecto
  end

  # ⚠️ Los frames del ALTA cuentan como «vengo del plan»: viven dentro de él.
  #
  # Turbo manda en `Turbo-Frame` el frame CONTENEDOR del formulario, no el de
  # destino que dice `data-turbo-frame`. Así que un alta desplegada bajo una
  # competencia manda `alta_evaluacion_11`, y comparando con `"plan"` a secas
  # la vuelta se iba a la LIBRETA — con el plan entero en «Content missing».
  def vengo_del_plan?
    pedido = frame_que_pregunta(nil).to_s

    pedido == "plan" || pedido.match?(ALTA)
  end

  # A dónde vuelve una evaluación: a la pestaña de donde salió.
  #
  # ⚠️ Sirve también para el REDIRECT de `create` y `update`, no solo para el
  # botón «Volver». Turbo arrastra el encabezado `Turbo-Frame` a través del
  # redirect, así que la respuesta cae en el mismo frame — creando desde el
  # plan, lo que reemplaza el formulario es el plan con su evaluación nueva
  # colgada de su competencia, y no la libreta encima de la planificación.
  def ruta_de_vuelta(actividad)
    return nil if actividad.section_id.blank?
    return ruta_de_calificar(actividad) unless vengo_del_plan?

    planificar_section_path(actividad.section_id, area: actividad.subject_id,
                            lapso: actividad.evaluation_moment_id)
  end


  # La pestaña «Planificar» de una asignación.
  def ruta_de_planificar(asignacion, lapso = nil)
    return competencies_path if asignacion.nil?

    planificar_section_path(asignacion.section_id, area: asignacion.subject_id, lapso: lapso&.id)
  end

  # La pestaña «Calificar» de una evaluación: la libreta donde vive su columna.
  def ruta_de_calificar(actividad)
    section_path(actividad.section_id, area: actividad.subject_id,
                 lapso: actividad.evaluation_moment_id)
  end
end
