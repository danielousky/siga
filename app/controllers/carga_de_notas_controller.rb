# Quién no ha terminado de cargar sus notas (MOR-155).
#
# ## Por qué esto no es un reporte más
#
# Los otros pendientes del panel —secciones sin profesor, alumnos sin
# representante— son deudas del arranque: molestan, y esperan. Este tiene
# **fecha de vencimiento**. El lapso cierra, los boletines salen incompletos, y
# la familia recibe un papel con casillas en blanco que nadie puede llenar
# después sin volver a emitirlo.
#
# Es lo que el documento del fundador pedía textualmente: *«que el personal
# administrativo pueda SABER si un profe completó toda su calificación para
# hacerle el respectivo LLAMADO de atención»*.
class CargaDeNotasController < ApplicationController
  before_action :require_puede_ver!

  def index
    # El año de la sesión (MOR-165), y si es «Todos», el que tiene clases. Nunca
    # `vigente`: en agosto `vigente` es el año que empieza, sin una sola
    # evaluación, y esta pantalla diría «todos al día» mientras el panel de al
    # lado dice que hay cuatro atrasados. Ver `anio_de_trabajo`.
    @periodo = anio_de_trabajo
    @atrasados = CargaDeNotas.profesores_atrasados(@periodo)
    @lapso = lapso_en_curso
  end

  private

  # El lapso que está corriendo, si el colegio cargó las fechas. Es lo que
  # convierte «hay cuatro atrasados» en «hay cuatro y el lapso cierra el
  # viernes», que es la diferencia entre un dato y una decisión.
  def lapso_en_curso
    return nil if @periodo.nil?

    EvaluationMoment.where(academic_period_id: @periodo.id)
                    .find { |l| l.fechas_propias? && l.rango.cover?(Date.current) }
  end

  def require_puede_ver!
    return if can_manage_sections?

    redirect_to dashboard_path_for_user,
                alert: "El avance de la carga de notas lo ve la dirección."
  end
end
