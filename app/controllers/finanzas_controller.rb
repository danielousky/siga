# La bandeja de la oficina: los pagos que reportó la familia, para validarlos
# (spec: `docs/specs/pagos-de-la-familia.md`).
#
#     GET   /finanzas             lo que espera revisión
#     GET   /finanzas/:id         el reporte con su voucher
#     PATCH /finanzas/:id/validar  → los cobros quedan pagados
#     PATCH /finanzas/:id/rechazar → los cobros se sueltan y se dice por qué
#
# Daniel: *«el administrador financiero del colegio de finanzas debe poder
# validar el pago. Si el pago es válido, entonces puede liberar el acceso a las
# vistas que estuvieran bloqueadas por pago»*.
class FinanzasController < ApplicationController
  before_action :require_finanzas!
  before_action :set_reporte, only: [ :show, :validar, :rechazar ]

  # ⚠️ Lo que ESPERA primero, y lo más viejo arriba.
  #
  # Una bandeja ordenada por fecha descendente entierra el reporte de hace tres
  # días debajo de los de hoy, y ese es justamente el que tiene a una familia
  # sin ver las notas.
  def index
    @esperando = PaymentReport.esperando.includes(:enrollment, enrollment: :student)
    @revisados = PaymentReport.where.not(estado: "en_revision")
                              .includes(:enrollment, :revisado_por).recientes_primero.limit(25)
    @en_mora = Charge.en_mora.includes(enrollment: :student).en_orden.limit(50)
  end

  def show
    @cobros = @reporte.charges.en_orden.includes(:fee)
    @estado = EstadoDeCuenta.de(@reporte.enrollment)
  end

  def validar
    @reporte.validar!(por: current_user)
    registrar_cambio(:actualizado, @reporte, "Pago validado · #{@reporte.referencia}")
    redirect_to finanzas_path, notice: "Pago validado. La familia ya puede ver todo."
  end

  # ⚠️ El motivo es obligatorio. Un rechazo sin explicación deja a la familia
  # reportando lo mismo otra vez, y a la oficina revisándolo otra vez.
  def rechazar
    motivo = params[:motivo].to_s.strip
    if motivo.blank?
      return redirect_to finanza_path(@reporte), alert: "Diga por qué se rechaza."
    end

    @reporte.rechazar!(por: current_user, motivo: motivo)
    registrar_cambio(:actualizado, @reporte, "Pago rechazado · #{@reporte.referencia}")
    redirect_to finanzas_path, notice: "Rechazado. La familia puede volver a reportarlo."
  end

  private

  # ⚠️ La misma pregunta que se hace el MENÚ —`puede_cobrar?`, en
  # `ApplicationController`— y no una copia. Dos listas de cargos se separan, y
  # el día que se separen el menú ofrece una puerta que rebota.
  def require_finanzas!
    return if puede_cobrar?

    redirect_to dashboard_path_for_user, alert: "Esta sección es de la administración financiera."
  end

  def set_reporte = @reporte = PaymentReport.find(params[:id])
end
