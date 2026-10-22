# Lo que comparten las pantallas de «Horarios» (spec `horarios`).
module HorariosHelper
  # Los parámetros que una pantalla de horarios conserva al moverse dentro de
  # sí misma. «porque» y «hora» NO están: dicen lo que se acaba de tocar, y
  # arrastrarlos repetiría el mensaje en cada clic.
  PARAMETROS_DEL_HORARIO = %i[ver vista seccion armar area dia profesor alumno q].freeze

  # Cada área con su tono (decisión 22): el NOMBRE manda y el color acompaña.
  # Fríos y apagados a propósito: verde, rojo y ámbar son del dato (`MOR-135`),
  # y un área en rojo se leería como un aplazado.
  COLORES_DE_AREA = %w[
    #1F5C8B #6B4E71 #2F6B6B #7A5230 #3E5C76 #8A4F6E #5B4B8A #4A5578
    #12596E #7A6A3A #2E4F8F #6E5A8C #3D6470 #6B5F4E #4F6F86 #4D6B3C
  ].freeze

  # «Ver el horario por»: la misma tabla de clases, por cuatro puertas.
  def pestanas_de_horarios(activa:)
    [ [ "Secciones", "secciones" ], [ "Profesores", "profesores" ], [ "Áreas", "areas" ], [ "Alumnos", "alumnos" ] ]
      .map { |texto, ver| [ texto, horarios_path(ver: (ver unless ver == "secciones")), activa == ver ] }
  end

  # Esta misma pantalla, con algo cambiado: `ruta_del_horario(seccion: 4)`.
  def ruta_del_horario(**cambios)
    actuales = params.permit(*PARAMETROS_DEL_HORARIO).to_h.symbolize_keys
    horarios_path(actuales.merge(cambios).compact_blank)
  end

  def color_del_area(materia)
    @colores_de_area ||= Subject.order(:name).pluck(:id).each_with_index
                                .to_h { |id, i| [ id, COLORES_DE_AREA[i % COLORES_DE_AREA.size] ] }
    @colores_de_area.fetch(materia.id, COLORES_DE_AREA.first)
  end

  def nombre_de_la_seccion(seccion) = "#{seccion.grade.name} #{seccion.name}"

  # «1er A»: cabe en una casilla.
  def corto_de_la_seccion(seccion) = "#{seccion.grade.name.split.first} #{seccion.name}"

  def apellido_del_profesor(profesor) = ChoquesDeHorario.apellido_de(profesor)

  # «Turno de la mañana, de 7:10 a. m. a 1:00 p. m.»
  def resumen_corto_del_turno(turno)
    return turno.name if turno.time_slots.empty?

    "#{turno.name}, de #{HoraDelDia.con_meridiano(turno.entrada)} a #{HoraDelDia.con_meridiano(turno.salida)}"
  end

  # Lo que pregunta «Publicar» antes de publicar: quién lo va a ver, y qué falta.
  def confirmacion_de_publicar(seccion, carga)
    texto = "¿Publicar el horario de #{nombre_de_la_seccion(seccion)}? Lo verán sus profesores, sus alumnos y las familias."
    texto += " Faltan #{carga.faltan} horas por ubicar: esas casillas saldrán vacías." if carga.faltan.positive?
    texto
  end

  # «A y B»: las secciones de un grado en el año.
  def letras_del_grado(seccion)
    Section.where(grade_id: seccion.grade_id, academic_period_id: seccion.academic_period_id)
           .pluck(:name).sort.to_sentence
  end
end
