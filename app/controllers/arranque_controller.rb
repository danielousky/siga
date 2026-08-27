# Los pasos opcionales que un colegio decide no hacer (MOR-154).
#
# ## Por qué esto existe siendo que el arranque no guarda progreso
#
# La puesta en marcha se DEDUCE de los datos: ¿hay grados?, ¿hay período?, ¿hay
# alumnos? Una bandera se queda vieja el día que nadie se acuerda de moverla.
#
# Pero hay algo que no se puede deducir: **«no aplica»**. Un colegio sin
# departamentos se ve idéntico a uno que todavía no los cargó. Esa es la única
# excepción, y por eso este controller es tan chico.
class ArranqueController < ApplicationController
  before_action :require_direccion!

  OPCIONALES = %w[departamentos].freeze

  def omitir
    Current.school.omitir_paso!(clave)
    redirect_to dashboards_administrador_path,
                notice: "Listo. Ese paso no vuelve a aparecer; puede retomarlo cuando quiera."
  end

  def retomar
    Current.school.retomar_paso!(clave)
    redirect_to dashboards_administrador_path
  end

  private

  # Solo los pasos declarados como opcionales. Sin esto, un `clave` cualquiera
  # se guardaría en la columna y un paso obligatorio quedaría escondido para
  # siempre — un colegio sin alumnos creyendo que ya arrancó.
  def clave
    pedida = params[:clave].to_s
    raise ActiveRecord::RecordNotFound unless OPCIONALES.include?(pedida)

    pedida
  end
end
