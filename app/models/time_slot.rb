# Una HORA del timbre de un turno: de cuándo a cuándo, y si es de clase o receso.
#
# Se llama `TimeSlot` y se lee «hora» —«la 1ra hora», «el receso»—.
#
# ## ⚠️ En minutos desde la medianoche
#
# `starts_min = 430` son las 7:10. El porqué está en `HoraDelDia` y en la
# migración: sin zona horaria que convertir, y con rangos que PostgreSQL sabe
# preguntar si se pisan.
#
# ## ⚠️ Dos horas de un turno no se pisan, y lo dice la BASE
#
# La validación de acá existe para explicarlo con palabras —«se pisa con la 2da
# hora»—; quien lo impide es la restricción `time_slots_no_se_pisan`. Dos
# personas corrigiendo el timbre a la vez pasan las dos la validación.
#
# ## ⚠️ Una hora es una hora académica
#
# No hay horas «que valen dos»: el bloque de 80 minutos de la Resolución
# DM-029/2022 son dos horas de 40 seguidas, y así las escribe un colegio —
# `7:10–7:50` y `7:50–8:30` en la misma casilla—. Con horas de distinto valor
# habría dos maneras de contar la carga de un área.
class TimeSlot < ApplicationRecord
  include SchoolScoped

  # Femeninas, porque es «la primera hora». Hasta catorce, que es el tope del
  # generador: un turno de más horas que eso no es un turno.
  ORDINALES = %w[1ra 2da 3ra 4ta 5ta 6ta 7ma 8va 9na 10ma 11ma 12ma 13ra 14ta].freeze

  belongs_to :bell_schedule, inverse_of: :time_slots
  # Una hora con clases no se borra: el aviso dice cuántas tiene.
  has_many :lessons, dependent: :restrict_with_error
  derives_school_from :bell_schedule

  enum :kind, { clase: 0, receso: 1 }

  validates :starts_min, presence: { message: "no se entiende: escríbala como 7:10" }
  validates :ends_min, presence: { message: "no se entiende: escríbala como 7:50" }
  validate :termina_despues_de_empezar
  validate :no_se_pisa_con_otra

  # Lo que escribe y lee el formulario: «07:10», el formato de un campo de hora.
  def desde = HoraDelDia.del_campo(starts_min)
  def hasta = HoraDelDia.del_campo(ends_min)

  def desde=(texto)
    self.starts_min = HoraDelDia.a_minutos(texto)
  end

  def hasta=(texto)
    self.ends_min = HoraDelDia.a_minutos(texto)
  end

  def rango = HoraDelDia.rango(starts_min, ends_min)
  def minutos = ends_min - starts_min

  private

  def termina_despues_de_empezar
    return if starts_min.nil? || ends_min.nil? || starts_min < ends_min

    errors.add(:ends_min, "tiene que ser después de la hora en que empieza")
  end

  def no_se_pisa_con_otra
    return if starts_min.nil? || ends_min.nil? || bell_schedule.nil?

    otra = bell_schedule.time_slots.where.not(id: id)
                        .where("starts_min < ? AND ends_min > ?", ends_min, starts_min)
                        .first
    return unless otra

    errors.add(:base, "Se pisa con #{articulo_de(otra)} #{bell_schedule.nombre_de(otra).downcase} (#{otra.rango})")
  end

  def articulo_de(hora) = hora.receso? ? "el" : "la"
end
