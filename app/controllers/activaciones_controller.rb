# La primera vez que alguien entra a SIGA (MOR-143).
#
# El colegio le generó un código de un solo uso; acá lo canjea por una
# contraseña propia. De ahí en adelante entra como todo el mundo, y "Olvidé mi
# contraseña" funciona normal.
#
# ## Por qué esto va sin sesión
#
# Quien abre este enlace **todavía no tiene contraseña**: ponerlo detrás de
# `authenticate_user!` sería pedirle que entre para poder entrar. Lo que lo
# protege es el propio código —de un solo uso, caducable y guardado digerido,
# no en claro—.
#
# ## Por qué se piden las dos cosas juntas
#
# Si falta el correo, se exige en la misma pantalla que la contraseña. Aceptar
# una sin la otra deja a alguien con contraseña puesta y sin correo, o sea **sin
# ninguna forma de recuperarla**: el mailer de Devise solo sabe escribirle al
# correo del usuario.
class ActivacionesController < ApplicationController
  skip_before_action :authenticate_user!

  def edit
    @token   = params[:token].to_s
    @usuario = usuario_del(@token)

    return render(:caducado, status: :gone) if @usuario.nil?

    @pide_correo = @usuario.email.blank?
  end

  def update
    @token   = params.dig(:user, :token).to_s
    @usuario = usuario_del(@token)

    return render(:caducado, status: :gone) if @usuario.nil?

    # ⚠️ Se calcula ANTES de asignar. Si la vista preguntara por
    # `@usuario.email.blank?`, al reintentar con un correo inválido el campo
    # habría desaparecido —ya no está en blanco: tiene el valor malo— y la
    # persona quedaría mirando un formulario que no le deja arreglar el error
    # que le acaban de señalar.
    @pide_correo   = @usuario.email.blank?
    @usuario.email = params.dig(:user, :email) if @pide_correo

    return render(:edit, status: :unprocessable_entity) unless correo_utilizable?

    if @usuario.reset_password(params.dig(:user, :password), params.dig(:user, :password_confirmation))
      sign_in(@usuario)
      redirect_to after_sign_in_path_for(@usuario), notice: "Listo: su acceso quedó activo."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Devise guarda el token DIGERIDO, así que la búsqueda va por el digest del
  # valor recibido. Un código que no existe y uno que caducó son la misma
  # pantalla a propósito: no hay nada útil que distinguirle a quien no lo tiene.
  def usuario_del(token)
    usuario = User.with_reset_password_token(token)
    usuario if usuario&.reset_password_period_valid?
  end

  # Que el correo choque contra otro ya registrado es el caso normal, no un
  # error raro: la misma mamá pudo quedar cargada dos veces antes de que el
  # colegio lo notara. Merece una frase que diga qué hacer, no "ya está en uso".
  # Los mensajes van en `:base` y no en `:email` para que se lean como frases.
  # Rails antepone el nombre del atributo —"Email hace falta…"— y ese nombre está
  # en inglés en toda la app, así que sobre una frase en español queda mal.
  def correo_utilizable?
    if @usuario.email.blank?
      @usuario.errors.add(:base, "Hace falta un correo: es por donde va a poder recuperar su contraseña.")
      return false
    end

    ya_registrado = User.where(email: @usuario.email).where.not(id: @usuario.id).exists?
    return true unless ya_registrado

    @usuario.errors.add(
      :base,
      "Ese correo ya está registrado en SIGA. Si usted ya tiene una cuenta, entre " \
      "con ella; si no, avísele al colegio."
    )
    false
  end
end
