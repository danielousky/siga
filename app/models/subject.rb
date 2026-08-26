class Subject < ApplicationRecord
  include SchoolScoped

  belongs_to :department

  derives_school_from :department

  has_many :grade_subjects, dependent: :destroy
  has_many :grades, through: :grade_subjects
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :restrict_with_error

  # El código es la nomenclatura interna del colegio: único dentro de él, no en
  # toda la plataforma. Un colegio que viene de otro sistema trae sus códigos ya
  # impresos en carnets y planillas.
  validates :code, presence: true, uniqueness: { scope: :school_id }
  validates :name, presence: true

  # ⚠️ La escala de ESTA materia, cuando no es la de su grado (MOR-99).
  #
  # `NULL` es lo normal y significa «la que diga el grado». La excepción existe
  # por la Certificación de Calificaciones del MPPE: desde el plan **31059**,
  # **Orientación y Convivencia** y **Participación en Grupos de Creación,
  # Recreación y Producción** se califican con LETRA aunque estén en bachillerato,
  # donde todo lo demás va del 1 al 20.
  #
  # El comentario de `Grade#escala` ya lo había previsto: *«poner un grado de
  # bachillerato en literal pondría en literal a Matemática, que es indefendible.
  # Si esas áreas del EMG hacen falta algún día, la escala tendría que vivir por
  # MATERIA.»* Hacen falta.
  enum :escala, { numerica: 0, literal: 1 }, prefix: :escala, allow_nil: true

  # Las dos áreas que la forma 31059 saca de la tabla de calificaciones y pone en
  # sus propias tablitas al final, con el literal por año.
  ORIENTACION = "orientacion y convivencia".freeze
  PARTICIPACION = "participacion en grupos".freeze

  # Las dos áreas del plan 31059 que van en literal. Se reconocen por nombre
  # porque es como llegan de cualquier planilla; el colegio puede corregirlo
  # marcando la materia a mano.
  DE_LITERAL_POR_NORMA = [ ORIENTACION, PARTICIPACION ].freeze

  # Con qué escala se muestra una nota de esta materia en un grado dado. La de la
  # materia gana si la declara; si no, manda el grado.
  def escala_en(grado) = escala.presence || grado&.escala

  # ¿El nombre es el de un área que la norma califica con letra? Se usa al
  # importar y al sembrar, para no obligar a marcarlas una por una.
  def self.de_literal_por_norma?(nombre) = area_del_31059(nombre).present?

  # Cuál de las dos áreas es, o `nil` si es un área de formación normal.
  def self.area_del_31059(nombre)
    comparable = Normaliza.limpiar(nombre).gsub(/[^a-z0-9 ]/, "")

    DE_LITERAL_POR_NORMA.find { |a| comparable.start_with?(a) }
  end
end
