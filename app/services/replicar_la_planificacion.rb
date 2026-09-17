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
#     qué INDICADORES mide cada una
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

  # ⚠️ Del AÑO PASADO: las evaluaciones SOLO si las dictaba el mismo profesor.
  #
  # Daniel, 17 de septiembre: *«cuando se trae la planificación del año
  # anterior, solo debería traer las competencias e indicadores; las
  # evaluaciones no. Esas deben ser agregadas nuevas, a menos que sea el mismo
  # profe, en ese caso se deben clonar para que haga el ajuste directamente
  # él»*.
  #
  # **Una evaluación es una decisión pedagógica de quien evalúa** —el peso del
  # examen, la fecha, qué mide— y heredarla de otro le pone al profesor nuevo un
  # criterio ajeno en su plan, que además no va a revisar porque vino puesto.
  # Las competencias sí se heredan: describen qué enseña el GRADO.
  #
  # Entre HERMANAS no hay decisión que tomar: `otras_secciones` son las
  # asignaciones de ESE mismo profesor, así que `para` siempre las trae.
  #
  #
  # La primera versión traía solo las competencias, con el argumento de que las
  # fechas del año pasado son de otro calendario. Daniel lo corrigió, y tenía
  # razón: la fecha no es un obstáculo, es una TRADUCCIÓN —mismo día y mes, el
  # año que corresponde— y las notas no viajan, así que no hay nada que
  # contaminar.
  #
  # Y es literalmente lo que pedía Cyndi, que es de donde sale `MOR-136`:
  #
  #   > *«nosotros todos los lapsos tenemos que estar cargando competencias e
  #   > indicadores… eso es de verdad una pérdida de tiempo muy grande»*
  #
  # Quedarse en las competencias dejaba la mitad del trabajo sin resolver: el
  # examen del 40 %, el taller del 30 y la participación del 30 se volvían a
  # escribir igual, todos los años.
  def self.del_ano_pasado(desde:, lapso_de_origen:, hacia:, lapso:, con_evaluaciones: false)
    new(desde, hacia, lapso, lapso_de_origen: lapso_de_origen,
        con_evaluaciones: con_evaluaciones).replicar
  end

  # `desde` y `hacia` son asignaciones (`TeacherSection`): sección + área.
  #
  # `lapso_de_origen` solo difiere al traer de otro año; entre hermanas es el
  # mismo, y por eso su valor por defecto es `lapso`.
  def initialize(desde, hacia, lapso, lapso_de_origen: nil, con_evaluaciones: true)
    @desde = desde
    @hacia = hacia
    @lapso = lapso
    @lapso_de_origen = lapso_de_origen || lapso
    @con_evaluaciones = con_evaluaciones
    @avisos = []
  end

  def replicar
    copiadas = copiar_competencias
    hechas   = con_evaluaciones ? copiar_evaluaciones : 0

    Resultado.new(competencias: copiadas, evaluaciones: hechas, avisos: @avisos)
  end

  private

  attr_reader :desde, :hacia, :lapso, :lapso_de_origen, :con_evaluaciones

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

      competencias = equivalentes_de(vieja)
      indicadores  = indicadores_equivalentes_de(vieja)
      next anotar_que_no_mide(vieja) if exige_plan? && (competencias.empty? || indicadores.empty?)

      en_su_savepoint do
        nueva = EvaluationActivity.new(
          section_id: hacia.section_id, subject_id: hacia.subject_id,
          evaluation_moment_id: lapso.id, description: vieja.description,
          weight_percentage: vieja.weight_percentage,
          date_scheduled: fecha_trasladada(vieja.date_scheduled)
        )
        # ⚠️ ANTES de guardar, no después: una evaluación de primaria tiene que
        # medir una competencia y un indicador, y eso se valida al crear. Con la
        # asignación después del `create!`, la copia quedaba rechazada siempre.
        nueva.competency_ids = competencias
        nueva.indicators     = indicadores
        nueva.save!
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

  # ⚠️ Los INDICADORES también se re-apuntan, un escalón más adentro.
  #
  # Una evaluación no mide la competencia entera: mide algunos de sus
  # indicadores, y no se repiten entre evaluaciones. Copiar sin esto dejaba el
  # plan del destino con las evaluaciones sin decir qué miden —y desde la regla
  # de Daniel, ni siquiera se podrían guardar—.
  #
  # Se busca por el PAR (canónica de la competencia, canónica del indicador):
  # el id es de la otra sección, y la canónica sola se repite entre competencias
  # («Participa en clase» puede estar en las dos).
  #
  # ⚠️ Y solo si está LIBRE en el destino. Si el profesor ya armó allá una
  # evaluación que mide ese indicador, tomarlo se lo QUITARÍA a la suya —
  # callado, porque la columna admite un solo dueño y el último gana.
  def indicadores_equivalentes_de(vieja)
    vieja.indicators.filter_map do |viejo|
      destino = indicadores_del_destino[[ viejo.competency.descripcion_canonica, viejo.descripcion_canonica ]]
      next if destino.nil? || destino.evaluation_activity_id.present?

      destino
    end
  end

  # Si el destino se planifica por competencias. En bachillerato no hay plan, y
  # una evaluación sin competencias es lo normal — no un aviso.
  def exige_plan? = hacia.section.grade.por_competencias?

  # ⚠️ La fecha se CORRE los años que separan los dos calendarios.
  #
  # Daniel: *«se le coloca el mismo mes y día del año pasado pero con el año
  # actual»*. Entre hermanas el desfase es cero y la fecha queda igual; del año
  # pasado, el examen del 8 de noviembre de 2025 pasa al 8 de noviembre de 2026.
  #
  # ⚠️ Se suman AÑOS, no días: `+ 1.year` sobre un 29 de febrero cae en el 28,
  # que es lo que un humano esperaría. Sumar 365 días lo correría un día en
  # cada bisiesto y, a los cuatro años, el examen del 8 de noviembre estaría el
  # 7 sin que nadie lo hubiera movido.
  def fecha_trasladada(fecha)
    return fecha if fecha.nil? || desfase_de_anios.zero?

    fecha + desfase_de_anios.years
  end

  def desfase_de_anios
    @desfase_de_anios ||= anio_de(lapso) - anio_de(lapso_de_origen)
  end

  # El año del calendario en que ARRANCA ese lapso. Del período académico y no
  # del lapso, porque `starts_on` es opcional: un colegio puede no habérselo
  # puesto y ahí el desfase saldría cero, dejando la fecha en el año pasado.
  def anio_de(momento)
    (momento.starts_on || momento.academic_period.start_date).year
  end

  # ── Lo que se lee una sola vez ────────────────────────────────────────────

  def plan_de_origen
    @plan_de_origen ||= Competency.del_plan(desde.section_id, desde.subject_id, lapso_de_origen.id)
                                  .includes(:indicators).to_a
  end

  def evaluaciones_de_origen
    @evaluaciones_de_origen ||= EvaluationActivity
                                .where(section_id: desde.section_id, subject_id: desde.subject_id,
                                       evaluation_moment_id: lapso_de_origen.id)
                                .includes(:competencies, indicators: :competency)
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

  # ⚠️ Se lee DESPUÉS de copiar las competencias, como su hermana de arriba: los
  # indicadores que acaban de crearse son justamente a los que hay que apuntar.
  #
  # ⚠️ Se memoiza con los OBJETOS, y eso es lo que impide robar dos veces el
  # mismo: al guardar, Rails le escribe el `evaluation_activity_id` al objeto en
  # memoria, así que la evaluación siguiente lo ve tomado.
  def indicadores_del_destino
    @indicadores_del_destino ||=
      Indicator.where(competency_id: competencias_del_destino.values)
               .includes(:competency)
               .index_by { |i| [ i.competency.descripcion_canonica, i.descripcion_canonica ] }
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

  # El otro caso de «no se pudo»: la evaluación del ORIGEN no dice qué mide.
  #
  # Pasa con lo escrito antes de que existiera la relación. Copiarla dejaría en
  # el destino el mismo hueco, y crearla ni siquiera se puede: una evaluación de
  # primaria mide una competencia y un indicador. Se dice dónde arreglarlo, que
  # es lo único accionable.
  def anotar_que_no_mide(vieja)
    @avisos << "«#{vieja.description}» no se copió: en #{desde.section.name} no dice qué indicadores mide."
    false
  end
end
