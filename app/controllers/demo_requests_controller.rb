# El formulario público de "pedir una demo".
#
# ⚠️ Este controller quedó SOLO con lo público: el formulario, su envío y la
# página de gracias. Ver, listar y responder solicitudes se mudó a
# `Siga::SolicitudesController` (MOR-133).
#
# No es un refactor cosmético. Este dato —quién pidió una demo, su correo, su
# teléfono, qué sistema usa hoy— **es de SIGA, no de ningún colegio**, y vivir
# acá lo dejó filtrándose tres veces:
#
#   1. `require_admin_access!` dejaba pasar a cualquier `director`
#   2. tapado eso, el panel seguía mostrando CUÁNTAS había pendientes
#   3. y el enlace del menú delataba que la sección existía
#
# Cada arreglo tapaba una pantalla y el siguiente agujero aparecía en otra.
# **Tapar la puerta no alcanza si la pared tiene ventana.** Ahora el panel del
# colegio no tiene estas acciones: no hay nada que tapar.
class DemoRequestsController < ApplicationController
  # Todo público: quien pide una demo, por definición, no tiene cuenta.
  skip_before_action :authenticate_user!

  def new
    @demo_request = DemoRequest.new
  end

  # `registrar` y no `create`: quien pide la demo por segunda vez no recibe un
  # error de validación, recibe las gracias otra vez y sube su contador. Ver
  # `DemoRequest.registrar`.
  def create
    @demo_request = DemoRequest.registrar(demo_request_params)

    if @demo_request.persisted?
      # El número viaja a la página de gracias para mostrárselo de vuelta. Un
      # dígito mal tipeado en el WhatsApp pierde al prospecto para siempre, y
      # este es el último instante en que se puede notar.
      flash[:telefono] = @demo_request.phone
      redirect_to success_demo_requests_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success
    @telefono = flash[:telefono]
  end

  private

  # `message` y `current_system_detail` siguen permitidos aunque el formulario
  # público ya no los pida (MOR-135): los llena el equipo de SIGA desde el panel
  # durante la llamada, que es cuando esa información realmente se consigue.
  def demo_request_params
    params.require(:demo_request).permit(:name, :email, :institution, :phone, :message,
                                         :current_system, :current_system_detail)
          .to_h.symbolize_keys
  end
end
