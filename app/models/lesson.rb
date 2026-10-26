# Una clase: UNA casilla del horario —sección · área · día · hora— (spec
# `horarios`, § 9). Un bloque de 80 minutos son dos clases seguidas, que la
# rejilla dibuja unidas.
#
# ## ⚠️ Guarda tres datos que son de otras tablas, y no los mantiene ella
#
# El año, los minutos y el profesor se copian aquí al nacer porque las dos
# restricciones de la base solo miran su propia fila. Después los mantiene
# PostgreSQL con llaves compuestas: corregir la hora mueve los minutos, borrar
# la asignación deja la clase «sin profesor». La migración
# `las_clases_del_horario` cuenta cada una.
#
# ## El choque se rechaza en tres capas, con UN texto
#
#    1 · la pantalla   la casilla sale rayada y dice por qué
#    2 · el modelo     esta validación, con `ChoquesDeHorario`
#    3 · la base       dos `EXCLUDE`: aunque dos personas guarden a la vez
class Lesson < ApplicationRecord
  include SchoolScoped

  DIAS = BellSchedule::DIAS

  belongs_to :section
  belongs_to :subject
  belongs_to :time_slot
  belongs_to :academic_period
  belongs_to :teacher, optional: true
  llega_al_anio_por
  llega_al_nivel_por section: :grade
  derives_school_from :section
  validates_same_school :subject, :time_slot, :teacher

  validates :day, inclusion: { in: 1..DIAS.size }
  validate :la_hora_es_de_su_turno
  validate :sin_choques

  before_validation :copiar_lo_de_otras_tablas, on: :create

  def dia = DIAS[day - 1]
  def rango = HoraDelDia.rango(starts_min, ends_min)

  private

  # El profesor sale de quién dicta el área en la sección (decisión 7). Sin
  # asignación, la clase nace «sin profesor» y no choca con nadie.
  def copiar_lo_de_otras_tablas
    self.academic_period_id = section&.academic_period_id
    self.starts_min = time_slot&.starts_min
    self.ends_min = time_slot&.ends_min
    self.teacher_id = TeacherSection.where(section_id:, subject_id:).pick(:teacher_id)
  end

  def la_hora_es_de_su_turno
    return unless time_slot && section

    errors.add(:time_slot, "es el receso") if time_slot.receso?
    errors.add(:time_slot, "no es del turno de la sección") if time_slot.bell_schedule_id != section.bell_schedule_id
  end

  def sin_choques
    return if errors.any? || starts_min.nil?

    motivo = ChoquesDeHorario.motivo(seccion: section, dia: day, desde: starts_min, hasta: ends_min,
                                     profesor: teacher, salvo: id)
    errors.add(:base, ChoquesDeHorario.frase(dia: day, desde: starts_min, motivo:)) if motivo
  end
end
