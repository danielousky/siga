class Grade < ApplicationRecord
  include SchoolScoped
  llega_al_nivel_por

  # ⚠️ `preescolar` se agregó en MOR-153 y faltaba ENTERO: un colegio con
  # maternal no se podía representar, y son la mitad de los colegios privados
  # chicos de Venezuela.
  #
  # El valor 2 va al final a propósito aunque preescolar sea el primer nivel:
  # los enteros ya están escritos en la base y renumerarlos movería el nivel de
  # cada grado existente. El orden pedagógico lo da `orden`, no el enum.
  enum :level, { primaria: 0, secundaria: 1, preescolar: 2, media_tecnica: 3 }

  # ⚠️ «Media» es bachillerato, general O técnica — y es lo que casi todo el
  # código quería decir cuando preguntaba `secundaria?`.
  #
  # Al agregar la Media Técnica había SIETE lugares preguntando por el enum:
  # la validación de la escala, el default de la escala, la ficha del alumno y
  # cuatro puntos de la certificación 31059. Los siete se habrían quedado ciegos
  # ante el sexto año — y el peor de todos en silencio: la 31059 es el documento
  # de la educación media, y un Técnico Medio no habría podido pedirla.
  #
  # El enum distingue dos niveles; el dominio tiene un solo concepto. Preguntar
  # por el concepto es lo que hace que agregar un nivel no obligue a revisar el
  # proyecto entero.
  def media? = secundaria? || media_tecnica?

  # Con qué escala se califica este grado (MOR-129).
  #
  # Cuelga del GRADO y no del colegio: un mismo colegio tiene primaria por
  # literal y bachillerato por número, y las dos escalas conviven adentro. Con
  # esto en `School` ese colegio —que es el caso común— no se podría representar.
  #
  # ⚠️ **En secundaria la escala es SIEMPRE numérica.** Acá decía lo contrario,
  # justificado en que la certificación EMG de media general tiene dos áreas por
  # literal. Eso puede ser cierto y aun así no justifica nada, porque `escala`
  # vive en el GRADO: poner un grado de bachillerato en literal pondría en
  # literal a **Matemática**, que es indefendible.
  #
  # Si esas áreas del EMG hacen falta algún día, la escala tendría que vivir en
  # `GradeSubject` —por materia— y eso es otro issue. Al nivel donde el campo
  # existe hoy, la respuesta es única.
  enum :escala, { numerica: 0, literal: 1 }, prefix: :escala

  belongs_to :school
  # El COORDINADOR del grado, no su profesor guía (MOR-150).
  #
  # ⚠️ Esta columna se llamaba `leader_teacher` y eso era un error con
  # consecuencia: el guía es de la SECCIÓN —«1er Año A» tiene el suyo y «1er Año
  # B» el suyo—, así que colgarlo del grado hacía que un profesor pasara lista de
  # tres secciones ajenas y que los otros dos guías no vieran la propia.
  #
  # Del grado cuelga, si acaso, alguien que coordina a esos guías. Es opcional:
  # la mayoría de los colegios no tiene el cargo.
  belongs_to :coordinator_teacher, class_name: "Teacher", optional: true

  # El coordinador tiene que ser del mismo colegio que el grado.
  validates_same_school :coordinator_teacher

  # ⚠️ El nivel y el orden NO se capturan: se DEDUCEN del nombre (MOR-153).
  #
  # «4to Grado» es primaria y «4to Año» es secundaria — la palabra distingue el
  # nivel y no hay ambigüedad posible. Un campo que no se llena no se puede
  # llenar mal, y esto venía llenándose mal: el importador ponía el nivel a ojo
  # y una planilla de primaria terminaba con grados marcados como secundaria,
  # lo que cambia la escala de calificación del boletín entero.
  #
  # Si el nombre NO está en el catálogo, se respeta lo que venga: hay grados
  # cargados antes de esto y rechazarlos rompería colegios en producción por un
  # nombre mal escrito. Ver `#oficial?`.
  before_validation :deducir_nivel_y_orden

  has_many :grade_subjects, dependent: :destroy
  has_many :subjects, through: :grade_subjects
  has_many :sections, dependent: :restrict_with_error

  # El nombre es único dentro del colegio, no en toda la plataforma: dos colegios
  # tienen cada uno su "1er Año" sin saber que el otro existe.
  validates :name, presence: true, uniqueness: { scope: :school_id }

  # De 1er Nivel a 5to Año, en el orden en que un niño los cursa. Los que no
  # están en el catálogo caen al final: es mejor que caer en medio de los
  # oficiales, donde un nombre inventado se disfraza de grado real.
  scope :en_orden, -> { order(Arel.sql("orden IS NULL, orden"), :name) }

  # ¿Es uno de los catorce que fija el reglamento?
  def oficial? = GradoOficial.para(name).present?

  def entrada_oficial = GradoOficial.para(name)
  validates :level, presence: true
  validate  :la_media_se_califica_por_numero

  # Un grado nuevo nace con la escala que le corresponde por nivel, y quien
  # quiera lo cambia. Sin esto, cada grado de primaria que alguien cree se
  # llevaría el default de la columna —numérica— y el colegio volvería al
  # problema que este issue arregla, de a un grado por vez.
  #
  # ⚠️ «Quien quiera lo cambia» no era cierto en un caso, y el bug era invisible:
  # `Grade.new(level: :primaria, escala: :numerica)` salía LITERAL.
  #
  # La guardia miraba `escala_changed?`, y como el default de la columna ya es
  # `numerica`, declararla numérica no cambia nada — así que la guardia no
  # disparaba y el default por nivel la pisaba. Solo fallaba al declarar el
  # valor que coincide con el de la columna, que es justo el que uno declara
  # cuando quiere ir contra el nivel.
  #
  # Ahora se recuerda si ALGUIEN la asignó, que es la pregunta real.
  # ⚠️ La escala por defecto se calcula DOS veces, y las dos hacen falta.
  #
  # **Al construir**, porque `/grades/new` dibuja el desplegable de escala a
  # partir de `Grade.new(level: :primaria)`: si acá no está puesta, el
  # formulario le propone al director la escala equivocada y él la confirma sin
  # mirar.
  #
  # **Y antes de validar**, porque `Grade.new(name: "1er Año")` —el camino que
  # usa `SembrarGrados`— llega con `level` en nil: la escala saldría literal, la
  # deducción marcaría el grado como secundaria, y el modelo se pelearía con su
  # propia validación. Así, NINGÚN grado de bachillerato se podía crear por el
  # nombre.
  #
  # La segunda pasada solo actúa si nadie declaró la escala a mano, así que un
  # colegio de primaria que califica por número no la pierde.
  after_initialize  :escala_por_defecto_del_nivel, if: :new_record?
  before_validation :escala_por_defecto_del_nivel, if: :new_record?

  def escala=(valor)
    @escala_declarada = true
    super
  end

  private

  # La regla del dominio, no una preferencia: no existe la calificación literal
  # en secundaria. La primaria sí elige —hay colegios que usan número desde
  # primer grado— y por eso solo se valida un lado.
  def la_media_se_califica_por_numero
    return unless media? && escala_literal?

    errors.add(:escala, "en bachillerato siempre es numérica: la literal es de primaria")
  end

  # El nivel y el orden salen del catálogo, no del formulario (MOR-153).
  #
  # Si el nombre no está en el catálogo se respeta lo que venga: hay grados
  # cargados antes de esto, y rechazarlos rompería colegios en producción por un
  # nombre escrito distinto.
  def deducir_nivel_y_orden
    entrada = GradoOficial.para(name)
    return if entrada.nil?

    self.level = entrada.nivel
    self.orden = entrada.orden
  end

  def escala_por_defecto_del_nivel
    return if @escala_declarada

    # ⚠️ Preescolar va con primaria, no con secundaria. En preescolar la
    # calificación es CUALITATIVA por reglamento; `literal` es lo más cerca que
    # llega el modelo hoy. Un nivel de maternal con notas del 1 al 20 sería
    # indefendible delante de una madre, y es lo que salía por omisión antes de
    # MOR-153 porque el enum solo conocía dos niveles.
    self.escala = media? ? :numerica : :literal
    @escala_declarada = false
  end
end
