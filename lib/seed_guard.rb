# Decide si los seeds pueden correr, y con qué contraseña.
#
# Vive acá y no adentro de `db/seeds.rb` por una razón concreta: **un guard sin
# test es una intención, no un control.** Metido en el archivo de seeds no se
# puede probar sin sembrar la base, y probarlo a mano contra producción falla
# antes de llegar al guard —Rails aborta primero por la conexión— así que uno
# cree que funciona sin haberlo visto funcionar nunca.
#
# ## Qué protege
#
# Los seeds crean cuentas con contraseña conocida, y una tiene rol
# `desarrollador`: máximo privilegio. Un `db:seed` contra la base de un colegio
# real no necesita ningún ataque para hacer daño — alcanza un comando en la
# terminal equivocada. Y como los seeds son idempotentes, ni siquiera fallaría.
#
# ## Lista blanca, no lista negra
#
# `unless Rails.env.production?` deja pasar un `staging` con datos reales, que
# tiene exactamente el mismo problema y no se llama production.
#
# Ver MOR-104.
class SeedGuard
  class EntornoNoPermitido < StandardError; end
  class FaltaLaClave < StandardError; end

  ENTORNOS_DE_PRUEBA = %w[development test].freeze
  CLAVE_POR_DEFECTO  = "123123".freeze

  def initialize(entorno: Rails.env.to_s, variables: ENV)
    @entorno = entorno
    @env = variables
  end

  def entorno_de_prueba?
    ENTORNOS_DE_PRUEBA.include?(@entorno)
  end

  # La única puerta fuera de desarrollo, y cuesta escribirla a propósito.
  def demo_declarada?
    @env["SIGA_ENTORNO_DEMO"] == "1"
  end

  def verificar!
    raise EntornoNoPermitido, mensaje_de_entorno unless entorno_de_prueba? || demo_declarada?
    raise FaltaLaClave, mensaje_de_clave if !entorno_de_prueba? && clave_declarada.blank?

    true
  end

  # En desarrollo y test hay default; en cualquier otro entorno NO. Una demo
  # pública con `123123` es una cuenta de administrador abierta a cualquiera que
  # lea el repositorio.
  def clave
    verificar!
    entorno_de_prueba? ? (clave_declarada.presence || CLAVE_POR_DEFECTO) : clave_declarada
  end

  # El desarrollador de los datos de prueba no lleva un correo personal: en una
  # URL pública sería la dirección real de alguien con contraseña conocida.
  def correo_desarrollador
    @env.fetch("SIGA_SEED_DEV_EMAIL", "desarrollador@siga.edu")
  end

  private

  def clave_declarada
    @env["SIGA_SEED_PASSWORD"]
  end

  def mensaje_de_entorno
    <<~MSG
      ✗ Los seeds NO corren en #{@entorno}.

        Crean cuentas con contraseña conocida, una de ellas con rol `desarrollador`.
        En la base de un colegio real eso es acceso total.

        Si esto ES una demo pública y sabes lo que estás haciendo:

          SIGA_ENTORNO_DEMO=1 SIGA_SEED_PASSWORD=<una-clave-de-verdad> bin/rails db:seed
    MSG
  end

  def mensaje_de_clave
    <<~MSG
      ✗ Falta SIGA_SEED_PASSWORD.

        En #{@entorno} la contraseña de los datos de prueba no tiene default: hay
        que elegirla. Una demo pública con `123123` es una cuenta de administrador
        abierta a cualquiera que lea este repositorio.
    MSG
  end
end
