# Cómo contesta una planilla que se guarda campo por campo.
#
# Las cuatro —notas, reparaciones, informes descriptivos y Educación Inicial—
# son la misma interacción: se escribe, se sale del campo, se guarda. Hasta hoy
# eran tres transportes distintos —dos JSON escritos a mano con su `fetch`, y un
# frame que se reemplazaba entero— y cada uno con su forma de decir «guardado».
#
# ## ⚠️ Un STREAM, y nunca la lista entera
#
# La planilla de notas son treinta filas y el profesor las recorre con Enter.
# Devolver el frame completo repinta las treinta en cada tecla y se lleva el
# foco del campo siguiente — que es justo lo que hace usable la pantalla.
#
# Por eso la respuesta toca solo los pedazos que NO tienen el foco:
#
#     estado_<fila>              la marca ✓ · — · !
#     progreso_de_la_planilla    la barra y «12 de 30»
#     <extra>                    lo que cada planilla agregue (la definitiva)
#
# ## ⚠️ El error va en la MARCA, no en un flash
#
# Un flash arriba dice «no se pudo guardar» sin decir a quién. En una planilla
# de treinta alumnos eso obliga a revisarlos uno por uno. La marca de la fila
# ya está al lado del campo que falló.
module PlanillaQueSeGuardaSola
  extend ActiveSupport::Concern

  # Contesta que una fila quedó guardada, vacía o rechazada.
  def fila_de_la_planilla(id:, estado:, mensaje: nil, hechas: nil, total: nil,
                          nombre: "llenas", extra: [])
    fragmentos = [ marca_de_la_fila(id, estado, mensaje) ]

    if hechas && total
      fragmentos << turbo_stream.replace("progreso_de_la_planilla",
                                         partial: "shared/progreso_de_la_planilla",
                                         locals: { hechas: hechas, total: total, nombre: nombre })
    end

    render turbo_stream: fragmentos + Array(extra)
  end

  private

  def marca_de_la_fila(id, estado, mensaje)
    turbo_stream.replace(id, partial: "shared/estado_de_la_fila",
                             locals: { id: id, estado: estado, mensaje: mensaje })
  end
end
