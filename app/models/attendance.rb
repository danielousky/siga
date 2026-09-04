# La asistencia de un alumno en un día (MOR-111).
#
# El modelo es la parte fácil de este issue y hay que decirlo: **la pantalla es
# todo el trabajo**. Un profesor toma asistencia de pie, con treinta alumnos
# entrando, al empezar la clase. Si tarda más de un minuto, no se hace — y una
# asistencia que no se toma es peor que no tenerla, porque el colegio cree que
# la tiene.
class Attendance < ApplicationRecord
  include SchoolScoped

  derives_school_from :enrollment

  belongs_to :enrollment
  belongs_to :recorded_by,     class_name: "User", optional: true
  belongs_to :justificada_por, class_name: "User", optional: true
  llega_al_anio_por enrollment: :section
  llega_al_nivel_por enrollment: { section: :grade }
  has_one :student, through: :enrollment
  has_one :section, through: :enrollment

  # Los tres que el docente puede OBSERVAR parado en la puerta. "Justificada" no
  # está acá a propósito: cuando se toma la asistencia nadie sabe todavía si la
  # falta lo estaba — el justificativo llega al día siguiente, y casi siempre lo
  # recibe otra persona. Es un momento distinto del proceso, así que es un campo
  # distinto (`justificacion`), no un cuarto estado.
  enum :status, { presente: 0, ausente: 1, tarde: 2 }

  ETIQUETAS = { "presente" => "Presente", "ausente" => "Ausente", "tarde" => "Tarde" }.freeze

  validates :date, presence: true
  validates :enrollment_id, uniqueness: { scope: :date, message: "ya tiene asistencia ese día" }
  validate  :no_es_del_futuro

  scope :del_dia,   ->(dia)  { where(date: dia) }
  scope :faltas,    -> { where(status: [:ausente, :tarde]) }
  scope :sin_justificar, -> { where(status: :ausente, justificada_en: nil) }

  # Una falta cuenta como tal hasta que alguien traiga el papel.
  def justificada? = justificada_en.present?

  def cuenta_como_inasistencia? = ausente? && !justificada?

  def etiqueta = ETIQUETAS.fetch(status, status)

  private

  # Marcar asistencia de mañana no es un error de dedo inofensivo: deja el día
  # cerrado antes de que ocurra, y el docente que llegue mañana va a ver la
  # sección "ya tomada" y seguir de largo.
  def no_es_del_futuro
    return if date.blank? || date <= Date.current

    errors.add(:date, "no se puede tomar asistencia de un día que no llegó")
  end
end
