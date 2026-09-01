# El año escolar de la sesión (MOR-165).
#
# ## Por qué existe
#
# Había CUATRO maneras de decidir qué año escolar mira una pantalla, cada una
# escrita a mano: `AcademicPeriod.vigente`, `.en_operacion`, el helper
# `periodo_vigente` y el prefijo del importador. Se contradecían en agosto —el
# año viejo terminó, el nuevo no empezó— y ninguna le preguntaba a la persona.
#
# Daniel: *«vamos a implementar la figura de año escolar de la sesión. Ese lo
# vamos a tomar como pivote para filtrar todo lo que sea filtrable»*.
#
# ## Dónde se guarda, y por qué no es como el colegio
#
# `Current.school` sale del ROL y jamás de un parámetro: si el inquilino se
# pudiera elegir, el aislamiento no serviría de nada.
#
# El año escolar es otra cosa: es una preferencia de quien mira, y elegir uno
# **no da acceso a nada nuevo** —los años de otro colegio ya son invisibles por
# el RLS—. Por eso vive en la sesión y se cambia con un clic.
#
# ⚠️ Se busca CON el `default_scope` de `SchoolScoped`, no con `unscoped`: así,
# un id de otro colegio guardado en la sesión simplemente no encuentra nada y se
# cae al valor por defecto. La comprobación la hace el aislamiento, no un `if`.
module LlevaElAnioEscolar
  extend ActiveSupport::Concern

  CLAVE = :anio_escolar
  TODOS = "todos".freeze

  included do
    before_action :fijar_el_anio_escolar
    helper_method :anio_de_la_sesion, :anios_para_elegir, :mirando_todos_los_anios?,
                  :puede_elegir_anio?, :anio_de_trabajo
  end

  private

  # ⚠️ Corre DENTRO del `around_action` del colegio: sin `Current.school` fijado,
  # el RLS devuelve cero filas y no habría ningún año que elegir.
  def fijar_el_anio_escolar
    return if Current.school.nil?

    Current.academic_period = anio_de_la_sesion
  end

  def anio_de_la_sesion
    return @anio_de_la_sesion if defined?(@anio_de_la_sesion)

    @anio_de_la_sesion = calcular_el_anio
  end

  def calcular_el_anio
    guardado = session[CLAVE]

    # «Todos los años» es una elección legítima: la secretaria que busca la
    # constancia de un egresado necesita ver lo viejo.
    return nil if guardado == TODOS

    # ⚠️ Un profesor NO elige año: ve el que está cursando.
    #
    # Daniel: «los docentes no deberían necesitar ni siquiera ver algo anterior,
    # solo lo que están calificando». Darle el selector es darle una manera de
    # cargar notas en el año equivocado sin enterarse.
    return anio_por_defecto unless puede_elegir_anio?

    (guardado && AcademicPeriod.find_by(id: guardado)) || anio_por_defecto
  end

  # ⚠️ `en_operacion` ANTES que `vigente`, y la diferencia solo se ve en agosto.
  #
  # Daniel pidió «que por defecto esté el más reciente», y la trampa está en qué
  # significa eso. Hoy —31 de agosto de 2026— la fila más nueva es 2026-2027, que
  # empieza en dos semanas y no tiene ni una sección: entrar ahí es abrir el
  # panel del colegio lleno y leer «0 secciones, 0 alumnos».
  #
  # El más reciente que SIRVE es el último con alumnos adentro. Y se corrige
  # solo: en cuanto el colegio inscribe para 2026-2027 —que se hace en julio—
  # `en_operacion` pasa a devolver ese, sin que nadie toque nada.
  #
  # Es la misma trampa de `Subscription.matricula_de` y la de `periodo_en_curso`
  # en el panel del director. Tercera vez que aparece; ahora vive en un solo
  # lugar.
  def anio_por_defecto
    AcademicPeriod.en_operacion || AcademicPeriod.vigente
  end

  # El año sobre el que trabaja una pantalla que NO PUEDE no tener uno: el panel
  # del director, «quién no cargó notas», la emisión de boletines.
  #
  # ⚠️ La diferencia con `anio_de_la_sesion` es qué hacer con «Todos los años».
  # Para un LISTADO, «todos» es una respuesta perfecta. Para «¿quién no cargó
  # notas?» no lo es: la pregunta se responde sobre un año o no se responde.
  # Ahí se cae al año donde hay clases, que es lo que ya hacían estas pantallas
  # cada una por su cuenta.
  def anio_de_trabajo
    return @anio_de_trabajo if defined?(@anio_de_trabajo)

    @anio_de_trabajo = anio_de_la_sesion || AcademicPeriod.en_operacion
  end

  # Los años entre los que se puede elegir, del más nuevo al más viejo.
  def anios_para_elegir
    @anios_para_elegir ||= AcademicPeriod.order(start_date: :desc).to_a
  end

  def mirando_todos_los_anios? = puede_elegir_anio? && session[CLAVE] == TODOS

  # Quién ve el selector. El profesor y el alumno no: para ellos el año escolar
  # no es una preferencia, es dónde están parados.
  def puede_elegir_anio?
    administrador? || equipo_de_siga?
  end
end
