# El porqué de una casilla que no se puede usar, escrito en UN solo sitio
# (spec `horarios`, decisión 23). Lo leen el modelo, el rescate de la base
# —cuando dos guardan a la vez y salta el `EXCLUDE`— y la rejilla.
#
#     ChoquesDeHorario.motivo(seccion:, dia: 3, desde: 510, hasta: 550, profesor:)
#     # => "López está en 2do Año A dando Inglés"
#     ChoquesDeHorario.frase(dia: 3, desde: 510, motivo:)
#     # => "Miércoles a las 8:30 no se puede: López está en 2do Año A dando Inglés."
#
# ⚠️ El choque se mide por RELOJ, no por número de hora (decisión 6): la 3ra
# hora de Primaria y la 2da de Media pueden pisarse, y un profesor dicta en las
# dos. Dos horas contiguas no chocan: el rango es [desde, hasta).
module ChoquesDeHorario
  module_function

  def motivo(seccion:, dia:, desde:, hasta:, profesor:, salvo: nil)
    pisan = ->(clases) { clases.where(day: dia).where("starts_min < ? AND ends_min > ?", hasta, desde).where.not(id: salvo) }

    if (otra = pisan.(Lesson.where(section_id: seccion.id)).includes(:subject).first)
      return "#{nombre_de(seccion)} ya tiene #{otra.subject.name} a esa hora"
    end
    return unless profesor

    otra = pisan.(Lesson.where(teacher_id: profesor.id, academic_period_id: seccion.academic_period_id))
           .includes(:subject, section: :grade).first
    "#{apellido_de(profesor)} está en #{nombre_de(otra.section)} dando #{otra.subject.name}" if otra
  end

  def frase(dia:, desde:, motivo:)
    "#{Lesson::DIAS[dia - 1]} a las #{HoraDelDia.texto(desde)} no se puede: #{motivo}."
  end

  def nombre_de(seccion) = "#{seccion.grade.name} #{seccion.name}"

  # El PRIMER apellido, en Tipo Título: es como se nombra a un profesor en un
  # colegio («la profesora López»), y en la base vive en mayúscula.
  def apellido_de(profesor) = Normaliza.titulo(profesor.user.last_name)
end
