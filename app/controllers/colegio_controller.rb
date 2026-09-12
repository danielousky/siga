# La identidad del colegio: su nombre, su ubicación y su escudo.
#
# Existe porque el logotipo **es identidad, no configuración**. Un boletín con el
# escudo del colegio es el boletín del colegio; sin él, el papel que la familia
# se lleva parece de la empresa de software.
#
# Lo administra la dirección del propio colegio y no SIGA: nadie de afuera sabe
# cuál es el escudo correcto, ni tiene por qué decidirlo.
class ColegioController < ApplicationController
  el_nivel_no_aplica "la identidad es de todo el colegio"
  include NormalizaLaUbicacion
  before_action :require_direccion!

  def show
    @colegio = Current.school
  end

  def update
    @colegio = Current.school

    if @colegio.update(con_la_ubicacion_resuelta(colegio_params))
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

  def quitar_sello
    Current.school.sello.purge

    redirect_to colegio_path, notice: "Sello eliminado."
  end

  private

  def colegio_params
    permitidos = params.require(:school).permit(:name, :logo, :firma, :sello,
                                                :dea_code, :tope_de_arrastre,
                                                :entidad_federal, :municipio, :municipio_libre,
                                                :parroquia, :parroquia_libre,
                                                :direccion, :telefono)

    # ⚠️ El DEA se carga UNA vez, y la guarda va acá y no solo en el formulario.
    #
    # El campo sale deshabilitado cuando ya está cargado, y eso basta para la
    # pantalla. Pero un `disabled` no es un permiso: un POST escrito a mano lo
    # cambiaría igual, y ese código sale impreso en cada boletín y en cada
    # constancia del colegio.
    permitidos.delete(:dea_code) if Current.school&.dea_code.present?
    permitidos
  end
end
