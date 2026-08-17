# La identidad del colegio: su nombre, su ubicación y su escudo.
#
# Existe porque el logotipo **es identidad, no configuración**. Un boletín con el
# escudo del colegio es el boletín del colegio; sin él, el papel que la familia
# se lleva parece de la empresa de software.
#
# Lo administra la dirección del propio colegio y no SIGA: nadie de afuera sabe
# cuál es el escudo correcto, ni tiene por qué decidirlo.
class ColegioController < ApplicationController
  before_action :require_direccion!

  def show
    @colegio = Current.school
  end

  def update
    @colegio = Current.school

    if @colegio.update(colegio_params)
      redirect_to colegio_path, notice: "Listo. El escudo aparece en el sistema y en los documentos."
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Quitar el escudo. Va aparte del formulario porque borrar un archivo no es lo
  # mismo que dejar un campo vacío: un `file_field` vacío significa "no cambié
  # nada", no "sacá el que había".
  def quitar_logo
    Current.school.logo.purge

    redirect_to colegio_path, notice: "Escudo eliminado."
  end

  def quitar_firma
    Current.school.firma.purge

    redirect_to colegio_path, notice: "Firma eliminada."
  end

  private

  def colegio_params
    params.require(:school).permit(:name, :location, :logo, :firma)
  end

  def require_direccion!
    return if can_manage_academic_config?

    redirect_to dashboard_path_for_user, alert: "La identidad del colegio la administra la dirección."
  end
end
