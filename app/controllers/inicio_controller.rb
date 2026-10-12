# La raíz: portada pública para quien no tiene sesión, desvío para quien sí.
class InicioController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  # ## Por qué el `case` de acá se fue
  #
  # Este controller tenía su propia lista de roles —administrador, profesor,
  # alumno— y `dashboard_path_for_user` tenía OTRA, más completa. Cada rol
  # nuevo había que acordarse de agregarlo en los dos lados, y no pasó:
  #
  #   · un **representante** caía en el `else` y leía "Tu cuenta no tiene un rol
  #     asignado", teniendo dos hijos inscritos;
  #   · el **equipo de SIGA** (MOR-133) tampoco estaba, y terminaba en la misma
  #     pantalla.
  #
  # Ahora hay una sola lista. `dashboard_path_for_user` devuelve `root_path`
  # cuando de verdad no hay rol, y ese caso se atrapa acá: sin esa comparación
  # sería un redirect infinito contra esta misma acción.
  #
  # ⚠️ En la instancia de MUESTRA, la portada son sus puertas (`MuestraController`).
  # Quien llega ahí vino a ver el sistema funcionando, no a leer qué es: la
  # tapa del sitio de verdad le ofrecería registrar un colegio en una base que
  # se borra cada noche.
  def index
    return render("muestra/show") if Muestra.activa? && !user_signed_in?
    return unless user_signed_in?

    destino = dashboard_path_for_user
    return if destino == root_path

    redirect_to destino
  end
end
