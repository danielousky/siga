# Cuándo se puede borrar algo, de verdad (MOR-135).
#
# ## El botón que fallaba 200 de 200 veces
#
# Cada listado traía un "Eliminar" al lado de cada fila. En el de alumnos,
# **ninguno de los 200 funcionaba**: `Student has_many :enrollments, dependent:
# :restrict_with_error`, y un alumno sin ninguna inscripción no existe en un
# colegio real. La secretaria tocaba Eliminar, confirmaba el "¿Está seguro?", y
# recibía un mensaje de error. Cada vez.
#
# Y es lo correcto que falle: **borrar a un alumno borraría sus notas**, que son
# su historia académica. Lo que estaba mal era ofrecerlo.
#
#     lo que hacía el sistema          lo que el colegio quiere
#     ───────────────────────          ────────────────────────
#     Eliminar → ✗ error               Retirar / egresar
#     (borra notas e historia)         (la historia se queda)
#
# ## Qué hace este helper
#
# Pregunta si las asociaciones que bloquean el borrado están vacías, para
# ofrecer el botón solo cuando va a funcionar. Es genérico a propósito: lee las
# `dependent: :restrict_with_error` del modelo en vez de repetir la lista a
# mano, así que un modelo nuevo queda cubierto sin tocar esto.
#
# Se usa en la pantalla de EDICIÓN, no en el listado, por dos motivos: en un
# listado son N consultas por N filas, y un botón destructivo al lado de cada
# renglón es un clic errado esperando su turno.
module BorradoHelper
  def borrable?(registro)
    bloqueos_de(registro).none? { |asociacion| tiene_algo?(registro, asociacion) }
  end

  # Para explicar POR QUÉ no se puede, que es lo que la persona necesita saber
  # para hacer lo correcto en su lugar.
  def motivo_para_no_borrar(registro)
    con_datos = bloqueos_de(registro).select { |a| tiene_algo?(registro, a) }
    return nil if con_datos.empty?

    nombres = con_datos.map { |a| etiqueta_de(a.name) }
    "Tiene #{nombres.to_sentence} en el sistema. Borrarlo perdería esa información."
  end

  ETIQUETAS_DE_ASOCIACION = {
    enrollments:          "inscripciones",
    activity_grades:      "calificaciones",
    moment_grades:        "notas de lapso",
    final_grade_books:    "notas definitivas",
    teacher_sections:     "secciones asignadas",
    evaluation_activities: "evaluaciones",
    sections:             "secciones",
    subjects:             "áreas de aprendizaje",
    led_sections:         "secciones que guía",
    coordinated_grades:   "grados que coordina",
    evaluation_moments:   "lapsos"
  }.freeze

  private

  def bloqueos_de(registro)
    registro.class.reflect_on_all_associations
            .select { |a| a.options[:dependent] == :restrict_with_error }
  end

  # `has_many` responde `exists?`; `has_one` y `belongs_to`, no. La diferencia
  # importa: llamar `exists?` sobre un `has_one` levanta NoMethodError, y este
  # helper corre en la vista, o sea que la pantalla entera se cae.
  def tiene_algo?(registro, asociacion)
    valor = registro.public_send(asociacion.name)
    valor.respond_to?(:exists?) ? valor.exists? : valor.present?
  end

  def etiqueta_de(nombre)
    ETIQUETAS_DE_ASOCIACION[nombre] || nombre.to_s.humanize.downcase
  end
end
