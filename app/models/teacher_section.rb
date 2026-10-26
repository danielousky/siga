class TeacherSection < ApplicationRecord
  include SchoolScoped

  belongs_to :teacher
  belongs_to :section
  belongs_to :subject
  llega_al_anio_por :section
  llega_al_nivel_por section: :grade
  derives_school_from :section
  validates_same_school :teacher, :subject

  validates :subject_id, uniqueness: { scope: :section_id, message: "ya está asignada en esta sección" }

  # Al nacer, el profesor toma las clases de su área en la sección que quedaron
  # «sin profesor» —la base las deja así al borrar la asignación anterior—
  # (spec `horarios`, decisión 8). Donde ya dicta en otra sección a esa hora,
  # la clase vuelve a «por ubicar»: la asignación se guarda SIEMPRE, porque
  # quién dicta es un hecho y el horario es un plan.
  after_create :llevar_al_horario

  # Las que no pudo tomar, con su porqué, para que la pantalla lo diga:
  # «miércoles 8:30 — Pérez está en 3er Año A dando Matemática».
  def clases_desubicadas = @clases_desubicadas || []

  private

  def llevar_al_horario
    @clases_desubicadas = []
    Lesson.where(section_id:, subject_id:, teacher_id: nil).order(:day, :starts_min).each do |clase|
      motivo = ChoquesDeHorario.motivo(seccion: section, dia: clase.day, desde: clase.starts_min,
                                       hasta: clase.ends_min, profesor: teacher, salvo: clase.id)
      next if motivo.nil? && tomar(clase)

      motivo ||= "#{ChoquesDeHorario.apellido_de(teacher)} acaba de recibir otra clase a esa hora"
      @clases_desubicadas << "#{clase.dia.downcase} #{HoraDelDia.texto(clase.starts_min)} — #{motivo}"
      clase.destroy!
    end
  end

  # En su SAVEPOINT: si alguien le llenó esa hora al profesor un instante
  # antes, la base lo rechaza y la clase vuelve a «por ubicar», en vez de
  # tumbar la asignación con la transacción entera.
  def tomar(clase)
    Lesson.transaction(requires_new: true) { clase.update_columns(teacher_id:) }
    true
  rescue ActiveRecord::ExclusionViolation
    false
  end
end
