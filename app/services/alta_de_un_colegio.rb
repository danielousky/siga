# Todo lo que pasa cuando alguien abre su cuenta en SIGA (MOR-208).
#
# Daniel: *«el registro inicial de un usuario debe ser el registro del usuario
# principal junto con los datos iniciales de la escuela… Ese es el primer paso,
# sencillo y directo»*.
#
#     ANTES                        AHORA
#     ─────                        ─────
#     /registrarse   la persona    /registrarse   la persona Y su colegio
#            ↓                            ↓
#     /mi-colegio    el colegio    un solo envío ──► persona
#            ↓                                   ──► colegio
#     8 pasos a mano               ──► rol de dirección
#                                  ──► plan Inicial
#                                  ──► andamiaje sembrado
#
# ## ⚠️ UNA transacción, y eso resuelve la objeción que separaba las pantallas
#
# Estaban separadas por una razón escrita: *«son dos actos distintos y el segundo
# puede fallar solo; juntarlos haría que un error de tipeo en la dirección le
# borre el usuario»*. Con la dirección fuera del formulario ese riesgo casi
# desaparece, y lo que queda lo cubre la transacción: si el colegio falla, no
# queda un usuario huérfano que después no puede volver a registrarse porque su
# correo «ya está en uso».
#
# ## ⚠️ El correo de bienvenida sale DESPUÉS del commit
#
# `deliver_later` dentro de la transacción encola un job que puede ejecutarse
# antes de que la transacción termine —o después de que se deshaga— y entonces
# se le da la bienvenida a una cuenta que no existe. Va afuera, y solo si todo
# salió bien.
class AltaDeUnColegio
  Resultado = Data.define(:usuario, :colegio, :andamiaje)

  class NoSePudo < StandardError
    attr_reader :usuario, :colegio

    def initialize(usuario, colegio)
      @usuario = usuario
      @colegio = colegio
      super("no se pudo crear la cuenta")
    end
  end

  def self.crear(datos_de_la_persona:, datos_del_colegio:, niveles:, cargo:, hoy: Date.current)
    new(datos_de_la_persona, datos_del_colegio, niveles, cargo, hoy).crear
  end

  def initialize(persona, colegio, niveles, cargo, hoy)
    @persona = persona
    @colegio = colegio
    @niveles = niveles
    @cargo = cargo
    @hoy = hoy
  end

  def crear
    usuario = User.new(@persona)
    colegio = School.new(@colegio)
    andamiaje = nil

    ActiveRecord::Base.transaction do
      # ⚠️ Se validan los DOS antes de guardar cualquiera, para que el
      # formulario vuelva con TODOS los errores y no con los del primer bloque.
      # Guardando en cadena, quien se equivoca en el correo y en el DEA corrige
      # uno, envía, y recién ahí se entera del otro.
      raise NoSePudo.new(usuario, colegio) unless [ usuario.valid?, colegio.valid? ].all?

      usuario.save!
      colegio.registrado_por = usuario
      colegio.save!

      # ⚠️ `Current.en_el_colegio` y no un `create` a secas: la petición empezó
      # SIN colegio —quien la hace todavía no tiene ninguno— así que
      # `siga.school_id` está vacío y el RLS rechaza el INSERT en `admins` con
      # un `PG::InsufficientPrivilege`. El colegio existe recién en esta línea.
      Current.en_el_colegio(colegio) do
        Admin.create!(user: usuario, school: colegio, role: @cargo)
        suscripcion_inicial(colegio)
        andamiaje = SembrarElColegio.para(colegio, niveles: @niveles, hoy: @hoy)
      end
    end

    Resultado.new(usuario: usuario, colegio: colegio, andamiaje: andamiaje)
  end

  private

  # ⚠️ Nace en el plan GRATIS, explícito, no sin suscripción.
  #
  # «Sin fila» significa otra cosa en este sistema —acceso completo, el piloto
  # que alguien acompaña— y confundirlos le daría a cualquiera que se registre
  # todo el producto.
  def suscripcion_inicial(colegio)
    Subscription.create!(school: colegio, plan: :gratis, status: :activa,
                         precio_mensual: 0, vigente_desde: Date.current,
                         notas: "Plan Inicial, creado al registrarse.")
  end
end
