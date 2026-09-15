# La tarjeta de pago de la familia, y el reporte de un pago (spec:
# `docs/specs/pagos-de-la-familia.md`).
#
#     GET  /pagos              lo que se debe al colegio, con una pestaña por hijo
#     GET  /pagos/reportar     el formulario
#     POST /pagos              queda «en revisión»
#     GET  /pagos/:id/corregir mientras nadie lo haya mirado
#
# ## ⚠️ La deuda es UNA, aunque los hijos sean tres
#
# Daniel: *«la deuda con el colegio es una, debe ser vista y reportada como tal,
# sin importar los hijos que se tengan estudiando»*. Y sobre el reporte: *«yo
# tengo dos hijos… cuando hago un pago no hago un pago para uno y un pago para
# el otro. Hago el pago de los dos. Eso es lo natural»*.
#
# Por eso el reporte cuelga del REPRESENTANTE y a qué hijos alcanza sale de sus
# CUOTAS, que ya saben su inscripción. Un reporte con `enrollment_id` obligaba a
# partir una transferencia en dos.
class PagosController < ApplicationController
  include ExigeEstarAlDia

  before_action :require_representante!
  before_action :set_representante
  before_action :set_reporte, only: [ :edit, :update, :destroy ]

  # ⚠️ Esta pantalla NO se bloquea por deuda, y es lo único que no: es la que
  # explica la deuda y permite salir de ella.
  def index
    @inscripciones = inscripciones_con_cuotas
    @estados = @inscripciones.index_with { |i| EstadoDeCuenta.de(i) }
    @elegida = @inscripciones.find { |i| i.id == params[:hijo].to_i } || @inscripciones.first
    @reportes = PaymentReport.where(representative_id: @representante.id)
                             .recientes_primero.limit(10)
  end

  def new
    @reporte = PaymentReport.new(representative: @representante, pagado_el: Date.current,
                                 depositante_nombre: current_user.apellidos_y_nombres)
    @cobros_por_hijo = cobros_reportables
  end

  def create
    @reporte = PaymentReport.new(datos_del_reporte)
    @reporte.representative = @representante
    @cobros_por_hijo = cobros_reportables

    guardar(@cobros_por_hijo.values.flatten) ? bienvenida : render(:new, status: :unprocessable_entity)
  end

  # ── Corregir lo que se reportó, mientras nadie lo ha mirado ───────────────
  #
  # Daniel: *«el error humano es posible, entonces deben poder corregir»*. La
  # madre copia la referencia del SMS del banco y baila dos dígitos; sin esto no
  # puede editar, no puede retirar y no puede volver a reportar —la referencia
  # es única por colegio— así que solo le queda esperar el rechazo.

  def edit
    @cobros_por_hijo = cobros_reportables(incluyendo: @reporte)
  end

  def update
    @cobros_por_hijo = cobros_reportables(incluyendo: @reporte)
    elegidos = @cobros_por_hijo.values.flatten

    if guardar(elegidos, corrigiendo: true)
      registrar_cambio(:actualizado, @reporte, "Pago corregido · #{@reporte.referencia}")
      redirect_to pagos_path, notice: "Corregido. El colegio lo va a revisar con los datos nuevos."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Retirarlo entero: el error no fue un dato, fue el reporte completo.
  def destroy
    referencia = @reporte.referencia
    PaymentReport.transaction do
      Charge.where(payment_report_id: @reporte.id).update_all(payment_report_id: nil)
      @reporte.destroy!
    end

    registrar_cambio(:eliminado, @reporte, "Pago retirado · #{referencia}")
    redirect_to pagos_path, notice: "Retirado. Puede reportarlo de nuevo cuando quiera."
  end

  private

  # ⚠️ Una sola puerta para crear y para corregir: las dos hacen lo mismo —
  # guardar el reporte y decir qué cuotas cubre— y dos copias se separan.
  def guardar(candidatos, corrigiendo: false)
    elegidos = candidatos.select { |c| cobros_elegidos.include?(c.id) }

    if elegidos.empty?
      @reporte.errors.add(:base, "Marque qué cuotas está pagando.")
      return false
    end

    PaymentReport.transaction do
      atributos = corrigiendo ? datos_del_reporte.merge(corregido_el: Time.current) : {}
      next false if corrigiendo && !@reporte.update(atributos)
      next false if !corrigiendo && !@reporte.save

      # ⚠️ Se sueltan las que ya no marcó y se toman las nuevas. Sin la primera
      # mitad, una cuota desmarcada seguiría figurando como reportada y la
      # familia no podría volver a reportarla nunca.
      Charge.where(payment_report_id: @reporte.id).update_all(payment_report_id: nil)
      @reporte.declarar!(elegidos)
      true
    end
  end

  def bienvenida
    registrar_cambio(:creado, @reporte, "Pago reportado · #{@reporte.referencia}")
    redirect_to pagos_path, notice: "Listo. El colegio va a revisar su pago."
  end

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
  def inscripciones_del_representante
    @inscripciones_del_representante ||=
      Enrollment.where(student_id: @representante.students.select(:id))
                .includes(:student, section: [ :grade, :academic_period ])
                .recientes_primero
  end

  # ⚠️ Los años SIN cuotas no se muestran.
  #
  # Daniel: *«las tarjetas vacías de 2024-2025… es información que debería estar
  # en un histórico»*. Una tarjeta que dice «todavía no tiene cuotas cargadas»
  # ocupa el mismo espacio que una con trece y no contesta nada.
  def inscripciones_con_cuotas
    conteo = Charge.where(enrollment_id: inscripciones_del_representante.map(&:id))
                   .group(:enrollment_id).count
    inscripciones_del_representante.select { |i| conteo[i.id].to_i.positive? }
  end

  # Lo que se puede marcar, agrupado POR HIJO: es como paga un padre.
  #
  # ⚠️ `incluyendo:` suma las que ese reporte ya tomó. Sin eso, abrir «Corregir»
  # mostraría el formulario con todo desmarcado.
  def cobros_reportables(incluyendo: nil)
    # ⚠️ `[ nil, incluyendo&.id ].compact` NO sirve: sin reporte que incluir,
    # `compact` se lleva también el `nil` que representa «sin dueño» y la lista
    # queda VACÍA — `where(payment_report_id: [])` no encuentra nada, así que
    # reportar contestaba «marque qué cuotas está pagando» con todo marcado.
    sin_dueno_o_de_este = [ nil ] + [ incluyendo&.id ].compact

    libres = Charge.where(enrollment_id: inscripciones_con_cuotas.map(&:id))
                   .pendientes
                   .where(payment_report_id: sin_dueno_o_de_este)
                   .en_orden.includes(:fee, enrollment: { student: :user }).to_a

    libres.group_by(&:enrollment).sort_by { |i, _| i.student.user.apellidos_y_nombres.to_s }.to_h
  end

  def cobros_elegidos = Array(params[:cobros]).map(&:to_i)

  # ⚠️ SOLO los suyos, y solo mientras nadie los haya mirado.
  def set_reporte
    @reporte = PaymentReport.find_by(id: params[:id], representative_id: @representante.id)
    raise ActiveRecord::RecordNotFound if @reporte.nil?

    return if @reporte.la_familia_puede_corregir?

    redirect_to pagos_path,
                alert: "Ese pago ya lo revisó el colegio. Si hay un error, escríbales."
  end

  def datos_del_reporte
    params.require(:payment_report).permit(:referencia, :banco, :monto, :pagado_el,
                                           :depositante_nombre, :depositante_documento,
                                           :nota, :voucher)
  end
end
