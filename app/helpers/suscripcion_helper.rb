# Lo que necesita la pantalla «Suscripción» (spec `del-registro-al-cobro`, § 5.3).
module SuscripcionHelper
  # En qué está la suscripción, dicho en una línea y su explicación.
  #
  # ⚠️ El pago en revisión va PRIMERO, antes que cualquier estado: el director
  # que ya pagó y lee «sin suscripción activa» cree que su reporte se perdió, y
  # reporta otra vez.
  #
  # ⚠️ La clave es el nombre del DATO —activa, en gracia—, no un color: el color
  # lo decide la hoja de estilos a partir de él (regla de color, MOR-135).
  Estado = Data.define(:clave, :titulo, :detalle)

  def estado_de_la_suscripcion(suscripcion, en_revision: nil)
    if en_revision
      Estado.new(:en_revision, "Pago en revisión",
                 "Recibimos el reporte del #{l(en_revision.created_at.to_date, format: :long)}; " \
                 "lo estamos validando. Le avisamos por correo apenas esté.")
    elsif suscripcion.gratis?
      Estado.new(:sin_activar, "Sin suscripción activa",
                 "Cargar es libre. Calificar, pasar lista y emitir se activan al validarse el pago.")
    elsif suscripcion.solo_lectura?
      Estado.new(:solo_lectura, "Solo lectura",
                 "Se puede ver y descargar todo; para volver a cargar, hay que reportar el pago.")
    elsif suscripcion.en_gracia?
      Estado.new(:en_gracia, "Venció el #{l(suscripcion.vigente_hasta, format: :long)}",
                 "Quedan #{contar(suscripcion.dias_de_gracia_restantes, 'día', 'días')} " \
                 "antes de pasar a solo lectura. Mientras tanto, todo funciona.")
    elsif suscripcion.por_vencer?
      Estado.new(:por_vencer, "Vence el #{l(suscripcion.vigente_hasta, format: :long)}",
                 "Todo funciona. Para que nada se interrumpa, reporte el pago antes de esa fecha.")
    else
      # ⚠️ Sin fecha de vencimiento es una cortesía o un piloto abierto a mano:
      # se dice «activa» y nada más, en vez de inventarle un día.
      hasta = suscripcion.vigente_hasta
      Estado.new(:activa, hasta ? "Activa hasta el #{l(hasta, format: :long)}" : "Activa",
                 "Todo funciona: calificar, pasar lista y emitir.")
    end
  end

  # Cuántos alumnos cubre el mínimo con el precio de este colegio: con el de
  # hoy, 39 $ a 0,30 son 130. Se calcula, no se escribe, por lo mismo que el
  # precio (`los_precios_de_un_solo_lugar_test`).
  def alumnos_que_cubre_el_minimo(cotizacion)
    (cotizacion.minimo / cotizacion.por_alumno).floor
  end

  def porcentaje_de_iva = "#{(Subscription::IVA * 100).to_i} %"
end
