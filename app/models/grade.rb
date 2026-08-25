class Grade < ApplicationRecord
  include SchoolScoped

  enum :level, { primaria: 0, secundaria: 1 }

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
  belongs_to :leader_teacher, class_name: "Teacher", optional: true

  # El profesor guía tiene que ser del mismo colegio que el grado.
  validates_same_school :leader_teacher

  has_many :grade_subjects, dependent: :destroy
  has_many :subjects, through: :grade_subjects
  has_many :sections, dependent: :restrict_with_error

  # El nombre es único dentro del colegio, no en toda la plataforma: dos colegios
  # tienen cada uno su "1er Año" sin saber que el otro existe.
  validates :name, presence: true, uniqueness: { scope: :school_id }
  validates :level, presence: true
  validate  :secundaria_se_califica_por_numero

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
  after_initialize :escala_por_defecto_del_nivel, if: :new_record?

  def escala=(valor)
    @escala_declarada = true
    super
  end

  private

  # La regla del dominio, no una preferencia: no existe la calificación literal
  # en secundaria. La primaria sí elige —hay colegios que usan número desde
  # primer grado— y por eso solo se valida un lado.
  def secundaria_se_califica_por_numero
    return unless secundaria? && escala_literal?

    errors.add(:escala, "en secundaria siempre es numérica: la literal es de primaria")
  end

  def escala_por_defecto_del_nivel
    return if @escala_declarada

    self.escala = primaria? ? :literal : :numerica
    @escala_declarada = false
  end
end
