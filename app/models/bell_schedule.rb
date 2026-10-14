# Un TURNO: a qué hora suena el timbre de las secciones que lo usan.
#
#     Media · mañana     1ra 7:10–7:50 · 2da 7:50–8:30 · … · Receso 9:50–10:20 · … · 8va 12:20–1:00
#
# Se llama `BellSchedule` y se lee «Turno» (`MOR-162`: inglés donde Rails deduce
# un nombre de otro, español en lo que se lee). «Turno» es la palabra de la
# Resolución DM-029/2022 y la del colegio. Spec: `docs/specs/horarios.md`.
#
# ## Por qué existe, si casi todos los colegios tienen uno solo
#
# Porque el choque de un profesor se mide por RELOJ. Primaria y Media no
# comparten timbre, y un profesor que dicta en las dos puede tener «la 3ra
# hora» en una y «la 2da» en la otra a la misma hora de la mañana. Sin el
# turno —con sus horas de verdad— ese choque no se puede ni preguntar.
#
# ## ⚠️ Es del AÑO ESCOLAR
#
# Como las secciones y los lapsos: el timbre de este año puede no ser el del que
# viene, y el horario de un año cerrado tiene que seguir diciendo a qué hora fue.
class BellSchedule < ApplicationRecord
  include SchoolScoped

  # Lunes a viernes (decisión 15 del spec). El día de una clase es su posición
  # en esta lista, contando desde 1: el lunes es 1 y el viernes 5.
  DIAS = %w[Lunes Martes Miércoles Jueves Viernes].freeze

  belongs_to :academic_period
  llega_al_anio_por
  derives_school_from :academic_period

  has_many :time_slots, -> { order(:starts_min) }, dependent: :destroy, inverse_of: :bell_schedule
  # ⚠️ Un turno con secciones no se borra: se quedarían sin timbre, y en cuanto
  # tengan horario, sin dónde colgar sus clases. Primero se les cambia el turno.
  has_many :sections, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :academic_period_id }

  # «Media · mañana » y «Media · mañana» son el mismo turno.
  def name=(valor)
    super(valor.is_a?(String) ? valor.squish : valor)
  end

  # Las horas en que se dicta clase, sin los recesos, en orden.
  def horas_de_clase = time_slots.select(&:clase?)

  # Cuántas horas de clase caben en una semana: es contra lo que se compara la
  # carga horaria de un grado.
  def horas_a_la_semana = horas_de_clase.size * DIAS.size

  def entrada = time_slots.map(&:starts_min).min
  def salida  = time_slots.map(&:ends_min).max

  # Cada hora con el nombre con que se la llama: «1ra hora», «2da hora»…,
  # «Receso». El número no se guarda: sale de contar las horas de clase en
  # orden, así que borrar la 2da convierte a la 3ra en la 2da sin tocar nada.
  def horas_con_nombre
    numero = 0

    time_slots.map do |hora|
      nombre = hora.receso? ? "Receso" : "#{TimeSlot::ORDINALES.fetch(numero, "#{numero + 1}.ª")} hora"
      numero += 1 if hora.clase?

      [ hora, nombre ]
    end
  end

  def nombre_de(hora) = horas_con_nombre.find { |otra, _| otra == hora }&.last
end
