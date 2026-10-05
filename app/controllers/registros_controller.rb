# El registro abierto (MOR-158).
#
# ## Qué cambia respecto de `MOR-101`
#
# El registro se había cerrado porque `users.email` es único en TODA la
# plataforma: cualquiera puede quemar el correo de un profesor real
# registrándolo antes que su colegio. Eso sigue siendo cierto.
#
# La decisión de producto es aceptarlo: **facilidad y velocidad de registro por
# encima de la seguridad**, mientras el acceso sea compartir el enlace a mano.
#
# ⚠️ Lo que hace tolerable el riesgo es el aislamiento, no la confianza:
# registrarse **crea siempre un colegio nuevo** y nunca se une a uno existente,
# así que el daño máximo de un abuso es una fila que no ve nada de nadie. Ese
# invariante vive en `MiColegioController` y no se puede aflojar sin volver a
# discutir esto.
class RegistrosController < Devise::RegistrationsController
  # Lo que se pide para abrir una cuenta (MOR-208).
  #
  # Daniel: *«el registro de usuario no debe incluir la cédula, solo lo más
  # sencillo: nombre y correo del usuario que va a manejar la cuenta»*, y en el
  # MISMO formulario el nombre del colegio, su código DEA y qué dicta.
  #
  #     LA PERSONA    nombre · apellido · correo · contraseña · cargo
  #     EL COLEGIO    nombre · código DEA · qué dicta (4 casillas)
  #
  # ⚠️ Lo que NO está acá también es una decisión: cédula, ubicación, teléfono,
  # dirección, logo y sello. Todo eso el colegio lo completa cuando quiera, y
  # pedirlo en el primer minuto es la diferencia entre registrarse y abandonar.
  PERMITIDOS = %i[first_name last_name email password password_confirmation].freeze

  before_action :configure_permitted_parameters

  # ⚠️ Quien YA tiene colegio no vuelve a pasar por acá.
  before_action :redirigir_si_ya_entro, only: [ :new, :create ]

  def new
    build_resource({})
    @colegio = School.new(sugerido_por_la_url)
    @niveles = []
    yield resource if block_given?
    respond_with resource
  end

  # Un envío crea la persona, su colegio, su rol, su plan y el andamiaje.
  # Todo el trabajo vive en `AltaDeUnColegio`; acá solo se traduce el
  # formulario y se decide a dónde se va después.
  def create
    alta = AltaDeUnColegio.crear(datos_de_la_persona: datos_de_la_persona,
                                 datos_del_colegio: datos_del_colegio,
                                 niveles: niveles_elegidos,
                                 cargo: cargo_elegido)

    # ⚠️ El correo va DESPUÉS del commit, nunca dentro de la transacción: un job
    # encolado adentro puede correr antes de que termine —o después de que se
    # deshaga— y darle la bienvenida a una cuenta que no existe.
    BienvenidaMailer.cuenta_creada(alta.usuario).deliver_later
    avisarle_a_siga(alta)

    sign_in(resource_name, alta.usuario)
    redirect_to arranque_listo_path, notice: "Listo, #{alta.colegio.name} ya existe."
  rescue AltaDeUnColegio::NoSePudo => e
    # Los dos objetos vuelven CON sus errores, así que el formulario los muestra
    # todos de una vez en vez de uno por envío.
    self.resource = e.usuario
    @colegio = e.colegio
    @niveles = niveles_elegidos
    render :new, status: :unprocessable_entity
  end

  # ¿Ese correo está libre? (MOR-208)
  #
  # Daniel: *«tiene que ser una validación muy rápida. Cuando él lo transcriba,
  # validamos de una vez allí si el correo está correcto y no existe»*.
  #
  # ⚠️ Esto NO agrega exposición, aunque lo parezca. Un endpoint que contesta
  # «ese correo ya existe» es un oráculo de enumeración… y el formulario ya lo
  # era: enviarlo con un correo tomado devuelve «Correo ya está en uso». Lo
  # único que cambia es que la respuesta llega antes de llenar el resto.
  #
  # ⚠️ Se busca SIN aislamiento y a propósito: `users.email` es único en toda la
  # plataforma, así que la pregunta «¿está libre?» solo tiene sentido global.
  # Preguntando dentro de un colegio diría «libre» y el INSERT fallaría igual.
  def correo_disponible
    correo = Normaliza.correo(params[:email])

    libre = correo.present? && Current.sin_aislamiento { !User.exists?(email: correo) }

    render json: { libre: libre, formato: correo.present? }
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: PERMITIDOS)
  end

  private

  # El aviso a SIGA de que entró un colegio nuevo (`MOR-158`).
  #
  # Son DOS correos por registro y van a dos personas distintas: la bienvenida
  # le llega a quien se registró; este, al equipo de SIGA, con los datos para
  # levantar el teléfono.
  #
  # ⚠️ Estuvo un mes sin salir. Al juntar el registro en un solo formulario
  # (`MOR-208`, 2 de septiembre de 2026) se borró la línea que lo mandaba, y el
  # test solo exigía «un correo»: la mitad que faltaba no se notó. La plantilla
  # y el mailer siguieron ahí, que es lo que hacía parecer que funcionaba.
  #
  # ⚠️ Se encola DENTRO del colegio nuevo, y no es ceremonia. En este momento la
  # petición no tiene colegio —quien se registra todavía no inició sesión— y un
  # job se lleva el que haya al encolarlo (`CarriesSchool`). Sin esto el aviso
  # corre sin colegio, el RLS le devuelve cero grados, y llega diciendo
  # «todavía no eligió sus niveles» de un colegio que sí los eligió.
  def avisarle_a_siga(alta)
    Current.en_el_colegio(alta.colegio) do
      PlataformaMailer.colegio_registrado(alta.colegio, alta.usuario).deliver_later
    end
  end

  # El colegio ya puesto cuando se llega desde el directorio público.
  #
  # ⚠️ SOLO el nombre y el código, y no es por prudencia sobrante: son los dos
  # únicos campos que el catálogo rellena de todas formas cuando alguien
  # escribe el nombre a mano. Aceptar más convertiría la URL en una manera de
  # preparar un registro entero desde afuera.
  #
  # ⚠️ Y son SUGERENCIA, como todo lo del catálogo: el formulario los muestra
  # editables y manda lo que quede escrito.
  def sugerido_por_la_url
    return {} if params[:school].blank?

    params.require(:school).permit(:name, :dea_code)
  end

  def datos_de_la_persona
    params.require(:user).permit(*PERMITIDOS).to_h.symbolize_keys
  end

  def datos_del_colegio
    # ⚠️ La ubicación entra desde el registro: llega ELEGIDA del catálogo del
    # MPPE, así que pedirla ya no cuesta un campo que escribir. Son los tres
    # datos que salen impresos en los documentos del ministerio.
    params.require(:school).permit(:name, :dea_code,
                                   :entidad_federal, :municipio, :municipio_libre,
                                   :parroquia, :parroquia_libre,
                                   :direccion, :telefono).to_h.symbolize_keys
  end

  # ⚠️ Se filtra contra `GradoOficial::NIVELES` y no se confía en el formulario:
  # es lo que decide qué grados y qué materias se siembran, o sea la forma del
  # colegio entero.
  def niveles_elegidos
    Array(params[:niveles]).map(&:to_sym) & GradoOficial::NIVELES
  end

  # ⚠️ Igual con el cargo: solo los tres que se ofrecen. Un `role` cualquiera
  # llegado por el formulario podría pedir `desarrollador`.
  # ⚠️ Y se traduce al ROL. «Otro cargo» es una etiqueta del formulario, no un
  # valor del enum: se guarda como `asistente`, que es dirección sin ser el
  # director. Ver `Admin::CARGO_AL_ROL`.
  def cargo_elegido
    cargo = params[:cargo].to_s
    Admin.rol_al_registrarse(Admin::CARGOS_AL_REGISTRARSE.key?(cargo) ? cargo : "director")
  end

  def redirigir_si_ya_entro
    return unless user_signed_in? && current_user.admins.any?

    redirect_to dashboard_path_for_user,
                alert: "Ya tienes un colegio. Para dar de alta otro, escríbenos."
  end
end
