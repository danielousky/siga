class DepartmentsController < ApplicationController
  before_action :set_department, only: [:edit, :update, :destroy]

  CAMPOS_DE_BUSQUEDA = %w[departments.name].freeze

  def index
    scope = Department.includes(:school)
    scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])) if params[:q].present?

    @pagy, @departments = pagy(scope.order(:name))
  end


  def new
    @department = Department.new
  end

  def edit; end

  def create
    @department = Department.new(department_params)
    if @department.save
      registrar_cambio(:creado, @department, @department.name)
      redirect_to departments_path, notice: "Departamento creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      registrar_cambio(:actualizado, @department, @department.name)
      redirect_to departments_path, notice: "Departamento actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # El nombre, antes de borrar: después el objeto ya no puede
    # resolver sus asociaciones para armar el mensaje.
    nombre = @department.name

    if @department.destroy
      registrar_cambio(:eliminado, @department, nombre)
      redirect_to departments_url, notice: "Departamento eliminado exitosamente."
    else
      redirect_to departments_path, alert: @department.errors.full_messages.join(", ")
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    # `school_id` NO se permite: el colegio sale de la sesión, nunca del request (MOR-86).
    params.require(:department).permit(:name).merge(school_id: Current.school_id)
  end
end
