# La asistencia de un día, lista para dibujar.
#
# ⚠️ Existe porque la MISMA planilla se muestra en dos lugares: en
# `/asistencia/:seccion_id` —la entrada del menú, para el guía que va a pasar
# lista— y en la pestaña «Asistencia» de la sección (etapa ③).
#
# Daniel, sobre por qué la pestaña no puede sacarte de la sección: *«se
# descontextualiza todo, se supone que estoy en mi espacio de trabajo —la
# Sección— no para salir de él… no es solo "fingir" sino realmente estar en la
# sección»*. Y es exacto: una pestaña que te expulsa no divide nada, solo mueve
# el problema.
#
# La alternativa era copiar diez líneas de preparación en el otro controller, y
# las copias se separan: la de `show` ordenaría por apellido y la otra no, y
# nadie se enteraría hasta que un profesor comparara las dos.
module PreparaLaAsistencia
  extend ActiveSupport::Concern

  private

  def preparar_la_asistencia(seccion, dia = nil)
    @dia = dia || dia_pedido
    @inscripciones = seccion.enrollments.includes(student: :user).to_a
                            .sort_by { |i| [ i.student.user.last_name, i.student.user.first_name ] }

    @asistencias = Attendance.del_dia(@dia)
                             .where(enrollment_id: @inscripciones.map(&:id))
                             .index_by(&:enrollment_id)

    @ya_tomada = @asistencias.any?
  end

  # ⚠️ El día se elige con las pastillas de la propia pantalla, no en la URL a
  # mano: el caso normal es hoy, y una fecha mal escrita cae en hoy en vez de
  # reventar.
  def dia_pedido
    Date.parse(params[:dia].to_s)
  rescue ArgumentError, TypeError
    Date.current
  end
end
