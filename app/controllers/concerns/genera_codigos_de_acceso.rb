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

    redirect_to volver_del_codigo, flash: { codigo: codigo, notice: aviso_del_codigo(usuario) }
  end

  private

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
