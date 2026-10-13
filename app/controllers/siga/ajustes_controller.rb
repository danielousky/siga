module Siga
  # El WhatsApp de SIGA y los datos para pagarle (spec `del-registro-al-cobro`,
  # decisiones 20 a 22).
  #
  #     GET   /siga/ajustes   los ve todo el equipo de SIGA
  #     PATCH /siga/ajustes   los cambia el fundador
  #
  # Lo que se guarda aquí lo usan en la petición siguiente los botones de
  # WhatsApp y la pantalla «Suscripción» de cada colegio: cambiar de número o
  # de cuenta no exige un despliegue ni entrar al servidor.
  class AjustesController < BaseController
    before_action :exigir_que_maneje_el_cobro!, only: :update

    def show
      @ajustes = SigaSetting.actuales
    end

    def update
      @ajustes = SigaSetting.actuales
      @ajustes.assign_attributes(datos_de_los_ajustes.merge(actualizado_por: current_user))

      if @ajustes.save
        redirect_to siga_ajustes_path, notice: "Guardado. Los colegios ya ven los datos nuevos."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def datos_de_los_ajustes
      params.require(:siga_setting).permit(:whatsapp, :titular, :documento, :pago_movil_banco,
                                           :pago_movil_telefono, :cuenta, :binance)
    end
  end
end
