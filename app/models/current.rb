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

  # Marca los contextos donde mirar todos los colegios es legítimo y deliberado:
  # seeds, migraciones, tareas rake y la consola. Nunca una petición web.
  attribute :tenant_scope_disabled

  def school_id
    school&.id
  end

  # Corre el bloque sin filtro de colegio, en la app Y en la base.
  #
  # Es explícito y greppable a propósito: buscar `sin_aislamiento` muestra de una
  # todos los lugares que ven la plataforma entera. Un `unscoped` suelto no se
  # distingue de un `unscoped` que solo quería saltarse un `order`.
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
