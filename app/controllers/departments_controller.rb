class DepartmentsController < ApplicationController
  before_action :set_department, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @departments = pagy(Department.includes(:school))
  end

  def show; end

  def new
    @department = Department.new
  end

  def edit; end

  def create
    @department = Department.new(department_params)
    if @department.save
      redirect_to @department, notice: "Departamento creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @department.update(department_params)
      redirect_to @department, notice: "Departamento actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @department.destroy
      redirect_to departments_url, notice: "Departamento eliminado exitosamente."
    else
      redirect_to @department, alert: @department.errors.full_messages.join(", ")
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :school_id)
  end
end
