# Copiar el plan de una sección a sus hermanas (etapa ③).
#
# ## De dónde sale
#
# Daniel, describiendo el ciclo del docente: *«él puede clonar o copiar esa
# planificación de esa sección, o replicar esa planificación para otra sección.
# Entonces debería haber una opción, dentro de esa planificación, de replicar a
# las otras secciones hermanas»*.
#
# **Hermanas** = mismo grado, misma área, otra sección. «4to Grado A, B y C de
# Matemática» son hermanas, y es normal que las dicte el mismo profesor.
#
# ## Qué se copia, y qué no
#
#     SE COPIA                          NO SE COPIA
#     ────────                          ───────────
#     las competencias                  las NOTAS     ← son de los alumnos
#     sus indicadores                   quién dicta   ← ya está asignado
#     las evaluaciones, con su peso
#       y su fecha
#     qué competencia mide cada una
#
# ⚠️ Copiar competencias ya existía; **las evaluaciones son lo que faltaba**, y
# son la mitad más pesada del trabajo de septiembre: un profesor con tres
# secciones hermanas escribía las mismas cuatro evaluaciones doce veces.
#
# ## ⚠️ Lo que hace que esto sea difícil: el enganche se RE-APUNTA
#
# Una evaluación copiada no puede seguir midiendo la competencia del ORIGEN —
# esa pertenece a otra sección. Hay que engancharla a la competencia
# equivalente del DESTINO, y «equivalente» es por `descripcion_canonica`, que
# es la misma comparación que impide la competencia duplicada.
#
#     ORIGEN 4to A                       DESTINO 4to B
#     «Resuelve problemas de adición»    «Resuelve problemas de adición»
#              ▲                                  ▲
#              └── Examen 40 % ──copiar──► Examen 40 % ──────┘
#                                          (mide la de ACÁ)
#
# Sin eso, la copia deja las evaluaciones sin medir nada — y una competencia
# que ninguna evaluación mide sale en la boleta SIN nivel (`MOR-229`).
#
# ## ⚠️ ERROR vs AVISO, otra vez
#
# La misma distinción del importador (`§ 3`) y de `CopiarLaEstructura` (`§ 9`).
# Acá **nada es error**: lo que no se puede copiar se salta y se dice.
#
# El caso real es la ponderación: si el destino ya tiene un examen del 100 %,
# la evaluación del 40 % que viene no cabe. Abortar la copia entera por eso
# dejaría al profesor sin las otras tres, que sí cabían.
class ReplicarLaPlanificacion
  # Qué quedó, para poder contarlo en pantalla.
  Resultado = Data.define(:competencias, :evaluaciones, :avisos) do
    def initialize(competencias: 0, evaluaciones: 0, avisos: []) = super

    def nada? = competencias.zero? && evaluaciones.zero?
  end

  # A una sección HERMANA: el plan entero, competencias y evaluaciones.
  def self.para(desde:, hacia:, lapso:)
    new(desde, hacia, lapso).replicar
  end

  # ⚠️ Del AÑO PASADO: solo las competencias, y por eso tiene su propia puerta.
  #
  # Las evaluaciones del año que pasó no aplican: sus fechas son de otro
  # calendario y sus notas ya están cargadas contra ellas. Lo que se reutiliza
  # es el PLAN —«que un docente no vuelva a escribir una competencia que su
  # colegio ya escribió», que es todo `MOR-136`—, no la agenda.
  def self.solo_competencias(origen:, hacia:, lapso:)
    servicio = new(nil, hacia, lapso)
    servicio.plan_de_origen = origen
    servicio.replicar(evaluaciones: false)
  end

  # `desde` y `hacia` son asignaciones (`TeacherSection`): sección + área.
  def initialize(desde, hacia, lapso)
    @desde = desde
    @hacia = hacia
    @lapso = lapso
    @avisos = []
  end

  attr_writer :plan_de_origen

  def replicar(evaluaciones: true)
    copiadas = copiar_competencias
    hechas   = evaluaciones ? copiar_evaluaciones : 0

    Resultado.new(competencias: copiadas, evaluaciones: hechas, avisos: @avisos)
  end

  private

  attr_reader :desde, :hacia, :lapso

  # ── Las competencias, con sus indicadores ─────────────────────────────────

  def copiar_competencias
    ya_estan = canonicas_del_destino

    plan_de_origen.count do |vieja|
      next false if ya_estan.include?(vieja.descripcion_canonica)

      # ⚠️ Cada una en su SAVEPOINT: una que falle no puede tumbar las otras
      # veinte, y un `create!` fallido aborta la transacción de PostgreSQL —
      # las siguientes revientan con «current transaction is aborted».
      en_su_savepoint do
        nueva = Competency.create!(section_id: hacia.section_id, subject_id: hacia.subject_id,
                                   evaluation_moment_id: lapso.id,
                                   descripcion: vieja.descripcion, orden: vieja.orden)
        vieja.indicators.each { |i| nueva.indicators.create!(descripcion: i.descripcion, orden: i.orden) }
        ya_estan << nueva.descripcion_canonica
        true
      end
    end
  end

  # ── Las evaluaciones, con su peso y su enganche ───────────────────────────

  def copiar_evaluaciones
    ya_estan = descripciones_de_evaluaciones_del_destino

    evaluaciones_de_origen.count do |vieja|
      # ⚠️ Idempotente por DESCRIPCIÓN: correrlo dos veces no deja dos
      # «Examen del lapso». Es la misma regla que `CopiarLaEstructura`.
      next false if ya_estan.include?(Normaliza.para_comparar(vieja.description))

      en_su_savepoint do
        nueva = EvaluationActivity.create!(
          section_id: hacia.section_id, subject_id: hacia.subject_id,
          evaluation_moment_id: lapso.id, description: vieja.description,
          weight_percentage: vieja.weight_percentage, date_scheduled: vieja.date_scheduled
        )
        nueva.competency_ids = equivalentes_de(vieja)
        ya_estan << Normaliza.para_comparar(nueva.description)
        true
      end || anotar_que_no_cupo(vieja)
    end
  end

  # ⚠️ El enganche se RE-APUNTA a las competencias del DESTINO.
  #
  # Buscarlas por `descripcion_canonica` y no por id: el id es de la otra
  # sección. Y si la competencia no está en el destino —porque el profesor la
  # borró allá— la evaluación se copia igual, sin medir esa: es un aviso, no un
  # error.
  def equivalentes_de(vieja)
    canonicas = vieja.competencies.map(&:descripcion_canonica)
    return [] if canonicas.empty?

    competencias_del_destino.values_at(*canonicas).compact
  end

  # ── Lo que se lee una sola vez ────────────────────────────────────────────

  def plan_de_origen
    @plan_de_origen ||= Competency.del_plan(desde.section_id, desde.subject_id, lapso.id)
                                  .includes(:indicators).to_a
  end
  public :plan_de_origen

  def evaluaciones_de_origen
    @evaluaciones_de_origen ||= EvaluationActivity
                                .where(section_id: desde.section_id, subject_id: desde.subject_id,
                                       evaluation_moment_id: lapso.id)
                                .includes(:competencies)
                                .order(:date_scheduled, :id).to_a
  end

  def canonicas_del_destino
    Competency.del_plan(hacia.section_id, hacia.subject_id, lapso.id)
              .pluck(:descripcion_canonica).to_set
  end

  # ⚠️ Se lee DESPUÉS de copiar las competencias, no antes: las que acaban de
  # crearse son justamente a las que hay que enganchar las evaluaciones.
  def competencias_del_destino
    @competencias_del_destino ||=
      Competency.del_plan(hacia.section_id, hacia.subject_id, lapso.id)
                .pluck(:descripcion_canonica, :id).to_h
  end

  def descripciones_de_evaluaciones_del_destino
    EvaluationActivity.where(section_id: hacia.section_id, subject_id: hacia.subject_id,
                             evaluation_moment_id: lapso.id)
                      .pluck(:description)
                      .map { |d| Normaliza.para_comparar(d) }.to_set
  end

  # ── El detalle que evita el 500 ───────────────────────────────────────────

  def en_su_savepoint
    ActiveRecord::Base.transaction(requires_new: true) { yield }
  rescue ActiveRecord::RecordInvalid
    false
  end

  # El único caso real de «no cupo»: el destino ya tiene su 100 % repartido.
  # Se dice cuál y se sigue — abortar la copia entera dejaría al profesor sin
  # las otras tres, que sí cabían.
  def anotar_que_no_cupo(vieja)
    @avisos << "«#{vieja.description}» no cabe: #{hacia.section.name} ya tiene su ponderación completa."
    false
  end
end
