class ActivityGrade < ApplicationRecord
  include SchoolScoped

  # ⚠️ Cerrado el lapso, esta nota no se toca — ni se cambia ni se borra.
  # Daniel: *«al dar el visto bueno… el profe ya no puede modificar las notas»*.
  include SeCierraConElLapso
  se_cierra_con_el_lapso :evaluation_activity

  belongs_to :evaluation_activity
  belongs_to :student, foreign_key: :student_id
  llega_al_anio_por evaluation_activity: :section
  llega_al_nivel_por evaluation_activity: { section: :grade }
  derives_school_from :evaluation_activity
  validates_same_school :student

  # Art. 108 del Reglamento General de la LOE: "escala del uno (1) al veinte (20),
  # ambos inclusive". No arranca en cero — al que no se presenta se le pone 01.
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }
  validates :student_id, uniqueness: { scope: :evaluation_activity_id }

  # El cable que faltaba (MOR-96).
  #
  # `GradeCalculator` estaba escrito, funcionaba, y no lo llamaba nadie:
  # `moment_grades` y `final_grade_books` existían como tablas y nunca se
  # llenaban solas.
  #
  # Va EN LÍNEA y no en un job, contra lo que sugería el issue, porque se midió:
  # recalcular el lapso y el anual de UN alumno en UNA materia son ~10 ms y una
  # treintena de consultas chicas. Los "30 recálculos" de una carga completa no
  # ocurren en una petición sino en TREINTA — la planilla guarda nota por nota.
  # Nadie paga 30 veces 10 ms de una sola vez.
  #
  # Y a cambio el promedio nunca queda viejo. Con un job y sin cola de verdad en
  # producción (hoy el adaptador es :async, que pierde lo encolado al reiniciar),
  # una nota guardada justo antes de un despliegue se quedaría sin recalcular y
  # nadie se enteraría. Sobre la nota oficial de un alumno, eso no se negocia.
  #
  # El recálculo masivo —cambiar la ponderación afecta a la sección entera, ~1 s—
  # sí va por job: ver `RecalcularSeccionJob`.
  after_save    :recalcular_promedios
  after_destroy :recalcular_promedios

  private

  def recalcular_promedios
    inscripcion = Enrollment.find_by(
      student_id: student_id, section_id: evaluation_activity.section_id
    )
    return if inscripcion.nil?

    GradeCalculator.calculate_moment_grade(
      enrollment: inscripcion,
      subject: evaluation_activity.subject,
      evaluation_moment: evaluation_activity.evaluation_moment
    )
    GradeCalculator.calculate_final_grade(
      enrollment: inscripcion,
      subject: evaluation_activity.subject
    )
  end
end
