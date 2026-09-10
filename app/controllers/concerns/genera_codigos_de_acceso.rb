# El código con el que alguien entra a SIGA por primera vez (MOR-143).
#
# ⚠️ El código es de la PERSONA, no de su rol.
#
# Nació en la ficha del representante y se quedó ahí, así que profesores y
# administradores seguían con "que alguien más te elija la contraseña" — que es
# exactamente el patrón que este trabajo vino a sacar. Y el importador de pensum
# lo volvió urgente: carga ocho profesores de un golpe, todos con correo y
# ninguno con contraseña.
#
# Es la MISMA funcionalidad para todos, y por eso vive acá y no copiada tres
# veces. El día que un alumno tenga que entrar, son dos líneas en su controller.
#
# ## Por qué un concern y no un controller central
#
# Un `POST /personas/:id/codigo` tendría que resolver a mano si esa persona
# pertenece a este colegio — y `User` **no** es `SchoolScoped`: una persona es de
# la plataforma. Olvidarlo daría un IDOR peor que el de MOR-86, porque acá lo que
# se filtra no es una ficha: es una llave.
#
# Colgando de cada controller, el `set_teacher` / `set_representative` que ya
# existe hace ese filtro con el `default_scope` del rol, que es de donde no se
# puede escapar por descuido.
#
# Cada controller declara `genera_codigos_de_acceso_para :teacher` y el rol dice
# de quién es el usuario y a dónde se vuelve.
module GeneraCodigosDeAcceso
  extend ActiveSupport::Concern

  class_methods do
    # `rol` es el nombre de la variable que ya carga el `before_action`:
    # `:teacher` usa `@teacher`, `:representative` usa `@representative`.
    #
    # `volver_a` es a dónde se vuelve con el código en la mano: la ficha si el
    # rol tiene una, el listado si no. `Admin` no tiene `show` —se edita y se
    # lista— y forzarle una pantalla por un botón sería al revés.
    #
    # ⚠️ Se declara, no se deduce. `url_for(admin)` NO revienta aunque no exista
    # la ruta `show`: `resources :admins, except: [:show]` igual genera
    # `admin_path` para el PATCH y el DELETE, así que el redirect salía a una URL
    # que existe para otros verbos y devolvía 404 en GET.
    def genera_codigos_de_acceso_para(rol, volver_a: :ficha)
      define_method(:registro_del_codigo) { instance_variable_get("@#{rol}") }
      define_method(:volver_del_codigo) do
        volver_a == :index ? url_for(action: :index) : url_for(registro_del_codigo)
      end
    end
  end

  def generar_codigo
    usuario = registro_del_codigo.user
    codigo  = usuario.generar_codigo_de_acceso!

    enviar_el_codigo(usuario, codigo)

    guardar_para_mostrar(usuario, codigo)

    redirect_to volver_del_codigo, notice: aviso_del_codigo(usuario)
  end

  private

  # ⚠️ El código va en la SESIÓN, no en el `flash`, y esa es la corrección.
  #
  # El flash vive UN render, y acá llegan dos: `button_to` envía con Turbo, el
  # redirect se sigue con `Accept: text/vnd.turbo-stream.html`, y como no hay
  # plantilla `.turbo_stream` Rails contesta HTML — que Turbo no sabe aplicar,
  # así que repite la visita como navegación normal. El primer render mostraba
  # el enlace y el segundo, medio segundo después, repintaba la pantalla sin él.
  #
  #     POST /representantes/411/codigo
  #       └─► GET /representantes/411   as TURBO_STREAM   ← el flash sale acá
  #           └─► GET /representantes/411   as HTML       ← y acá ya no está
  #
  # Daniel lo reportó DOS veces. La primera se movió el bloque arriba del todo
  # —creyendo que era posición— y siguió pasando, porque la causa era otra.
  #
  # ⚠️ Y de paso arregla algo que era malo de por sí: un enlace que se ve una
  # sola vez y NO SE PUEDE RECUPERAR no debe depender de que el navegador no
  # recargue. Ahora sobrevive a la recarga, y se va cuando la secretaria dice
  # que ya lo copió o cuando se genera otro.
  def guardar_para_mostrar(usuario, codigo)
    session[:codigo_a_la_vista] = { "user_id" => usuario.id, "codigo" => codigo }
  end

  # Si tiene correo se lo mandamos, y ADEMÁS queda en pantalla: el correo puede
  # tardar, caer en spam o rebotar, y la secretaria tiene a la persona delante.
  #
  # ⚠️ Va el `codigo` que devolvió `generar_codigo_de_acceso!`, no
  # `usuario.reset_password_token`. Devise guarda el DIGEST en esa columna: el
  # valor en claro existe una sola vez, en ese retorno. Mandando la columna se
  # envía un enlace que no abre nada.
  def enviar_el_codigo(usuario, codigo)
    return if usuario.email.blank?

    AccesoMailer.activacion(usuario, codigo, Current.school).deliver_later
  end

  def aviso_del_codigo(usuario)
    if usuario.email.present?
      "Se le envió el enlace a #{usuario.email}."
    else
      "#{Normaliza.titulo(usuario.first_name)} no tiene correo cargado: hágale llegar el enlace usted."
    end
  end
end
