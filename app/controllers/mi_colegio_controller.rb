# El colegio que crea quien acaba de registrarse (MOR-158).
#
# ## El invariante que sostiene el registro abierto
#
# **Crear un colegio SIEMPRE crea uno nuevo.** Nunca se une a uno existente, no
# hay código de invitación, no se busca por código DEA. Es lo que hace que el
# registro abierto sea tolerable: el daño máximo de un abuso es una fila en la
# base que, por el RLS, no ve nada de nadie.
#
# Aflojar esto —«que pueda unirse si el DEA ya existe»— convierte el registro
# abierto en una puerta a los datos de un colegio real. No se toca sin volver a
# discutir la decisión entera.
#
# ## Y por qué el colegio se crea acá y no en el registro
#
# Son dos actos distintos y el segundo puede fallar solo: si el DEA está
# repetido o falta un campo, la persona ya tiene su cuenta y vuelve a intentar.
# Juntarlos haría que un error de tipeo en la dirección le borre el usuario.
class MiColegioController < ApplicationController
  include NormalizaLaUbicacion
  # ⚠️ Quien llega acá TODAVÍA NO TIENE colegio, así que `Current.school` queda
  # en nil y el RLS no devuelve ni una fila. Está bien: esta pantalla no consulta
  # nada del colegio — lo está creando.
  before_action :redirigir_si_ya_tiene_colegio

  def new
    @colegio = School.new
  end

  def create
    # Qué dicta el colegio no se pregunta acá: se deduce de los grados, y los
    # grados se siembran marcando niveles en `/niveles` (MOR-160).
    @colegio = School.new(con_la_ubicacion_resuelta(colegio_params)
                            .merge(registrado_por: current_user))

    School.transaction do
      @colegio.save!

      # ⚠️ `Current.en_el_colegio` y no un `create` a secas.
      #
      # La petición empezó SIN colegio —quien la hace todavía no tiene ninguno—
      # así que `siga.school_id` está vacío y el RLS rechaza el INSERT en
      # `admins` con un `PG::InsufficientPrivilege`. Es el aislamiento haciendo
      # exactamente lo que se le pidió: sin contexto no se escribe nada.
      #
      # El colegio existe recién en esta línea, así que el contexto se fija acá
      # adentro y no en el `around_action`, que corrió antes de que existiera.
      Current.en_el_colegio(@colegio) do
        Admin.create!(user: current_user, school: @colegio, role: :director)
        suscripcion_inicial
      end
    end

    PlataformaMailer.colegio_registrado(@colegio, current_user).deliver_later

    redirect_to dashboards_administrador_path,
                notice: "Listo, #{@colegio.name} ya existe. Empiece por elegir qué niveles dicta."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  # ⚠️ Nace en el plan GRATIS, explícito, no sin suscripción.
  #
  # «Sin fila» significa otra cosa en este sistema —acceso completo, el piloto
  # que alguien acompaña— y confundirlos le daría a cualquiera que se registre
  # todo el producto. `gratis` es una decisión escrita y visible en la cartera:
  # carga todo lo que quiera; calificar, pasar lista y emitir se activan al
  # contratar un plan.
  def suscripcion_inicial
    Subscription.create!(school: @colegio, plan: :gratis, status: :activa,
                         precio_mensual: 0, vigente_desde: Date.current,
                         notas: "Plan Inicial, creado al registrarse.")
  end

  def redirigir_si_ya_tiene_colegio
    return if current_user.admins.none?

    redirect_to dashboard_path_for_user,
                alert: "Ya tienes un colegio. Para dar de alta otro, escríbenos."
  end

  def colegio_params
    # `school_type` NO se acepta acá: no se pregunta en el alta y se deduce de
    # los grados en `SembrarGrados`. Ver `mi_colegio/new`.
    params.require(:school).permit(:name, :dea_code, :location,
                                   :entidad_federal, :municipio, :municipio_libre,
                                   :parroquia, :parroquia_libre,
                                   :direccion, :telefono)
  end
end
