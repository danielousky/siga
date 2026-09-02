# Los años escolares de un colegio nuevo, con sus lapsos (MOR-208).
#
# Daniel: *«podemos crear el año escolar, porque nosotros sabemos el día de hoy.
# Si está cerca de septiembre es porque va a iniciar el año escolar… Y puedo
# incluso crear los anteriores, por lo menos los cuatro anteriores. Y con los
# años anteriores puedo crear también los lapsos. No tengo que preguntarlo, lo
# puedo deducir»*.
#
# ## ⚠️ Los años PASADOS no son relleno: son lo que destraba el historial
#
# Un colegio que ya venía funcionando sube sus notas de años anteriores, y hoy
# tiene que ir creando esos años a mano o aceptándolos de a uno desde la
# previsualización del importador. Creados de entrada, ese paso pierde la
# fricción — que es justo el paso que decide si el colegio puede emitir una
# constancia de un egresado su primer día con SIGA.
#
# ## ⚠️ Las fechas son una AYUDA, no una ley
#
# Daniel, explícito: *«al final lo que hace falta es el año; las fechas de inicio
# y culminación son un estimado, no una regla inquebrantable que si no la tenemos
# se cae el mundo. Es una ayuda»*.
#
# Por eso acá no hay ninguna lógica de calendario propia: se usa
# `AcademicPeriod.para_el_anio`, que ya reparte del 15 de septiembre al 31 de
# julio, y el colegio corrige lo que no coincida con el suyo. Nada del sistema
# depende de que esas fechas sean exactas.
#
# ## ⚠️ Y el año en curso NO es «el más nuevo»
#
# En agosto el año más nuevo es el que todavía no empezó. `AcademicPeriod
# .anio_en_curso` ya resuelve eso —de enero a julio se está cursando el que
# arrancó el septiembre anterior— y el panel sigue eligiendo por
# `en_operacion`, o sea el que TIENE alumnos. Es la trampa que ya apareció tres
# veces en este proyecto; sembrar cinco años de golpe la hace más probable, no
# menos.
class SembrarAniosEscolares
  # Cuatro hacia atrás, como pidió Daniel. Alcanza para el historial de un
  # bachiller que se está por graduar y no llena la lista de años vacíos.
  ANIOS_HACIA_ATRAS = 4

  Resultado = Data.define(:creados, :ya_estaban, :lapsos) do
    def total = creados.size + ya_estaban.size
    def alguno_nuevo? = creados.any?
  end

  def self.para(colegio, hoy: Date.current, hacia_atras: ANIOS_HACIA_ATRAS)
    new(colegio, hoy, hacia_atras).sembrar
  end

  def initialize(colegio, hoy, hacia_atras)
    @colegio = colegio
    @hoy = hoy
    @hacia_atras = hacia_atras
  end

  def sembrar
    creados, ya_estaban, lapsos = [], [], 0

    # Una transacción sola: cinco años a medias —tres con lapsos y dos sin
    # ellos— es peor que ninguno, porque no hay forma de saber cuál quedó bien.
    ActiveRecord::Base.transaction do
      # Del más viejo al más nuevo, para que el orden de creación coincida con
      # el orden del calendario: los listados que ordenan por `id` no quedan al
      # revés de los que ordenan por fecha.
      anios.sort.each do |inicio|
        periodo = existente(inicio)

        if periodo
          ya_estaban << periodo
        else
          periodo = AcademicPeriod.para_el_anio(inicio, school: @colegio)
          periodo.save!
          creados << periodo
        end

        # ⚠️ Se cuenta lo CREADO, no lo devuelto. `sembrar_lapsos` es
        # idempotente y, cuando el año ya los tiene, los devuelve tal cual —así
        # que sumar su tamaño hacía que una segunda pasada informara «15 lapsos
        # nuevos» sin haber tocado nada. Un resumen que miente sobre lo que
        # acaba de hacer es peor que no tener resumen.
        lapsos += periodo.evaluation_moments.any? ? 0 : periodo.sembrar_lapsos.size
      end
    end

    Resultado.new(creados: creados, ya_estaban: ya_estaban, lapsos: lapsos)
  end

  private

  # ⚠️ El año que ENCABEZA la lista es el que corresponde HOY, no el próximo.
  #
  # `AcademicPeriod.proximo_anio` mira el último año cargado y devuelve el
  # siguiente — perfecto para el botón «crear el año que viene», y equivocado
  # acá: un colegio sin ningún año recibiría el que empieza en septiembre y
  # ninguno para el que está cursando.
  #
  # `anio_en_curso` es el que corresponde a la fecha: de enero a julio, el que
  # arrancó el septiembre anterior; desde septiembre, el que acaba de empezar.
  def anios
    (@hoy.month >= AcademicPeriod::COMIENZA[:mes] ? @hoy.year : @hoy.year - 1)
      .then { |actual| ((actual - @hacia_atras)..actual).to_a }
  end

  # ⚠️ Se busca por el AÑO DE INICIO y no por el nombre: un colegio que ya
  # escribió «2024 - 2025» a mano tiene el mismo año con otro texto, y crear el
  # segundo le dejaría dos años escolares que son el mismo.
  def existente(inicio)
    periodos_por_anio[inicio]
  end

  def periodos_por_anio
    @periodos_por_anio ||= @colegio.academic_periods.reload.index_by { |p| p.start_date.year }
  end
end
