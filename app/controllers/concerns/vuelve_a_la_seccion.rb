# A dónde vuelve un profesor (etapa ③).
#
# ⚠️ Para un profesor, `/competencias` y `/evaluaciones` DEJARON DE SER
# DESTINO.
#
# Daniel, después de cancelar un formulario y caer en el listado global: *«esa
# vista ya no debe estar, al igual que evaluaciones; volver lleva a evaluaciones
# sin sección»*. Y es la conclusión de toda la etapa ③: si el trabajo del
# profesor es por sección, un listado que no dice de cuál es exactamente la
# descontextualización que las pestañas vinieron a evitar — con el agravante de
# que ahí hay que volver a elegir grado, área, sección y lapso.
#
# Las pantallas **siguen existiendo**: son la entrada de la DIRECCIÓN, que
# supervisa el colegio entero y para quien «todas las evaluaciones» sí es una
# pregunta. Lo que cambia es que un profesor nunca aterriza ahí.
#
#     PROFESOR      cualquier vuelta → la pestaña de SU sección
#     DIRECCIÓN     los listados siguen siendo suyos
module VuelveALaSeccion
  extend ActiveSupport::Concern

  private

  # La pestaña «Planificar» de una asignación.
  def ruta_de_planificar(asignacion, lapso = nil)
    return competencies_path if asignacion.nil?

    planificar_section_path(asignacion.section_id, area: asignacion.subject_id, lapso: lapso&.id)
  end

  # La pestaña «Calificar» de una evaluación: la libreta donde vive su columna.
  def ruta_de_calificar(actividad)
    section_path(actividad.section_id, area: actividad.subject_id,
                 lapso: actividad.evaluation_moment_id)
  end
end
