class Section < ApplicationRecord
  include SchoolScoped

  belongs_to :grade
  belongs_to :academic_period

  # El profesor guía de esta sección (MOR-209).
  #
  # Es quien pasa lista y quien responde por estos alumnos. Va acá y no en el
  # grado porque en un colegio venezolano el guía es de la sección: «1er Año A»
  # tiene el suyo y «1er Año B» el suyo.
  #
  # Opcional por ahora: hay secciones cargadas antes de que esto existiera, y un
  # colegio que importa su matrícula todavía no asignó guías. Sin guía, la
  # dirección igual puede pasar lista — ver `AsistenciasController`.
  belongs_to :leader_teacher, class_name: "Teacher", optional: true
  llega_al_anio_por
  llega_al_nivel_por :grade
  derives_school_from :grade
  validates_same_school :academic_period, :leader_teacher, :bell_schedule

  # El TURNO: a qué hora suena el timbre de esta sección (spec `horarios`).
  #
  # Opcional: una sección existe antes de que alguien arme el horario, y un
  # colegio que no usa horarios nunca lo necesita.
  #
  # ⚠️ Tiene que ser de SU año. Los turnos son del año escolar, como las
  # secciones: el de 2025-2026 puede haber sonado a otra hora, y una sección de
  # este año colgada de aquel leería un timbre que ya no existe.
  belongs_to :bell_schedule, optional: true
  validate :el_turno_es_de_su_anio

  has_many :enrollments, dependent: :restrict_with_error
  has_many :students, through: :enrollments
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :destroy
  # Las borra la base al borrar la sección (`lessons_de_su_seccion`, en cascada).
  has_many :lessons
  has_many :teachers, through: :teacher_sections

  # ⚠️ El identificador es CORTO y alfanumérico: «A», «B», «U1» (MOR-170).
  #
  # Sin el formato, «A », « A» y «Sección A» son tres secciones distintas para el
  # índice único, y el colegio termina con duplicados que solo se ven al mirar
  # dos filas seguidas. Y peor: el identificador sale impreso en el boletín y en
  # los documentos del MPPE, donde un espacio de más se nota.
  #
  # No es una lista cerrada a propósito: un colegio puede usar «U1» o «Rojo». Lo
  # que se prohíbe es el texto libre con espacios y símbolos.
  validates :name, presence: true,
                   uniqueness: { scope: [ :grade_id, :academic_period_id ] },
                   format: { with: /\A[[:alnum:]]+\z/,
                             message: "solo admite letras y números, sin espacios ni símbolos" },
                   length: { maximum: 8 }

  # En MAYÚSCULA, y no es cosmético: «a» y «A» son dos filas distintas para el
  # índice único, así que sin esto el mismo colegio puede crear la sección A dos
  # veces y descubrirlo cuando la matrícula quede partida.
  def name=(valor)
    super(valor.is_a?(String) ? valor.strip.upcase : valor)
  end

  # Los identificadores que este colegio YA usa, del más usado al menos.
  #
  # Daniel: «con el tiempo es probable que haga su universo de 4 o 5 valores
  # fijos. Además se siente para el usuario como que el sistema está
  # autoaprendiendo». Se ofrecen como sugerencia —`datalist`— y no como lista
  # cerrada: el colegio que abre una sección «D» por primera vez tiene que poder.
  #
  # ⚠️ Sin `del_anio_de_la_sesion`: el vocabulario es del COLEGIO, no del año.
  # Un año nuevo empieza sin secciones y ahí es justamente cuando más sirve.
  def self.identificadores_usados
    group(:name).order(Arel.sql("count(*) DESC"), :name).pluck(:name)
  end

  # Las secciones de una pantalla de «Documentos», y la que se va a emitir.
  #
  #     @secciones, @seccion = Section.con_la_pedida(@secciones, params[:section_id])
  #
  # ⚠️ La PEDIDA entra aunque el filtro de la sesión la deje afuera. Llega del
  # botón «Documentos oficiales» de una sección, y si es de otro año escolar,
  # caer en la primera de la lista sin decir nada es el filtro que aparece
  # puesto y no filtra (CLAUDE.md § 8.b): quien emite mira el papel que sale,
  # no el desplegable. La busca el `default_scope`, así que nunca es de otro
  # colegio.
  def self.con_la_pedida(lista, id)
    lista = lista.to_a
    return [ lista, lista.first ] if id.blank?

    pedida = lista.find { |seccion| seccion.id.to_s == id.to_s } ||
             includes(:grade, :academic_period).find_by(id: id)
    lista |= [ pedida ] if pedida
    [ lista, pedida || lista.first ]
  end
  validates :capacity, presence: true, numericality: { greater_than: 0 }

  # ⚠️ El cupo nace PROPUESTO, y no es cosmético: la columna es obligatoria y
  # el formulario de la sección lo esconde en «Guía, cupo y aula · opcional».
  # Sin propuesta, quien creaba una sección sin abrir ese panel recibía
  # «Capacidad no puede estar en blanco» de un campo que no veía. Y crearla desde la ficha
  # del grado —solo el identificador y el guía (Daniel, 13 de octubre de
  # 2026)— no tendría de dónde sacarlo. Treinta es el mismo piso que usa el
  # importador; se corrige cuando se ve la matrícula.
  CUPO_PROPUESTO = 30
  attribute :capacity, :integer, default: CUPO_PROPUESTO

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

  # Las materias que se dictan DE VERDAD en esta sección (MOR-211).
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

  private

  def el_turno_es_de_su_anio
    return if bell_schedule.nil? || bell_schedule.academic_period_id == academic_period_id

    errors.add(:bell_schedule, "es de otro año escolar")
  end
end
