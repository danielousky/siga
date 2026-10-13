module Siga
  # Los ajustes de la plataforma (spec `del-registro-al-cobro`, decisiones 20 a
  # 22 y 35).
  #
  #     GET   /siga/ajustes   los ve todo el equipo de SIGA
  #     PATCH /siga/ajustes   los cambia el fundador
  #
  #     el WhatsApp de SIGA          Setup        nombre y valor, una fila cada uno
  #     la dirección de la muestra   Setup
  #     los datos para pagar         SigaSetting  van juntos: se validan entre sí
  #
  # Lo que se guarda aquí lo usan en la petición siguiente los botones de
  # WhatsApp, la portada y la pantalla «Suscripción» de cada colegio: cambiar de
  # número, de cuenta o de dirección no exige un despliegue ni entrar al
  # servidor.
  class AjustesController < BaseController
    before_action :exigir_que_maneje_el_cobro!, only: :update

    def show
      @ajustes = SigaSetting.actuales
      @setup = Setup.para_el_formulario
      @ultimo_cambio = ultimo_cambio
    end

    def update
      @ajustes = SigaSetting.actuales
      @ajustes.assign_attributes(datos_de_los_ajustes)
      @ajustes.actualizado_por = current_user if @ajustes.new_record? || @ajustes.changed?
      cambios = Setup.para_guardar(datos_del_setup, por: current_user)

      if guardar(@ajustes, *cambios)
        redirect_to siga_ajustes_path, notice: "Guardado. Los colegios ya ven los datos nuevos."
      else
        @setup = Setup.para_el_formulario(cambios)
        @ultimo_cambio = ultimo_cambio
        render :show, status: :unprocessable_entity
      end
    end

    private

    # ⚠️ O se guarda todo, o nada. Se validan TODOS antes —para decir todos los
    # errores de una vez, y no uno por envío— y se guardan en una transacción:
    # un WhatsApp guardado con una cuenta rechazada al lado es un formulario que
    # dice «error» y que a medias sí cambió.
    def guardar(*registros)
      return false unless registros.map(&:valid?).all?

      ActiveRecord::Base.transaction { registros.each(&:save!) }
      true
    end

    # Quién cambió algo por última vez —en cualquiera de las dos tablas—.
    #
    # ⚠️ Se lee de la BASE, no de lo que trae el formulario. Al volver con un
    # error, lo que está en pantalla todavía no se guardó: decir «lo cambió» de
    # eso sería mentir (y sin fecha, reventaba).
    def ultimo_cambio
      [ SigaSetting.first, *Setup.all ].compact.select(&:actualizado_por).max_by(&:updated_at)
    end

    def datos_de_los_ajustes
      params.fetch(:siga_setting, {}).permit(:titular, :documento, :pago_movil_banco,
                                             :pago_movil_telefono, :cuenta, :binance)
    end

    def datos_del_setup
      params.fetch(:setup, {}).permit(*Setup::CAMPOS.keys).to_h
    end
  end
end
