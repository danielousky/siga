class AdminsController < ApplicationController
  include GeneraCodigosDeAcceso

  genera_codigos_de_acceso_para :admin, volver_a: :index
  before_action :require_admin_access!
  before_action :set_admin, only: [:edit, :update, :destroy, :generar_codigo]

  def index
    @pagy, @admins = pagy(Admin.includes(:user, :school))
  end


  def new
    @admin = Admin.new
    @admin.build_user
  end

  def edit; end

  def create
    @admin = Admin.new(admin_params)
    if @admin.save
      registrar_cambio(:creado, @admin, "#{@admin.user.nombre_completo}")
      redirect_to admins_path, notice: "Administrador creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @admin.update(admin_params)
      registrar_cambio(:actualizado, @admin, "#{@admin.user.nombre_completo}")
      redirect_to admins_path, notice: "Administrador actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = "#{@admin.user.nombre_completo}"

    if @admin.destroy
      registrar_cambio(:eliminado, @admin, nombre)
      redirect_to admins_url, notice: "Administrador eliminado exitosamente."
    else
      redirect_to admins_path, alert: @admin.errors.full_messages.join(", ")
    end
  end

  private

  def set_admin
    @admin = Admin.find(params[:id])
  end

  def admin_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:admin).permit(:role,
      user_attributes: [:id, :first_name, :last_name, :second_last_name,
                        :document, :document_type, :cedula_escolar,
                        :birth_date, :sex, :birth_place,
                        :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    # ⚠️ La MISMA lista que el resto de la app (`ApplicationController
    # ::DIRECCION`) y no una comprobación propia: acá había un `desarrollador? ||
    # director?` escrito a mano, y al agregar `asistente` en `MOR-208` el menú
    # ofrecía esta pantalla y este controller no dejaba entrar. Lo encontró
    # `cargo_de_asistente_test`, que recorre el menú y prueba cada enlace.
    unless can_manage_teachers?
      redirect_to dashboard_path_for_user, alert: "Esta parte del colegio la administra la dirección."
    end
  end
end
