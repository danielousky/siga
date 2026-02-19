class AdminsController < ApplicationController
  before_action :require_admin_access!
  before_action :set_admin, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @admins = pagy(Admin.includes(:user, :school))
  end

  def show; end

  def new
    @admin = Admin.new
    @admin.build_user
  end

  def edit; end

  def create
    @admin = Admin.new(admin_params)
    if @admin.save
      redirect_to @admin, notice: "Administrador creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @admin.update(admin_params)
      redirect_to @admin, notice: "Administrador actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @admin.destroy
      redirect_to admins_url, notice: "Administrador eliminado exitosamente."
    else
      redirect_to @admin, alert: @admin.errors.full_messages.join(", ")
    end
  end

  private

  def set_admin
    @admin = Admin.find(params[:id])
  end

  def admin_params
    params.require(:admin).permit(:school_id, :role,
      user_attributes: [:id, :name, :last_name, :id_card, :email, :password, :password_confirmation])
  end

  def require_admin_access!
    unless administrador? && (current_user.admin.desarrollador? || current_user.admin.director?)
      redirect_to dashboard_path_for_user, alert: "Acceso no autorizado. Esta función es solo para administradores con rol de desarrollador o director."
    end
  end
end
