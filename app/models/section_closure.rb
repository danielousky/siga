# El visto bueno de Control de Estudio sobre un lapso de una sección.
#
# Daniel: *«CE mira las boletas y da por "cerrado" el proceso de carga y
# completación de la calificación. Al dar el visto bueno se envía el correo al
# representante y ya puede entrar a ver sus notas, y a su vez el profe ya no
# puede modificar las notas»*.
#
#     POR CALIFICAR ──► CALIFICADA ──► CERRADA
#      falta una nota   están todas    alguien miró y firmó
#           ▲                 ▲              ▲
#      se DEDUCE        se DEDUCE       esta tabla
#
# ⚠️ Es el ÚNICO de los tres que se guarda, y por eso existe: los otros dos los
# contestan las notas. Lo que ningún dato puede contestar es si una persona miró
# y dio el visto bueno — eso es un hecho nuevo, con su autor y su fecha.
class SectionClosure < ApplicationRecord
  include SchoolScoped
  derives_school_from :section
  llega_al_anio_por :section
  llega_al_nivel_por section: :grade

  belongs_to :section
  belongs_to :evaluation_moment
  belongs_to :cerrado_por, class_name: "User"

  validates_same_school :evaluation_moment
  validates :cerrado_el, presence: true
  validates :evaluation_moment_id, uniqueness: { scope: :section_id }

  # ⚠️ El lapso tiene que ser del AÑO ESCOLAR de la sección.
  #
  # Es la misma validación que ya tienen `EvaluationActivity` y `Competency`, y
  # por la misma razón: un cierre colgado del lapso de otro año no lo ve nadie,
  # no cierra nada, y el profesor sigue pudiendo cargar notas sin que se
  # entienda por qué.
  validate :el_lapso_es_del_ano_de_la_seccion

  # ¿Está cerrado este par (sección, lapso)?
  #
  # ⚠️ Se pregunta por los IDS y no por los objetos: quien lo llama casi siempre
  # tiene los ids a mano —una nota sabe de qué actividad es— y cargar la sección
  # entera para preguntar una existencia son dos consultas en vez de una.
  def self.cerrado?(section_id:, evaluation_moment_id:)
    return false if section_id.blank? || evaluation_moment_id.blank?

    exists?(section_id: section_id, evaluation_moment_id: evaluation_moment_id)
  end

  private

  def el_lapso_es_del_ano_de_la_seccion
    return if section.nil? || evaluation_moment.nil?
    return if evaluation_moment.academic_period_id == section.academic_period_id

    errors.add(:evaluation_moment, "es de otro año escolar que el de la sección")
  end
end
