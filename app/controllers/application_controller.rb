class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Auditable
  before_action :authenticate_user!

  # Hacer disponibles los helpers de rol en los controladores
  helper_method :current_user_type, :estudiante?, :profesor?, :administrador?
  helper_method :can_manage_students?, :can_manage_teachers?, :can_manage_sections?
  helper_method :can_manage_academic_config?, :show_recent_activity?

  # Redirección post-login personalizada por tipo de usuario
  def after_sign_in_path_for(resource)
    log_activity(
      action:  "login",
      message: "#{resource.name} #{resource.last_name} inició sesión"
    )
    case current_user_type
    when :administrador then dashboards_administrador_path
    when :profesor      then dashboards_profesor_path
    when :estudiante    then dashboards_estudiante_path
    else root_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  private

  # Identificación de tipo de usuario
  def current_user_type
    return :estudiante if current_user.student.present?
    return :profesor if current_user.teacher.present?
    return :administrador if current_user.admin.present?
    nil
  end

  def estudiante?
    current_user_type == :estudiante
  end

  def profesor?
    current_user_type == :profesor
  end

  def administrador?
    current_user_type == :administrador
  end

  # Helpers de autorización para admins
  def can_manage_students?
    administrador? && %w[desarrollador director secretaria coordinador].include?(current_user.admin.role)
  end

  def can_manage_teachers?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def can_manage_sections?
    administrador? && %w[desarrollador director coordinador].include?(current_user.admin.role)
  end

  def can_manage_academic_config?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def show_recent_activity?
    administrador? && %w[desarrollador director].include?(current_user.admin.role)
  end

  def dashboard_path_for_user
    case current_user_type
    when :administrador then dashboards_administrador_path
    when :profesor      then dashboards_profesor_path
    when :estudiante    then dashboards_estudiante_path
    else root_path
    end
  end
  helper_method :dashboard_path_for_user
end
