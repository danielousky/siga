# Lo que el colegio cobra en un año escolar (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
#     GET   /academic_periods/:id/cobros     el calendario de cuotas
#     POST  /academic_periods/:id/cobros     agrega una
#     PATCH /cobros/:id                      corrige monto o fecha
#     DELETE /cobros/:id                     la quita
#     POST  /academic_periods/:id/cobros/proponer   el calendario habitual
#
# ## ⚠️ Era el hueco que impedía cobrar
#
# Los conceptos existían en la base y solo los creaba la tarea de demostración:
# un director real abría SIGA, veía la bandeja de pagos y no tenía dónde decir
# cuánto cuesta la inscripción. La cobranza entera colgaba de un `rake`.
class CobrosController < ApplicationController
  before_action :require_cobrador!
  before_action :set_periodo, only: [ :index, :create, :proponer ]
  before_action :set_concepto, only: [ :update, :destroy ]

  def index
    @conceptos = Fee.where(academic_period_id: @periodo.id).en_orden
    @concepto = Fee.new(academic_period: @periodo)
    @emitidos = Charge.where(fee_id: @conceptos.map(&:id)).group(:fee_id).count
  end

  def create
    @concepto = Fee.new(datos.merge(academic_period: @periodo))

    if @concepto.save
      registrar(:creado, @concepto, "Concepto de cobro · #{@concepto.nombre}")
      redirect_to academic_period_cobros_path(@periodo), notice: "«#{@concepto.nombre}» agregado."
    else
      @conceptos = Fee.where(academic_period_id: @periodo.id).en_orden
      @emitidos = Charge.where(fee_id: @conceptos.map(&:id)).group(:fee_id).count
      render :index, status: :unprocessable_entity
    end
  end

  # ⚠️ Cambiar el monto NO cambia lo que un alumno ya debe: su cuota copió el
  # monto al emitirse, igual que un boletín copia sus notas. La pantalla lo
  # dice, porque es lo primero que un director asume al revés.
  def update
    if @concepto.update(datos)
      registrar(:actualizado, @concepto, "Concepto de cobro · #{@concepto.nombre}")
      redirect_to academic_period_cobros_path(@concepto.academic_period_id), notice: "Listo."
    else
      redirect_to academic_period_cobros_path(@concepto.academic_period_id),
                  alert: @concepto.errors.full_messages.to_sentence
    end
  end

  def destroy
    periodo = @concepto.academic_period_id
    nombre = @concepto.nombre

    if @concepto.destroy
      registrar(:eliminado, @concepto, "Concepto de cobro · #{nombre}")
      redirect_to academic_period_cobros_path(periodo), notice: "«#{nombre}» eliminado."
    else
      # ⚠️ `restrict_with_error`: un concepto con cuotas emitidas no se borra.
      # Borrarlo dejaría a las familias con una cuota que no dice de qué es.
      redirect_to academic_period_cobros_path(periodo), alert: @concepto.errors.full_messages.to_sentence
    end
  end

  # El calendario habitual de un colegio venezolano, para no escribir trece
  # filas a mano.
  #
  # ⚠️ PROPONE, no impone: nace con la inscripción y los once meses, y el
  # colegio corrige lo que sea distinto. Y agosto vence en JULIO —solo agosto—
  # que es la regla que nadie recuerda al cargarlo a mano.
  def proponer
    mensualidad = params[:mensualidad].to_f
    inscripcion = params[:inscripcion].to_f

    if mensualidad <= 0
      return redirect_to academic_period_cobros_path(@periodo), alert: "Diga cuánto vale la mensualidad."
    end

    creados = Fee.calendario_propuesto(@periodo, mensualidad: mensualidad,
                                                 inscripcion: inscripcion).count do |datos|
      Fee.create(datos.merge(academic_period: @periodo)).persisted?
    end

    registrar(:creado, @periodo, "Calendario de cobro · #{creados} conceptos")
    redirect_to academic_period_cobros_path(@periodo),
                notice: "#{helpers.contar(creados, 'concepto', 'conceptos')}. Corrija lo que haga falta."
  end

  private

  def set_periodo = @periodo = AcademicPeriod.find(params[:academic_period_id])
  def set_concepto = @concepto = Fee.find(params[:id])

  def datos = params.require(:fee).permit(:nombre, :monto, :vence_el, :orden)

  def registrar(accion, objeto, detalle) = registrar_cambio(accion, objeto, detalle)

  # ⚠️ Lo define quien COBRA, no quien administra alumnos: es el precio del
  # colegio. La coordinadora carga la matrícula y no le pone precio.
  def require_cobrador!
    return if puede_cobrar?

    redirect_to dashboard_path_for_user, alert: "Esta sección es de la administración financiera."
  end
end
