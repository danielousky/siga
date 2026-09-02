class Subject < ApplicationRecord
  include SchoolScoped

  # ⚠️ El departamento es OPCIONAL, y el plan de arranque ya lo decía.
  #
  # `PasosDeArranque#departamentos` está marcado `opcional: true` desde MOR-154,
  # con el comentario «un colegio de 150 alumnos no tiene departamentos». El
  # modelo decía lo contrario, y el resultado lo encontró Daniel en el QA: un
  # colegio nuevo entra al paso 3 —las materias—, guarda, y recibe «Departamento
  # debe existir». Para seguir tenía que irse al paso 8, que la app le acababa de
  # presentar como omitible. La puesta en marcha se trababa en el tercer paso.
  #
  # Agrupar materias por área es una necesidad de un colegio de 800 alumnos, y
  # ese ya sabe pedirla. El promedio del mercado es 360.
  belongs_to :department, optional: true

  # Sin departamento no hay de dónde derivar el colegio, así que cae en la
  # sesión. La columna sigue siendo `NOT NULL`: una materia sin colegio no la ve
  # nadie, porque es por ahí que filtra el RLS.
  derives_school_from :department, or_from_session: true

  has_many :grade_subjects, dependent: :destroy
  has_many :grades, through: :grade_subjects
  has_many :evaluation_activities, dependent: :restrict_with_error
  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error
  has_many :teacher_sections, dependent: :restrict_with_error

  # El código es la nomenclatura interna del colegio: único dentro de él, no en
  # toda la plataforma. Un colegio que viene de otro sistema trae sus códigos ya
  # impresos en carnets y planillas.
  # ⚠️ El código es un CÓDIGO: alfanumérico y en mayúscula (MOR-185).
  #
  # Daniel: «el código solo debe aceptar alfanuméricos, nada de caracteres
  # especiales; es un código, no un nombre ni nada de eso».
  #
  # Y sale impreso: en el boletín, en la certificación 31059 y en las planillas
  # que el colegio exporta. Un «MAT-1 » con espacio al final es otro código
  # distinto para el índice único, y el colegio termina con dos Matemáticas.
  validates :code, presence: true,
                   uniqueness: { scope: :school_id },
                   format: { with: /\A[A-Za-z0-9]+\z/,
                             message: "solo admite letras y números, sin espacios ni símbolos" },
                   length: { maximum: 12 }
  validates :name, presence: true

  # Las dos normalizaciones, en el MISMO lugar que las de una persona
  # (`User#normalizar_el_nombre`): lo que llega del formulario y lo que llega de
  # una planilla importada tienen que quedar igual, o el listado sale desparejo.
  #
  # `Normaliza.mayuscula` es la misma que usa el nombre de una persona: recorta,
  # junta espacios dobles y sube a mayúscula.
  before_validation :normalizar

  # ⚠️ Se GUARDA en mayúscula y se MUESTRA en Tipo Título (MOR-188).
  #
  # Es la misma regla que el nombre de una persona, y por la misma razón: la
  # mayúscula es la forma canónica —así vienen las planillas del MPPE y así
  # compara el índice único— pero «MATEMÁTICA» en la pantalla de una madre grita.
  #
  # Daniel, fijando la regla: *«Tipo Título en pantalla y docs, mayúscula en la
  # base. Lo que quiero es evitar que se vuelva un arrozConMango y terminen unas
  # en minúsculas, otras Mayúsculas y otras títulos. Creéme, pasa»*.
  #
  # ⚠️ Va en el GETTER y no en cuarenta y ocho vistas.
  #
  # Contar los sitios donde se muestra el nombre de una materia da 48: listados,
  # planillas, el boletín, la certificación 31059, el panel del profesor, el del
  # alumno. Editarlos uno por uno es precisamente cómo se produce el arroz con
  # mango — basta olvidar dos y ya hay tres estilos conviviendo.
  #
  # Acá, el que consulte `subject.name` recibe la forma de leer. Quien necesite
  # la canónica —comparar, normalizar, indexar— pide `name_canonico`.
  def name
    Normaliza.titulo(super)
  end

  # El valor tal como vive en la base: MAYÚSCULA. Lo usa la normalización y
  # cualquier comparación que tenga que coincidir con el índice único.
  def name_canonico = self[:name]

  private

  def normalizar
    # ⚠️ ASCII, no `[[:alnum:]]` (MOR-201). En Ruby esa clase incluye la Ñ y las
    # vocales acentuadas, así que «ÑPPD01» pasaba como código válido. Un código se
    # compara y se imprime en una planilla del MPPE: si admite acentos, dos
    # códigos que se leen igual son distintos para el índice único.
    self.code = code.to_s.gsub(/[^A-Za-z0-9]/, "").upcase.presence
    # ⚠️ `self[:name]` y no `name`: el getter ya devuelve Tipo Título, y pasarle
    # eso a `mayuscula` funcionaría de casualidad. Lo que se normaliza es lo que
    # llegó del formulario, no lo que el getter decide mostrar.
    self[:name] = Normaliza.mayuscula(self[:name])
  end

  public

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
