# La administración de SIGA. Otra app, adentro de esta por ahora (MOR-133).
#
# ## Por qué un namespace y no un proyecto Rails aparte, todavía
#
# La decisión de Daniel fue *"una app aparte que la montemos en el mismo host con
# dokku, si es posible así bien, **sino, vivirá inicialmente en conjunto con la
# app principal**"*. Y el rabbit hole 5 del issue advierte por qué conviene la
# segunda: **una app aparte duplica el despliegue, y todavía no hay ni uno
# funcionando** (`MOR-106`, sin servidor ni dominio).
#
# Así que vive acá, pero con la frontera puesta como si ya estuviera afuera:
# controller base propio, layout propio, rutas bajo `/siga`, y **ningún modelo
# compartido con el panel del colegio salvo los que describen la plataforma**.
# Extraerlo el día que haya un Dokku andando es mecánico: este directorio pasa a
# ser la raíz de la app nueva.
#
# ## La inversión que hace que esto funcione
#
# `ApplicationController` asume un colegio: `around_action` lo fija en las dos
# capas, y salirse de él —`Current.sin_aislamiento`— es la excepción rara y
# grepeable que levanta una ceja.
#
# Acá es al revés. Esta administración **existe para ver todos los colegios**, así
# que el bypass se declara UNA VEZ, en la puerta, y adentro es la norma:
#
#     app del COLEGIO          administración de SIGA
#     ───────────────          ──────────────────────
#     Current.school puesto    sin colegio, a propósito
#     sin_aislamiento = 🚩     el bypass es la NORMA
#
# Mientras compartían controller, cada `sin_aislamiento` del panel de SIGA se
# leía igual que un descuido. Separados, cada uno declara su naturaleza una vez.
#
# ## Y por eso los cuatro agujeros dejan de ser posibles
#
# No se tapa una pantalla a la vez: **el panel del colegio deja de tener acceso a
# estos controllers**, y estos dejan de tener colegio. Tapar la puerta no
# alcanzaba si la pared tenía ventana — acá no hay pared compartida.
module Siga
  class BaseController < ActionController::Base
    include Pagy::Backend

    layout "siga"

    # NO hereda de `ApplicationController`, y esa es la frontera: no arrastra su
    # `around_action` de colegio, ni sus helpers de rol, ni su layout. El día que
    # esto se extraiga a su propia app de Dokku no hay nada que desenredar.
    before_action :authenticate_user!
    before_action :exigir_equipo_de_siga!

    around_action :sin_colegio

    helper_method :siga_staff, :siga_seccion_activa

    private

    def siga_staff
      @siga_staff ||= SigaStaff.para(current_user)
    end

    # La puerta. Un usuario de colegio no llega ni al `index`: no es que vea una
    # pantalla vacía, es que no entra.
    #
    # Rebota al panel de su colegio y no a un 403, por lo mismo que el resto del
    # sistema devuelve 404 en vez de 403: un 403 confirmaría que la sección
    # existe. Acá el mensaje es genérico a propósito.
    def exigir_equipo_de_siga!
      return if siga_staff.present?

      redirect_to root_path, alert: "No tienes acceso a esta sección."
    end

    # El bypass declarado una vez, en la puerta.
    #
    # `Current.sin_aislamiento` pone `siga.bypass_rls` a nivel de SESIÓN de
    # Postgres, no de transacción, así que **su `ensure` es lo único que impide
    # que la conexión vuelva al pool con el bypass puesto**. Sería una fuga al
    # revés —una petición de colegio heredando la vista de plataforma— y mucho
    # peor que la original.
    #
    # Envolver la petición ENTERA en un `around_action` es lo que garantiza que
    # ese `ensure` corra pase lo que pase, incluida una excepción a mitad de una
    # vista.
    def sin_colegio
      Current.sin_aislamiento { yield }
    ensure
      Current.reset
    end

    def siga_seccion_activa
      controller_name
    end

    # Validar pagos, tocar suscripciones y cambiar los ajustes es del fundador
    # (decisión 22 del spec `del-registro-al-cobro`). Operaciones VE las mismas
    # pantallas: lo que no puede es apretar.
    def exigir_que_maneje_el_cobro!
      return if siga_staff.maneja_el_cobro?

      redirect_back fallback_location: siga_root_path, alert: "Eso lo hace el fundador."
    end
  end
end
