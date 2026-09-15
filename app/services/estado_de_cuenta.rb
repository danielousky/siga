# Qué debe una inscripción, y si eso la bloquea (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
# Es la tarjeta de pago que pidió Daniel: *«una tarjeta de pago donde la persona
# veía que había pagado y qué le faltaba por pagar en función del año escolar»*.
#
#     EstadoDeCuenta.de(inscripcion).en_mora?   #=> true
#     EstadoDeCuenta.de(inscripcion).deuda      #=> 90.0
class EstadoDeCuenta
  # ⚠️ Los días de gracia existen porque el vencimiento es una fecha, no un
  # portón. Un pago del día 5 que la oficina valida el 8 no puede dejar a la
  # familia sin ver las notas el 6 y el 7 — y menos cuando el 5 cayó domingo.
  DIAS_DE_GRACIA = 5

  def self.de(enrollment, hoy: Date.current) = new(enrollment, hoy: hoy)

  def initialize(enrollment, hoy: Date.current)
    @enrollment = enrollment
    @hoy = hoy
  end

  attr_reader :enrollment

  def cobros = @cobros ||= Charge.where(enrollment_id: enrollment.id).en_orden.includes(:fee).to_a

  # ⚠️ El mismo conjunto, al revés: es lo que se DIBUJA en la tarjeta. Los
  # cálculos de arriba siguen sobre `cobros` —el orden no les importa— y así no
  # hay dos consultas para lo mismo.
  def cobros_recientes_primero = cobros.reverse

  def pagados     = cobros.select(&:pagado?)
  def pendientes  = cobros.reject(&:pagado?)
  def en_revision = cobros.select(&:reportado?)
  def vencidos    = pendientes.select { |c| c.vence_el < corte }

  # Lo que debe HOY: lo vencido y sin pagar.
  def deuda = vencidos.sum(&:monto)
  # Lo que queda del año, haya vencido o no.
  def por_pagar = pendientes.sum(&:monto)
  def pagado = pagados.sum(&:monto)
  def total = cobros.sum(&:monto)

  # ⚠️ Lo REPORTADO no cuenta como deuda.
  #
  # Una familia que ya transfirió y subió su voucher no puede quedar bloqueada
  # mientras la oficina revisa. El riesgo —alguien reporta un pago falso y ve
  # las notas hasta que lo rechacen— es mucho menor que el daño de castigar a
  # quien pagó por la demora de un tercero.
  def en_mora? = vencidos.reject(&:reportado?).any?

  def al_dia? = !en_mora?

  # Cuántas cuotas y cuál es la más vieja: es lo que dice el aviso.
  def cuotas_vencidas = vencidos.reject(&:reportado?)
  def la_mas_vieja = cuotas_vencidas.min_by(&:vence_el)

  # ⚠️ «Debe septiembre y octubre» dice más que «debe 90 $»: la familia sabe qué
  # transferir y la oficina sabe qué buscar.
  def meses_que_debe = cuotas_vencidas.map { |c| c.fee&.nombre }.compact

  # Para la barra de la tarjeta de pago.
  def porcentaje_pagado
    return 0 if total.to_f.zero?

    ((pagado / total) * 100).round
  end

  def sin_conceptos? = cobros.empty?

  private

  def corte = @hoy - DIAS_DE_GRACIA
end
