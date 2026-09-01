class Student < ApplicationRecord
  include SchoolScoped

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  has_many :enrollments, foreign_key: :student_id, dependent: :restrict_with_error
  has_many :sections, through: :enrollments
  has_many :activity_grades, foreign_key: :student_id, dependent: :restrict_with_error

  # Los alumnos que nadie representa (MOR-180).
  #
  # ⚠️ Se compara con `id`, NO con `user_id`, y ese era el bug: el panel decía
  # «200 alumnos no tienen representante registrado» en un colegio de 200 con
  # cuatro vínculos cargados. Comparaba `students.user_id` contra
  # `student_representatives.student_id` —ids de dos tablas distintas— así que
  # ninguno coincidía nunca y el aviso salía con la matrícula completa.
  #
  # Lo peor de ese modo de fallar es que **el número se ve creíble**: un colegio
  # que acaba de importar su matrícula sin representantes esperaría justo eso, y
  # nadie lo cuestiona hasta que carga uno y el número no baja.
  #
  # Vive como scope porque lo piden tres pantallas: el panel lo cuenta, el
  # listado lo filtra y la ficha del alumno pregunta por uno solo.
  scope :sin_representante, -> { where.not(id: StudentRepresentative.select(:student_id)) }

  # El carnet lo emite el colegio: dos colegios pueden numerar igual sin saberlo.
  validates :school_card, presence: true, uniqueness: { scope: :school_id }

  # ⚠️ Si nadie lo trae, lo numera SIGA.
  #
  # El importador YA hacía esto —una planilla de matrícula rara vez trae
  # carnet— pero el alta a mano lo exigía y devolvía «Carnet no puede estar en
  # blanco». O sea: cargar 360 alumnos de un Excel funcionaba y agregar UNO a
  # mano no, pidiendo un número que la secretaria no tiene y que el sistema sabe
  # inventar. Lo encontró el test de la puesta en marcha.
  #
  # Y el cálculo estaba DUPLICADO en `CargaDeMatricula` y `CargaDeHistorial`,
  # con dos implementaciones distintas del mismo formato. Vive acá, que es de
  # donde lo pueden pedir los tres.
  before_validation :numerar_el_carnet, on: :create

  # «26-001»: los dos dígitos del año escolar en que entró, y un consecutivo.
  #
  # ⚠️ Se consulta la base en vez de llevar un contador en memoria. Dentro de una
  # importación eso son 360 consultas de ~0,3 ms —nada al lado de lo que tarda
  # el resto— y a cambio no hay caché que se quede vieja si dos cargas corren a
  # la vez. La fila recién insertada la ve la misma transacción.
  def self.siguiente_carnet(colegio, prefijo: prefijo_de_carnet)
    ultimo = unscoped.where(school_id: colegio.id)
                     .where("school_card LIKE ?", "#{prefijo}-%")
                     .pluck(:school_card)
                     .filter_map { |c| c.to_s.split("-").last.to_i }
                     .max.to_i

    "#{prefijo}-#{(ultimo + 1).to_s.rjust(3, '0')}"
  end

  # El año escolar del que sale el prefijo. El historial pasa el suyo, porque
  # cada fila de una planilla vieja es de un año distinto.
  def self.prefijo_de_carnet(periodo = nil)
    periodo ||= Current.academic_period || AcademicPeriod.vigente || AcademicPeriod.order(:start_date).last
    periodo&.start_date&.strftime("%y") || Date.current.strftime("%y")
  end

  private

  def numerar_el_carnet
    return if school_card.present?

    colegio = school || (School.find_by(id: school_id) if school_id)
    return if colegio.nil?

    self.school_card = self.class.siguiente_carnet(colegio)
  end
end
