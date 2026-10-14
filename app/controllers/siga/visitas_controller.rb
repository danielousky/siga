module Siga
  # Entrar a un colegio a dar soporte, y salir.
  #
  # Ver `AccesoDelEquipoDeSiga` para por qué esto existe y por qué es una
  # decisión con fecha de vencimiento.
  class VisitasController < BaseController
    def create
      colegio = School.find(params[:school_id])
      session[:colegio_visitado_id] = colegio.id

      # El rastro va en el historial DEL COLEGIO, para que el colegio lo vea.
      # Se escribe DENTRO del colegio y no con el aislamiento apagado: el
      # `WITH CHECK` de la política lo exige, y tiene razón.
      Current.en_el_colegio(colegio) do
        ActivityLog.create!(
          user_id: current_user.id, school_id: colegio.id,
          action: "soporte_siga_entro",
          message: "#{current_user.nombre_completo}, del equipo de SIGA, " \
                   "entró al sistema del colegio para dar soporte"
        )
      end

      redirect_to main_app.root_path,
                  notice: "Está dentro de #{colegio.name}. El colegio ve que usted entró."
    end

    def destroy
      session.delete(:colegio_visitado_id)

      redirect_to siga_root_path, notice: "Saliste del colegio."
    end
  end
end
