# El colegio viaja CON el job, no lo hereda del ambiente.
#
# `Current.school` vive en el hilo de la petición. Un job se encola dentro de una
# petición —donde el contexto existe— y se ejecuta después en un worker donde no
# hay petición, ni sesión, ni usuario. Ahí `Current.school` está en `nil`.
#
#   PETICIÓN                         WORKER (minutos después)
#   ─────────────────────            ────────────────────────
#   Current.school = Bolívar         Current.school = nil
#           │                                │
#      MiJob.perform_later ─────────►   MiJob#perform
#      "el contexto está acá"          "acá ya no hay contexto"
#
# Antes del RLS eso era una fuga silenciosa: el `default_scope` no filtraba y el
# job procesaba los dos colegios. Con el RLS puesto pasó a ser lo contrario —
# devuelve CERO filas— que es mejor, pero sigue siendo un job roto.
#
# La única forma de que un worker sepa para qué colegio trabaja es que se lo
# digan. Por eso el `school_id` se serializa en el payload al encolar, que es el
# momento en que el contexto todavía existe.
#
# Ver MOR-88.
module CarriesSchool
  extend ActiveSupport::Concern

  # Un job que debía trabajar para un colegio y no sabe cuál. Se levanta en vez
  # de correr sin filtro: la misma regla que en `SchoolScoped`, por la misma
  # razón — el silencio nunca significa "todos los colegios".
  class SinColegio < StandardError; end

  included do
    # :obligatorio → exige colegio; sin él, levanta excepción. Es el defecto:
    #                un job nuevo es de un colegio salvo que se diga lo contrario.
    # :opcional    → corre con el colegio que venga, o sin ninguno. Para lo que
    #                no toca tablas con colegio (el correo de "olvidé mi clave"
    #                sale sin sesión: en ese momento no hay inquilino que poner).
    # :plataforma  → cruza colegios a propósito, dentro de `sin_aislamiento`.
    class_attribute :modo_de_colegio, default: :obligatorio, instance_writer: false

    around_perform :con_el_colegio_del_payload
  end

  class_methods do
    # Para jobs que no tocan datos de ningún colegio.
    def colegio_opcional
      self.modo_de_colegio = :opcional
    end

    # Para backfills, métricas de red y limpiezas que miran toda la plataforma.
    # Tiene que escribirse a mano y se encuentra con un grep, igual que
    # `Current.sin_aislamiento`.
    def de_toda_la_plataforma
      self.modo_de_colegio = :plataforma
    end
  end

  # Se llama AL ENCOLAR, todavía dentro de la petición.
  def serialize
    super.merge("school_id" => Current.school_id)
  end

  def deserialize(job_data)
    super
    @school_id = job_data["school_id"]
  end

  # Con `perform_now` el job no pasa por serialize/deserialize, así que el
  # payload viene vacío aunque el contexto exista. En ese caso el colegio de la
  # petición ES el del job.
  def school_id
    @school_id || Current.school_id
  end

  private

  def con_el_colegio_del_payload(&bloque)
    anterior = Current.school

    case modo_de_colegio
    when :plataforma
      Current.sin_aislamiento(&bloque)
    when :opcional
      school_id.present? ? con_contexto(&bloque) : yield
    else
      raise SinColegio, mensaje_sin_colegio if school_id.blank?
      con_contexto(&bloque)
    end
  ensure
    # Restaurar, no `Current.reset`: si el job corrió con `perform_now` dentro de
    # una petición, un reset le borraría el contexto a la petición que sigue
    # ejecutándose.
    Current.school = anterior
  end

  # La transacción no es un detalle: `set_config(..., true)` es `SET LOCAL`, y
  # `SET LOCAL` sin transacción no dura nada. Un `SET` de sesión duraría de más
  # —el worker reusa la conexión para el job siguiente, que heredaría este
  # colegio— así que la transacción es lo que garantiza que el contexto muera
  # con el job aunque el proceso se caiga a la mitad.
  #
  # El costo es real y hay que tenerlo presente: el job entero corre en una sola
  # transacción. Un job largo que necesite ir confirmando por partes debe
  # partirse en varios jobs, no abrir el contexto a mano.
  def con_contexto
    # `SET LOCAL` pertenece a la transacción MÁS EXTERNA, no al bloque que lo
    # ejecuta: `ActiveRecord::Base.transaction` anidado no abre una nueva, se
    # suma a la que ya había. Así que un job corrido con `perform_now` dentro de
    # una petición le deja su colegio puesto a la petición, que sigue después
    # con la capa 1 diciendo A y la capa 2 diciendo B — cero filas y ninguna
    # explicación. Hay que devolver el valor a mano.
    anidado  = ActiveRecord::Base.connection.transaction_open?
    anterior = anidado ? contexto_en_la_base : nil

    ActiveRecord::Base.transaction do
      Current.school = School.find(school_id)
      fijar_contexto(school_id)
      yield
    ensure
      restaurar_contexto(anterior) if anidado
    end
  end

  def fijar_contexto(valor)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array(
        ["SELECT set_config('siga.school_id', ?, true)", valor.to_s]
      )
    )
  end

  def restaurar_contexto(valor)
    fijar_contexto(valor)
  rescue ActiveRecord::StatementInvalid
    # La transacción de afuera ya está abortada: se va a deshacer entera y con
    # ella el SET LOCAL. No hay nada que restaurar, y reventar acá taparía el
    # error de verdad.
    nil
  end

  def contexto_en_la_base
    ActiveRecord::Base.connection.select_value("SELECT current_setting('siga.school_id', true)")
  end

  def mensaje_sin_colegio
    "#{self.class.name} se encoló sin colegio. Un job trabaja para UN colegio: " \
    "asegurate de que `Current.school` esté puesto al encolarlo, o declará " \
    "`colegio_opcional` / `de_toda_la_plataforma` en la clase del job."
  end
end
