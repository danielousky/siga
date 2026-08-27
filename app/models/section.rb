class Section < ApplicationRecord
  include SchoolScoped

  belongs_to :grade
  belongs_to :academic_period

  # El profesor guía de esta sección (MOR-150).
  #
  # Es quien pasa lista y quien responde por estos alumnos. Va acá y no en el
  # grado porque en un colegio venezolano el guía es de la sección: «1er Año A»
  # tiene el suyo y «1er Año B» el suyo.
  #
  # Opcional por ahora: hay secciones cargadas antes de que esto existiera, y un
  # colegio que importa su matrícula todavía no asignó guías. Sin guía, la
  # dirección igual puede pasar lista — ver `AsistenciasController`.
  belongs_to :leader_teacher, class_name: "Teacher", optional: true

  derives_school_from :grade
  validates_same_school :academic_period, :leader_teacher

  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :destroy
  has_many :teachers, through: :teacher_sections

  validates :name, presence: true, uniqueness: { scope: [:grade_id, :academic_period_id] }
  validates :capacity, presence: true, numericality: { greater_than: 0 }

  # La letra que le toca a la próxima sección de este grado (MOR-153).
  #
  # ## Es un facto, no una ley — y por eso SUGIERE en vez de imponer
  #
  # Las secciones de un colegio venezolano se llaman A, B, C. No lo manda ningún
  # reglamento, pero es lo que hace todo el mundo, y por eso proponerlo ahorra
  # una decisión en cada una de las catorce filas de la planificación.
  #
  # Sugiere y no impone porque el «casi» importa: hay colegios con «Única», con
  # «A1», o que numeran. Rechazar eso sería inventar una ley que no existe.
  #
  # Mira solo las de UNA letra: si el colegio ya usa «Única», la siguiente es
  # «A» y no una letra deducida de una palabra.
  def self.siguiente_letra(grade:, academic_period:)
    usadas = where(grade: grade, academic_period: academic_period)
             .pluck(:name)
             .filter_map { |n| n.strip.upcase if n.to_s.strip.match?(/\A[A-Za-z]\z/) }

    return "A" if usadas.empty?

    siguiente = usadas.max.succ

    # Después de la Z no hay letra que siga: mejor dejar el campo vacío y que
    # una persona decida, antes que proponer «AA» a un colegio que nunca pasó
    # de la D.
    siguiente.length == 1 ? siguiente : nil
  end

  # Las materias que se dictan DE VERDAD en esta sección (MOR-152).
  #
  # ## ⚠️ Esto NO es `grade.subjects`, y la diferencia es un año escolar entero
  #
  # `grade_subjects` une grado y materia sin período: un grado tiene UN pensum
  # para toda su historia. Agregar Francés hoy lo metía en el boletín de 2021 —
  # una materia que ese alumno nunca vio.
  #
  # Lo que distingue un año de otro es **quién dicta qué**, y eso cuelga de la
  # SECCIÓN, que a su vez cuelga del período. O sea: el dato ya estaba, solo que
  # nadie lo estaba leyendo. No hizo falta una columna nueva.
  #
  # Se suman las materias con actividades porque `EvaluationActivity` apunta a la
  # sección y a la materia **directamente**, sin pasar por `TeacherSection`: una
  # materia puede tener evaluaciones cargadas antes de que se le asigne profesor,
  # y esa materia se dicta aunque la asignación falte.
  def materias_dictadas
    Subject.where(id: teacher_sections.select(:subject_id))
           .or(Subject.where(id: EvaluationActivity.where(section_id: id).select(:subject_id)))
           .order(:name)
  end
end
