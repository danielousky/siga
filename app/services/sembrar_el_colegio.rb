# El andamiaje completo de un colegio nuevo, de una sola vez (MOR-208).
#
# ## Por qué existe
#
# Daniel le pidió a su esposa que hiciera de directora, y el resultado fue el
# hallazgo que ordena todo este trabajo: *«los 8 pasos son engorrosos incluso
# para mí, que tengo todo el contexto; para un director puede llegar a ser
# frustrante»*.
#
# La mitad de esos pasos no pedían decisiones del colegio: pedían que
# transcribiera cosas que fija la ley y son idénticas en los 3.900 colegios del
# país. Este servicio las escribe solo, a partir del ÚNICO dato que sí es una
# decisión —qué niveles dicta— y de la fecha de hoy.
#
#     qué dicta el colegio  ──►  los GRADOS      SembrarGrados
#                           ──►  las MATERIAS    SembrarMaterias   (por grado)
#     la fecha de hoy       ──►  los AÑOS        SembrarAniosEscolares
#                           ──►  los LAPSOS      (nacen con el año)
#
# ## ⚠️ Los departamentos NO entran, y es una decisión
#
# Daniel: *«saltémonos la creación de los departamentos… Simplemente creemos las
# asignaturas directamente. Luego, si la escuela quiere un departamento, los
# creará aparte y les asignará las asignaturas»*. Siguen siendo un paso opcional
# de la puesta en marcha, exactamente como estaban.
#
# ## ⚠️ El ORDEN importa, y no es alfabético
#
# Las materias se cuelgan de los grados, así que los grados van primero. Es la
# misma razón por la que `SembrarMaterias` hace `reload` de la asociación: si
# corre en la misma petición que `SembrarGrados`, la lista de grados viene
# cacheada sin los recién creados y el colegio quedaría con materias sin asignar
# a ningún grado — o sea, sin poder cargar una nota.
#
# ## ⚠️ Es idempotente, y todo dentro de UNA transacción
#
# Un colegio que agrega bachillerato dos años después vuelve a pasar por acá y
# recibe solo lo que le falta. Y si algo falla, no queda un colegio con grados y
# sin años: media siembra es peor que ninguna, porque nadie sabe qué falta.
class SembrarElColegio
  Resultado = Data.define(:grados, :materias, :anios, :resumen) do
    def algo_nuevo? = grados.alguno_nuevo? || materias.alguna_nueva? || anios.alguno_nuevo?
  end

  def self.para(colegio, niveles:, hoy: Date.current)
    new(colegio, niveles, hoy).sembrar
  end

  def initialize(colegio, niveles, hoy)
    @colegio = colegio
    @niveles = niveles
    @hoy = hoy
  end

  def sembrar
    ActiveRecord::Base.transaction do
      grados   = SembrarGrados.para(@colegio, niveles: @niveles)
      materias = SembrarMaterias.para(@colegio)
      anios    = SembrarAniosEscolares.para(@colegio, hoy: @hoy)
      sembrar_la_rubrica

      Resultado.new(grados: grados, materias: materias, anios: anios, resumen: contar)
    end
  end

  private

  # ⚠️ La rúbrica FALTABA, y el colegio nuevo emitía las boletas de primaria sin
  # nivel.
  #
  # `restablecer_la_rubrica!` solo se llamaba desde el botón «Volver a la
  # propuesta de SIGA» y desde los seeds, así que un colegio registrado por el
  # formulario nacía con CERO filas. Y sin rúbrica, `ReportCardData#rubricas`
  # queda vacía y la boleta imprime el número pelado — que es exactamente lo
  # contrario de lo que MOR-136 vino a dar: «en primaria la familia no lee un
  # 17, lee un nivel».
  #
  # Lo vio Cyndi en la prueba de campo, en la boleta de 5to Grado.
  #
  # ⚠️ Solo si NO tiene ninguna: `restablecer_la_rubrica!` borra y vuelve a
  # crear, así que llamarlo a ciegas le pisaría al colegio los niveles que haya
  # ajustado. Correr el andamiaje dos veces no puede deshacer trabajo hecho.
  def sembrar_la_rubrica
    @colegio.restablecer_la_rubrica! if @colegio.rubrics.none?
  end

  # ⚠️ El resumen cuenta lo que HAY, no lo que se creó en esta pasada.
  #
  # La pantalla del paso 2 contesta «¿con qué cuenta su colegio?», no «¿qué
  # acabo de hacer?». Y la diferencia se ve al correrlo dos veces: sumando lo
  # creado, la segunda pasada informaría «0 grados, 0 materias» sobre un colegio
  # que tiene once y veinte.
  #
  # Se cuenta contra la BASE y no sumando los resultados de cada servicio, para
  # que no haya dos maneras de llegar al mismo número: la que se muestra y la
  # que es verdad.
  def contar
    { grados:   Grade.count,
      materias: Subject.count,
      anios:    AcademicPeriod.count,
      lapsos:   EvaluationMoment.count }
  end
end
