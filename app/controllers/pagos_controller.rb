# La tarjeta de pago de la familia, y el reporte de un pago (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
#     GET  /pagos              la tarjeta: qué pagó y qué le falta
#     GET  /pagos/nuevo        el formulario
#     POST /pagos              queda «en revisión»
#
# Daniel: *«debería tener, del lado del representante, una tarjeta de pago… donde
# la persona veía que había pagado y qué le faltaba por pagar en función del año
# escolar»*.
class PagosController < ApplicationController
  include ExigeEstarAlDia

  before_action :require_representante!
  before_action :set_representante
  before_action :set_inscripcion, only: [ :new, :create ]

  # ⚠️ La tarjeta NO se bloquea por deuda, y es lo único que no.
  #
  # Es la pantalla que explica la deuda y permite salir de ella: esconderla
  # justo cuando hace falta deja a la familia sin ninguna puerta y al colegio
  # con una llamada.
  def index
    @inscripciones = inscripciones_del_representante
    @estados = @inscripciones.index_with { |i| EstadoDeCuenta.de(i) }
    @reportes = PaymentReport.where(representative_id: @representante.id)
                             .includes(:enrollment).recientes_primero.limit(10)
  end

  def new
    @reporte = PaymentReport.new(enrollment: @inscripcion, representative: @representante,
                                 pagado_el: Date.current,
                                 depositante_nombre: current_user.apellidos_y_nombres)
    # ⚠️ Solo lo que TODAVÍA se puede reportar: lo pagado no, y lo que ya está
    # esperando revisión tampoco. Ofrecer un cobro reportado invita a mandarlo
    # dos veces y a que la oficina revise el mismo pago por partida doble.
    @cobros = cobros_reportables
  end

  def create
    @reporte = PaymentReport.new(datos_del_reporte)
    @reporte.representative = @representante
    @reporte.enrollment = @inscripcion
    @cobros = cobros_reportables

    elegidos = @cobros.select { |c| cobros_elegidos.include?(c.id) }
    if elegidos.empty?
      @reporte.errors.add(:base, "Marque qué cuotas está pagando.")
      return render :new, status: :unprocessable_entity
    end

    # ⚠️ El reporte y sus cobros, todo junto. A medias queda un reporte que no
    # dice qué paga, y la oficina no tiene con qué compararlo.
    guardado = PaymentReport.transaction do
      next false unless @reporte.save

      # ⚠️ `declarar!` y no un `update_all` suelto: deja además la HISTORIA de
      # qué dijo pagar, que es lo que permite validarlo si un rechazo fue el
      # error. Ver `PaymentReport#cobros_declarados`.
      @reporte.declarar!(elegidos)
      true
    end

    if guardado
      registrar_cambio(:creado, @reporte, "Pago reportado · #{@reporte.referencia}")
      redirect_to pagos_path, notice: "Listo. El colegio va a revisar su pago."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_representante
    @representante = Representative.find_by(user_id: current_user.id)
    raise ActiveRecord::RecordNotFound if @representante.nil?
  end

  def require_representante!
    return if representante?

    redirect_to dashboard_path_for_user, alert: "Esta sección es para representantes."
  end

  # ⚠️ SOLO sus representados. Sin este filtro, cambiar el id en la URL deja
  # reportar un pago contra la inscripción de otro alumno — y, peor, mirar su
  # estado de cuenta.
  # ⚠️ Sale de `@representante.students`, como el resto del portal.
  #
  # `Student` no declara `has_many :student_representatives` —la relación se
  # navega desde el representante— así que un `joins(student: :…)` no existe.
  # Y pasar por los ids es además lo que hace el filtro explícito: sin esta
  # lista, cambiar el id en la URL deja reportar un pago contra la inscripción
  # de otro alumno, y peor, mirar su estado de cuenta.
  def inscripciones_del_representante
    @inscripciones_del_representante ||=
      Enrollment.where(student_id: @representante.students.select(:id))
                .includes(:student, section: [ :grade, :academic_period ])
                .recientes_primero
  end

  def set_inscripcion
    @inscripcion = inscripciones_del_representante.find_by(id: params[:inscripcion] || params.dig(:payment_report, :enrollment_id))
    @inscripcion ||= inscripciones_del_representante.first
    raise ActiveRecord::RecordNotFound if @inscripcion.nil?
  end

  def cobros_reportables
    Charge.where(enrollment_id: @inscripcion.id).sin_reportar.en_orden.includes(:fee).to_a
  end

  def cobros_elegidos = Array(params[:cobros]).map(&:to_i)

  def datos_del_reporte
    params.require(:payment_report).permit(:referencia, :banco, :monto, :pagado_el,
                                           :depositante_nombre, :depositante_documento,
                                           :nota, :voucher)
  end
end
