# La verificación pública de un boletín.
#
# Un PDF es trivial de editar antes de imprimirlo. El código impreso en el papel
# deja que la familia —o el colegio al que el alumno se traslada, o una
# universidad— compruebe contra la fuente sin llamar a nadie.
#
# Es el mismo mecanismo con el que Quid resuelve esto en Colombia, y es un
# argumento de venta concreto frente al incumbente: el producto de escritorio no
# puede tenerlo, porque no hay un sitio público donde consultar.
#
# ## Por qué esto va sin sesión y con `sin_aislamiento`
#
# La ruta es pública a propósito: quien verifica normalmente NO tiene cuenta. Y
# sin sesión no hay colegio, así que el RLS devolvería cero filas y la
# verificación no funcionaría nunca.
#
# La excepción está acotada a **una búsqueda por un código único de 8 caracteres
# aleatorios** — no expone ningún listado, ninguna búsqueda por nombre, y nada
# más que el boletín que ya está impreso en el papel que el visitante tiene en la
# mano. Es el mismo patrón que `colegio_de` en `ApplicationController`: explícito,
# acotado y grepeable.
#
# Ver MOR-98.
class VerificacionesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @codigo = params[:code].to_s.strip.upcase
    return render(:buscar) if @codigo.blank?

    @boletin = Current.sin_aislamiento do
      ReportCard.unscoped.includes(:evaluation_moment).find_by(code: @codigo)
    end

    render :no_encontrado, status: :not_found if @boletin.nil?
  end
end
