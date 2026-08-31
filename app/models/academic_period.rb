class AcademicPeriod < ApplicationRecord
  include SchoolScoped

  belongs_to :school

  has_many :sections, dependent: :restrict_with_error
  has_many :evaluation_moments, dependent: :restrict_with_error

  validates :name, :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  # ══════════════════════════════════════════════════════════════════════════
  # El año escolar venezolano se DEDUCE de un número (MOR-163)
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Va de mediados de septiembre a finales de julio. **Todos.** Daniel: «eso es
  # así cada año, no hace falta preguntar; ni en los peores años algo diferente».
  #
  # Así que crear un año escolar no son tres campos —nombre, fecha de inicio y
  # fecha de fin— sino UNO: qué año empieza. De ahí salen los otros tres.
  #
  # ⚠️ Antes esto vivía escondido en `ImportacionesController#rango_del_ano`, y
  # el formulario del director pedía las tres cosas a mano. O sea: el sistema ya
  # sabía la respuesta y de todos modos preguntaba — y aceptaba «Año escolar
  # 2026-2027» con las fechas en blanco, que es un año sin duración.

  # El primer día de clases. El 15 y no el 1: septiembre arranca a mitad de mes
  # en Venezuela, y esa es la fecha que un colegio reconoce.
  COMIENZA = { mes: 9, dia: 15 }.freeze
  TERMINA  = { mes: 7, dia: 31 }.freeze

  # Los años que tiene sentido ofrecer. Hacia atrás alcanzan el historial que un
  # colegio quiera importar; hacia adelante, el que está por planificar.
  def self.anios_elegibles(desde_hoy = Date.current)
    base = desde_hoy.year
    ((base - 12)..(base + 1)).to_a.reverse
  end

  # «2026» → «2026-2027». El nombre no se escribe: se arma.
  def self.nombre_del_anio(inicio) = "#{inicio}-#{inicio.to_i + 1}"

  # El año que le toca crear a este colegio.
  #
  # Si ya tiene 2025-2026, el siguiente es 2026 — «exacto», dijo Daniel. Si no
  # tiene ninguno, es el año escolar en curso: de enero a julio todavía se está
  # cursando el que empezó el septiembre anterior.
  def self.proximo_anio(hoy = Date.current)
    ultimo = order(:start_date).last
    return ultimo.start_date.year + 1 if ultimo

    hoy.month >= COMIENZA[:mes] ? hoy.year : hoy.year - 1
  end

  # Construye el año escolar completo a partir del número. Es el único camino:
  # el formulario, el importador y los seeds pasan por acá, así que las fechas
  # no pueden diferir según por dónde se creó.
  def self.para_el_anio(inicio, school: Current.school)
    inicio = inicio.to_i

    new(school: school, name: nombre_del_anio(inicio),
        start_date: Date.new(inicio, COMIENZA[:mes], COMIENZA[:dia]),
        end_date: Date.new(inicio + 1, TERMINA[:mes], TERMINA[:dia]))
  end

  # El año que empieza, leído del nombre.
  #
  # ⚠️ El primer grupo de cuatro dígitos, esté donde esté: una planilla trae
  # «2023-2024» pero un colegio escribe «Año escolar 2023-2024», y anclando al
  # principio de la cadena el segundo no se reconoce. El rango es el que filtra
  # la basura.
  def self.anio_de(nombre)
    inicio = nombre.to_s[/(\d{4})/, 1]&.to_i
    inicio if inicio&.between?(1950, 2100)
  end

  scope :en_curso, -> { where(start_date: ..Date.current, end_date: Date.current..) }
  scope :por_comenzar, -> { where(start_date: Date.current...).order(:start_date) }

  # El año escolar que el colegio está viviendo hoy.
  #
  # No hay bandera de "activo" y es a propósito: el año escolar lo definen sus
  # fechas, y una bandera se queda vieja el día que nadie se acuerda de moverla
  # — justo el día que la pantalla la muestra.
  #
  # Entre julio y septiembre **no hay ninguno en curso**, y ahí lo que le importa
  # al colegio es el que viene, que es el que está preparando. Por eso el orden
  # es: el de hoy, el próximo, y si no, el último que hubo.
  def self.vigente
    en_curso.first || por_comenzar.first || order(start_date: :desc).first
  end

  # ⚠️ El año escolar que TIENE ALUMNOS ADENTRO, que no es `vigente`.
  #
  # La diferencia aparece cada agosto y ya mordió tres veces. Entre julio y
  # septiembre `vigente` devuelve el año que EMPIEZA —lo correcto para la barra
  # de contexto: es el que el colegio está preparando— pero ese año todavía no
  # tiene ni una inscripción ni una evaluación.
  #
  # Quien pregunta «¿cuántos alumnos hay?», «¿qué secciones están sin profesor?»
  # o «¿quién no cargó notas?» necesita el año donde hay clases, no el que viene.
  # Preguntarle a `vigente` da CERO en agosto, y cero se lee como «todo al día».
  #
  # Estaba escrito a mano en el panel del director; al necesitarlo el segundo
  # lugar se subió acá. La tercera copia habría dado dos respuestas distintas a
  # la misma pregunta en la misma pantalla — que es justo lo que pasó.
  def self.en_operacion
    where(id: Section.joins(:enrollments).select(:academic_period_id))
      .order(:start_date).last
  end

  # Cómo se para el período frente a hoy. Se devuelve el símbolo y no el texto
  # para que la vista decida cómo escribirlo — y para que no haya que mirar una
  # cadena en castellano para saber si el año está corriendo.
  def situacion
    return :por_comenzar if start_date > Date.current
    return :finalizado   if end_date < Date.current

    :en_curso
  end

  private

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be after start date") if end_date <= start_date
  end
end
