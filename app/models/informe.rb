# El informe descriptivo del docente, por alumno y lapso (MOR-216).
#
# ## Qué dice, y por qué no lo dicen las notas
#
# La boleta dice **cuánto** sacó el niño. Un «PA» le cuenta a una madre en qué
# banda cayó su hijo; esto le cuenta que se distrae al final de la mañana y que
# lee mejor que en octubre.
#
# Cyndi, describiendo lo que su sistema actual ya hace: *«tiene una parte por
# donde uno coloca el informe descriptivo… el informe descriptivo de su
# rendimiento del lapso»*.
#
# ## ⚠️ UNO por alumno y lapso
#
# En singular, y el índice único es lo que lo sostiene: sin él, dos pestañas
# abiertas escriben dos informes y la boleta imprime el que salga primero.
#
# Que sea del LAPSO y no de la materia sale de la misma frase de Cyndi —«su
# rendimiento del lapso»— y de la boleta real del Teresiano, que trae uno solo
# al final. Si algún día hace falta por materia, es agregar `subject_id` a la
# clave: el resto del modelo aguanta.
#
# ## ⚠️ NO es el informe de Educación Inicial
#
# Suena igual y es otra cosa: ahí el informe **sustituye** a la calificación
# —no la acompaña— y se escribe por áreas de formación. Eso es `MOR-218`.
class Informe < ApplicationRecord
  include SchoolScoped

  belongs_to :enrollment
  belongs_to :evaluation_moment
  # Quién lo escribió. No es auditoría —para eso está `activity_logs`—: la
  # boleta puede querer firmarlo, y una sección cambia de guía a mitad de año.
  belongs_to :escrito_por, class_name: "User"

  llega_al_anio_por enrollment: :section
  llega_al_nivel_por enrollment: { section: :grade }
  derives_school_from :enrollment

  validates :cuerpo, presence: true
  validates :enrollment_id, uniqueness: { scope: :evaluation_moment_id,
                                          message: "ya tiene un informe en este lapso" }
  validate :el_lapso_pertenece_al_periodo_de_la_seccion

  # ⚠️ Recortado al guardar, y `presence` DESPUÉS de recortar. Un informe con
  # tres espacios adentro pasa `presence` y sale como un renglón en blanco en
  # la boleta que la familia se lleva.
  normalizes :cuerpo, with: ->(texto) { texto.to_s.strip }

  scope :del_lapso, ->(evaluation_moment_id) { where(evaluation_moment_id: evaluation_moment_id) }

  # El de este alumno en este lapso, o `nil`.
  def self.para(enrollment_id, evaluation_moment_id)
    find_by(enrollment_id: enrollment_id, evaluation_moment_id: evaluation_moment_id)
  end

  private

  # ⚠️ Un lapso de OTRO año escolar dejaría el informe colgando de una fecha que
  # no existe para ese alumno. Es la misma validación que llevan las
  # competencias y las evaluaciones.
  def el_lapso_pertenece_al_periodo_de_la_seccion
    return if enrollment.nil? || evaluation_moment.nil?
    return if evaluation_moment.academic_period_id == enrollment.section&.academic_period_id

    errors.add(:evaluation_moment, "no pertenece al año escolar de la sección")
  end
end
