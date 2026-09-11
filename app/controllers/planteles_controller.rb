# Las sugerencias del catálogo del MPPE, mientras alguien escribe el nombre de
# su colegio.
#
# ## ⚠️ Es PÚBLICO, y tiene que serlo
#
# Se usa en el registro: quien busca su colegio todavía no tiene cuenta. Por eso
# `skip_before_action :authenticate_user!`, que es lo que `ApplicationController`
# exige declarar a mano (ver el `CLAUDE.md` del proyecto).
#
# Lo que devuelve son nombres y códigos de planteles, que el MPPE publica. No
# hay nada de ningún colegio de SIGA acá.
class PlantelesController < ApplicationController
  skip_before_action :authenticate_user!

  # ⚠️ Sin `Current.school`, y sin RLS: es un catálogo de la plataforma. Quien
  # se está registrando no tiene colegio todavía — y es justo para él.
  def index
    @planteles = PlantelOficial.buscar(params[:q])
    @termino = params[:q].to_s.strip

    render partial: "planteles/sugerencias",
           locals: { planteles: @planteles, termino: @termino }
  end
end
