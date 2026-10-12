module Siga
  # Validar o rechazar lo que reportó un colegio (spec `del-registro-al-cobro`, § 5.6).
  #
  #     PATCH /siga/pagos/:id/validar    la suscripción queda activa un mes, en el momento
  #     PATCH /siga/pagos/:id/rechazar   con motivo; el colegio lo ve y le llega por correo
  #
  # La lista de lo que espera vive en la Cartera: esto son los dos verbos.
  #
  # ⚠️ Lo hace el fundador (decisión 22). Validar le abre el sistema a un
  # colegio; rechazar se lo deja cerrado. Operaciones ve la lista y no aprieta.
  class PagosController < BaseController
    before_action :exigir_que_maneje_el_cobro!
    before_action :set_pago
    before_action :solo_lo_que_espera!

    # La red del doble clic: las dos peticiones pasan el `before_action` de
    # arriba —las dos leen «en revisión»— y el modelo, con la fila bloqueada,
    # deja pasar una sola.
    rescue_from SubscriptionPayment::YaRevisado do
      redirect_to siga_cartera_index_path, alert: "Ese pago ya se revisó."
    end

    def validar
      @pago.validar!(por: current_user)

      dejar_rastro("suscripcion_pago_validado",
                   "#{current_user.nombre_completo}, de SIGA, validó el pago de la suscripción " \
                   "(#{@pago.nombre_del_medio}, #{helpers.importe_del_pago(@pago)})")
      avisarle_al_colegio { SuscripcionMailer.pago_validado(@pago).deliver_later }

      redirect_to siga_cartera_index_path,
                  notice: "Validado. #{@pago.school.name} queda activo hasta el " \
                          "#{I18n.l(@pago.cubre_hasta, format: :long)}."
    end

    # ⚠️ El motivo es obligatorio: un rechazo sin explicación deja al colegio
    # reportando lo mismo otra vez, y al fundador revisándolo otra vez.
    def rechazar
      motivo = params[:motivo].to_s.strip
      return redirect_to(siga_cartera_index_path, alert: "Falta el motivo del rechazo: el colegio lo va a leer.") if motivo.blank?

      @pago.rechazar!(por: current_user, motivo: motivo)

      dejar_rastro("suscripcion_pago_rechazado",
                   "#{current_user.nombre_completo}, de SIGA, rechazó el pago de la suscripción: #{motivo}")
      avisarle_al_colegio { SuscripcionMailer.pago_rechazado(@pago).deliver_later }

      redirect_to siga_cartera_index_path,
                  notice: "Rechazado. #{@pago.school.name} lo ve en su pantalla y le llega por correo."
    end

    private

    def set_pago
      @pago = SubscriptionPayment.includes(:school).find(params[:id])
    end

    # Validar dos veces sumaría dos meses por un solo pago; rechazar uno ya
    # validado dejaría al colegio activo con un pago «rechazado». Lo que ya se
    # revisó, no se vuelve a decidir desde aquí.
    def solo_lo_que_espera!
      return if @pago.en_revision?

      redirect_to siga_cartera_index_path, alert: "Ese pago ya se revisó."
    end

    # El rastro va en el historial DEL COLEGIO, para que el colegio lo vea: es
    # quien preguntará «¿quién nos activó, y cuándo?».
    #
    # ⚠️ Se escribe DENTRO del colegio y no con el aislamiento apagado, como la
    # visita de soporte: una fila del historial sin colegio es una fila que
    # nadie encuentra.
    def dejar_rastro(accion, mensaje)
      Current.en_el_colegio(@pago.school) do
        ActivityLog.create!(user_id: current_user.id, school_id: @pago.school_id,
                            action: accion, message: mensaje, subject: @pago,
                            ip_address: request.remote_ip)
      end
    end

    # ⚠️ El correo se encola DENTRO del colegio, y no es ceremonia: el trabajo
    # se lleva el colegio que haya al encolarlo (`CarriesSchool`), y aquí, en
    # `/siga`, no hay ninguno. Sin colegio, el worker buscaría el pago con el
    # RLS puesto y no lo encontraría.
    def avisarle_al_colegio(&)
      Current.en_el_colegio(@pago.school, &)
    end
  end
end
