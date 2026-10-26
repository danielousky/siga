# Cuántas horas a la semana va cada área de una sección, y cuántas ya están
# ubicadas (spec `horarios`, decisión 21). Es lo que dice «Por ubicar»:
# «Inglés · López · 2 de 4».
#
# ## ⚠️ La propuesta del plan oficial se MUESTRA, no se guarda
#
# Si el colegio no escribió la carga de un área, vale la del plan de 2017 —si
# la reconoce por su nombre (`CargaHorariaOficial`)—. Se ve igual que una
# escrita, y se vuelve del colegio la primera vez que la toca con − o +. Así
# nunca se pisa lo que el colegio decidió, y mirar no escribe nada.
class CargaDeLaSeccion
  Area = Data.define(:grade_subject, :materia, :profesor, :horas, :propuesta, :ubicadas) do
    def sin_horas? = horas.nil?
    def completa? = !sin_horas? && ubicadas >= horas
    def faltan = sin_horas? ? 0 : [ horas - ubicadas, 0 ].max
  end

  attr_reader :seccion

  def initialize(seccion)
    @seccion = seccion
  end

  def areas
    @areas ||= begin
      grado = seccion.grade
      profesores = TeacherSection.where(section: seccion).includes(teacher: :user).index_by(&:subject_id)
      ubicadas = seccion.persisted? ? Lesson.where(section: seccion).group(:subject_id).count : {}

      GradeSubject.where(grade: grado).includes(:subject).sort_by { |gs| gs.subject.name }.map do |gs|
        oficial = gs.weekly_hours.nil? ? CargaHorariaOficial.horas_para(gs.subject.name, grado.name) : nil
        Area.new(grade_subject: gs, materia: gs.subject, profesor: profesores[gs.subject_id]&.teacher,
                 horas: gs.weekly_hours || oficial, propuesta: !oficial.nil?,
                 ubicadas: ubicadas.fetch(gs.subject_id, 0))
      end
    end
  end

  def de(materia) = areas.find { |area| area.materia.id == (materia.respond_to?(:id) ? materia.id : materia.to_i) }

  def total = areas.sum { |area| area.horas.to_i }
  def ubicadas = areas.sum(&:ubicadas)
  def faltan = areas.sum(&:faltan)
  def primera_pendiente = areas.find { |area| !area.sin_horas? && !area.completa? }
end
