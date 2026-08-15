class AdminsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_admin, only: [:edit, :update, :destroy]

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
      registrar_cambio(:creado, @admin, "#{@admin.user.name} #{@admin.user.last_name}")
      redirect_to admins_path, notice: "Administrador creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @admin.update(admin_params)
      registrar_cambio(:actualizado, @admin, "#{@admin.user.name} #{@admin.user.last_name}")
      redirect_to admins_path, notice: "Administrador actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = "#{@admin.user.name} #{@admin.user.last_name}"

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
      user_attributes: [:id, :name, :last_name, :id_card, :email, :password, :password_confirmation])
          .merge(school_id: Current.school_id)
  end

  def require_admin_access!
    unless administrador? && (current_user.admin.desarrollador? || current_user.admin.director?)
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores con rol de desarrollador o director."
    end
  end
end
