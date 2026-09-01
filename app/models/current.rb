# El colegio de la petición en curso.
#
# `ActiveSupport::CurrentAttributes` vive por hilo y por request, y Rails lo
# limpia solo al terminar cada una. Eso es exactamente lo que se quiere: que el
# inquilino no sobreviva a la petición que lo estableció.
#
# ⚠️ El colegio sale SIEMPRE del rol del usuario autenticado — nunca de un
# parámetro. Ni de la URL, ni de un header, ni de un campo oculto del formulario.
# Si el inquilino pudiera venir del request, el atacante elegiría el suyo y todo
# el aislamiento no serviría de nada.
#
# Ver MOR-86.
class Current < ActiveSupport::CurrentAttributes
  attribute :school

  # El AÑO ESCOLAR de la sesión (MOR-165).
  #
  # ## Por qué esto hacía falta
  #
  # Había cuatro maneras distintas de decidir «qué año escolar estamos mirando»,
  # cada una escrita a mano en su pantalla: `AcademicPeriod.vigente`,
  # `.en_operacion`, el helper `periodo_vigente`, y el prefijo del importador.
  # Se contradecían en agosto —cuando el año viejo terminó y el nuevo no empezó—
  # y ninguna le preguntaba a la persona.
  #
  # Ahora se elige una vez, arriba, y filtra todo lo filtrable.
  #
  # ## ⚠️ Este SÍ puede venir del usuario, y el colegio NO
  #
  # `Current.school` sale del rol y jamás de un parámetro: si el inquilino
  # pudiera elegirse, el aislamiento no serviría de nada.
  #
  # El año escolar es lo contrario: es una preferencia de quien mira, y elegir
  # uno **no da acceso a nada nuevo** — los años escolares de otro colegio ya son
  # invisibles por el RLS. Por eso puede vivir en la sesión y cambiarse con un
  # clic. Lo que sí hace falta es comprobar que el año elegido sea de ESTE
  # colegio; de eso se encarga `SchoolScoped` al buscarlo.
  #
  # `nil` significa «todos los años», y es una opción legítima: la secretaria que
  # busca una constancia de un egresado necesita ver lo viejo.
  attribute :academic_period

  # Marca los contextos donde mirar todos los colegios es legítimo y deliberado:
  # seeds, migraciones, tareas rake y la consola. Nunca una petición web.
  attribute :tenant_scope_disabled

  def school_id
    school&.id
  end

  def academic_period_id = academic_period&.id

  # ¿Estamos mirando un año concreto, o todos?
  def un_solo_anio? = academic_period.present?

  # Corre el bloque sin filtro de colegio, en la app Y en la base.
  #
  # Es explícito y greppable a propósito: buscar `sin_aislamiento` muestra de una
  # todos los lugares que ven la plataforma entera. Un `unscoped` suelto no se
  # distingue de un `unscoped` que solo quería saltarse un `order`.
  # Corre el bloque DENTRO de un colegio concreto, en las dos capas.
  #
  #     sin_aislamiento    →  APAGA el filtro    (ve la plataforma entera)
  #     en_el_colegio      →  APUNTA el filtro   (ve un colegio, y solo ese)
  #
  # Existe porque hay trabajo legítimo de plataforma que necesita **escribir** en
  # un colegio: el rastro que deja una visita de soporte, un backfill dirigido.
  # Con `sin_aislamiento` también andaría —y por eso es tentador— pero apagaría
  # el aislamiento entero para tocar una fila de un colegio que ya se sabe cuál
  # es.
  #
  # Lo pidió el `WITH CHECK` de una política rechazando un INSERT: el RLS
  # haciendo exactamente lo que se le pidió, y de paso señalando lo que faltaba.
  def self.en_el_colegio(colegio)
    anterior_school = school
    anterior_bypass = tenant_scope_disabled

    self.school = colegio
    self.tenant_scope_disabled = false
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'off'")
    fijar_contexto(colegio&.id)

    yield
  ensure
    self.school = anterior_school
    self.tenant_scope_disabled = anterior_bypass
    fijar_contexto(anterior_school&.id)
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'on'") if anterior_bypass
  end

  def self.fijar_contexto(school_id)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(
        ["SELECT set_config('siga.school_id', ?, false)", school_id.to_s]
      )
    )
  end
  private_class_method :fijar_contexto

  def self.sin_aislamiento
    anterior = tenant_scope_disabled
    self.tenant_scope_disabled = true
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'on'")
    yield
  ensure
    self.tenant_scope_disabled = anterior
    ActiveRecord::Base.connection.execute("SET siga.bypass_rls = 'off'") unless anterior
  end
end
