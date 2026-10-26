# Lo que comparten las pantallas de «Horarios» (spec `horarios`).
module HorariosHelper
  # Los parámetros que una pantalla de horarios conserva al moverse dentro de
  # sí misma. «porque» y «hora» NO están: dicen lo que se acaba de tocar, y
  # arrastrarlos repetiría el mensaje en cada clic.
  PARAMETROS_DEL_HORARIO = %i[ver vista seccion armar area dia profesor alumno q].freeze

  # Los que conserva la pestaña «Horario» de una sección: la sección ya la dice
  # la dirección, y las otras miradas no viven ahí.
  PARAMETROS_DE_LA_PESTANA = %i[armar area dia].freeze

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

  # El tono de cada área del colegio, por orden alfabético: lo usan la pantalla
  # y el PDF (`HorarioPdf`), y por eso vive en un solo sitio.
  def self.colores_de_las_areas
    Subject.order(:name).pluck(:id).each_with_index.to_h { |id, i| [ id, COLORES_DE_AREA[i % COLORES_DE_AREA.size] ] }
  end

  # «Turno de la mañana, de 7:10 a. m. a 1:00 p. m.»: en la pantalla y en el PDF.
  def self.resumen_del_turno(turno)
    return turno.name if turno.time_slots.empty?

    "#{turno.name}, de #{HoraDelDia.con_meridiano(turno.entrada)} a #{HoraDelDia.con_meridiano(turno.salida)}"
  end

  # Si la semana se está mirando desde la pestaña «Horario» de la sección
  # (decisión 29), y no desde Académico ▸ Horarios. Lo marca la acción.
  def horario_en_la_seccion? = @en_la_seccion.present?

  # Esta misma pantalla, con algo cambiado: `ruta_del_horario(seccion: 4)`.
  #
  # ⚠️ Desde la pestaña de la sección, «esta misma pantalla» es la pestaña: un
  # enlace del marco que llevara a `/horarios` dibujaría ahí la otra puerta,
  # con su selector de secciones adentro (`MuestraElHorario`).
  def ruta_del_horario(**cambios)
    actuales = params.permit(*PARAMETROS_DEL_HORARIO).to_h.symbolize_keys
    if horario_en_la_seccion?
      return horario_section_path(@seccion, actuales.slice(*PARAMETROS_DE_LA_PESTANA).merge(cambios.except(:seccion)).compact_blank)
    end

    horarios_path(actuales.merge(cambios).compact_blank)
  end

  # Lo que llevan los formularios del marco para volver a la pestaña de donde
  # salieron (`MuestraElHorario#al_horario`).
  def desde_la_seccion = horario_en_la_seccion? ? { desde: "seccion" } : {}

  def color_del_area(materia)
    @colores_de_area ||= HorariosHelper.colores_de_las_areas
    @colores_de_area.fetch(materia.id, COLORES_DE_AREA.first)
  end

  def nombre_de_la_seccion(seccion) = "#{seccion.grade.name} #{seccion.name}"

  # «1er A»: cabe en una casilla.
  def corto_de_la_seccion(seccion) = "#{seccion.grade.name.split.first} #{seccion.name}"

  def apellido_del_profesor(profesor) = ChoquesDeHorario.apellido_de(profesor)

  def resumen_corto_del_turno(turno) = HorariosHelper.resumen_del_turno(turno)

  # Lo que pregunta «Publicar» antes de publicar: quién lo va a ver, y qué falta.
  def confirmacion_de_publicar(seccion, carga)
    texto = "¿Publicar el horario de #{nombre_de_la_seccion(seccion)}? Lo verán sus profesores, sus alumnos y las familias."
    texto += " Faltan #{carga.faltan} horas por ubicar: esas casillas saldrán vacías." if carga.faltan.positive?
    texto
  end

  # «la 1:00 p. m.» o «las 9:50 a. m.»: para «hasta las…» y «sale a las…».
  def las(minutos)
    hora = HoraDelDia.con_meridiano(minutos)
    (minutos / 60) % 12 == 1 ? "la #{hora}" : "las #{hora}"
  end

  # «A y B»: las secciones de un grado en el año.
  def letras_del_grado(seccion)
    Section.where(grade_id: seccion.grade_id, academic_period_id: seccion.academic_period_id)
           .pluck(:name).sort.to_sentence
  end
end
