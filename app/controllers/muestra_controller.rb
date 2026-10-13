# La puerta del colegio de muestra (spec `docs/specs/del-registro-al-cobro.md`,
# § 4.3).
#
#     GET  /muestra          las puertas, una por rol
#     POST /muestra/entrar   abre la sesión de esa cuenta, sin pedir la clave
#
# ## ⚠️ Entrar sin clave SOLO existe en la muestra
#
# Un endpoint que abre una sesión sin contraseña es la peor cosa que podría
# existir en el sistema de un colegio. Aquí tiene tres cerrojos, y cada uno
# alcanza solo:
#
#     1 · la instancia se declaró muestra    `Muestra.activa?`, o responde 404
#     2 · la cuenta está en la lista         `Muestra.cuenta`: no se entra «como quien uno diga»
#     3 · tiene ESE rol en ESE colegio       `Muestra.usuario_de`: el de la muestra, por su código DEA
#
# El primero es el que importa; los otros dos hacen que una variable mal puesta
# tampoco abra nada: en la base de los colegios esas cuentas no existen.
#
# ## Fuera de la muestra, `/muestra` es un cartel
#
# En el sitio de verdad no hay colegio de muestra que abrir: la dirección manda
# a donde vive —el ajuste `url_de_la_muestra`, en `/siga/ajustes`—, y si nadie
# lo cargó, no existe.
class MuestraController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    if Muestra.activa?
      # Con sesión las puertas no se dibujan aquí: para cambiar de rol se sale
      # —lo ofrece la franja de arriba— y se cae en ellas. Dibujarlas dentro
      # del panel sería la tapa metida en el marco de un colegio.
      redirect_to root_path if user_signed_in?
      return
    end

    destino = Muestra.direccion
    raise ActionController::RoutingError, "Aquí no hay colegio de muestra" if destino.nil?

    redirect_to destino, allow_other_host: true
  end

  def entrar
    raise ActionController::RoutingError, "Aquí no hay colegio de muestra" unless Muestra.activa?

    cuenta  = Muestra.cuenta(params[:rol])
    usuario = cuenta && Muestra.usuario_de(cuenta)

    # ⚠️ Una puerta que no abre lo DICE. Pasa en el minuto en que la muestra se
    # está restableciendo, y pasaría si alguien lograra borrar una cuenta: caer
    # en un «sin rol asignado» tres pantallas después no le explica nada a quien
    # vino a mirar.
    if usuario.nil?
      return redirect_to muestra_path,
                         alert: "Esa entrada no está disponible en este momento: la muestra se " \
                                "restablece cada noche. Pruebe de nuevo en un minuto."
    end

    # Cambiar de rol es salir y volver a entrar: `sign_out` se lleva el año, el
    # nivel y el colegio que había elegido el rol anterior, que son de la sesión.
    sign_out if user_signed_in?
    sign_in(:user, usuario)

    # Fija el colegio y deja el «inició sesión» en la bitácora, como cualquier
    # entrada. ⚠️ A dónde ir lo decide la petición SIGUIENTE: en esta, lo que el
    # controlador ya averiguó —si es representante, si es del equipo— se
    # preguntó antes de que hubiera sesión.
    after_sign_in_path_for(usuario)
    redirect_to root_path
  end
end
