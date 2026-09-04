# Qué evalúa una evaluación (MOR-136).
#
# El enganche entre el PLAN y la NOTA, y lo único que hace falta para que la
# boleta pueda decir «Resuelve situaciones con fracciones… PA».
#
#     evaluation_activity  ──etiquetada con──►  competency
#            │                                       │
#         su nota                            se muestra en la boleta
#            ▼                                  con ese nivel
#     activity_grades (1-20)  ──►  Rubric.para(nota)  ──►  «PA»
#
# ## ⚠️ Se etiqueta la COMPETENCIA, no el indicador
#
# El diagrama original apuntaba al indicador, y no funciona: **una competencia
# puede no tener ninguno** —la boleta real del Teresiano trae varias así— y
# entonces no habría manera de etiquetarla. Marcar indicadores en el formulario
# es azúcar de la pantalla; lo que se guarda es su competencia.
#
# Si algún día hace falta la precisión del indicador, se agrega y es aditivo.
class ActivityCompetency < ApplicationRecord
  include SchoolScoped

  belongs_to :competency
  belongs_to :evaluation_activity
  llega_al_anio_por evaluation_activity: :section
  llega_al_nivel_por evaluation_activity: { section: :grade }

  derives_school_from :evaluation_activity
  validates_same_school :competency

  validates :competency_id, uniqueness: { scope: :evaluation_activity_id }
  validate :la_competencia_es_del_mismo_plan

  private

  # ⚠️ Sin esto se etiqueta una prueba de Matemática de 5to A con una
  # competencia de Castellano de 6to B, y queda escrito.
  #
  # La fila cruzada no da error, no se ve en ninguna pantalla, y aparece meses
  # después en una boleta diciendo algo que nadie escribió ahí. Es el mismo
  # motivo por el que existe `ValidatesSameSchool`, un escalón más abajo: el
  # colegio ya coincide, lo que puede no coincidir es la sección, la materia o
  # el lapso.
  def la_competencia_es_del_mismo_plan
    return if competency.nil? || evaluation_activity.nil?

    del_mismo_plan = competency.section_id == evaluation_activity.section_id &&
                     competency.subject_id == evaluation_activity.subject_id &&
                     competency.evaluation_moment_id == evaluation_activity.evaluation_moment_id
    return if del_mismo_plan

    errors.add(:competency, "no es del plan de esta sección, materia y lapso")
  end
end
