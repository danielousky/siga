# La emisión de boletines.
#
# Es el trabajo que hoy consume días de secretaría tres veces al año. Un colegio
# que pasa de dos días de armado manual a un clic recuperó la suscripción anual
# en ese solo trimestre.
#
# ## Se emite en línea, y no por job — se midió, y hay que VOLVER a medir
#
# Una sección entera, en local, el 1 de octubre de 2026:
#
#   primaria con su plan    21 alumnos · 42 páginas    5,2 s   (1,2 datos + 4,0 PDF)
#   Media                   22 alumnos · 44 páginas    2,9 s
#   primaria sin plan       21 alumnos · 21 páginas    1,4 s
#   Inicial                 20 alumnos · 20 páginas    1,1 s
#
# ⚠️ Aquí decía «sección de 20 ~560 ms», y era cierto cuando se midió: el
# boletín era una página con una nota por materia. Después ganó competencias,
# indicadores, rúbrica, informe y comparación con la sección, y NADIE volvió a
# medir. El día que Daniel emitió 4to Grado A tardó veintiséis segundos, con
# 40.866 consultas — ver `ReportCardData#materias`.
#
# Una medida escrita en un comentario envejece en silencio. La de arriba
# depende de CUÁNTO dibuja el boletín: si crece, se vuelve a tomar.
#
# ⚠️ De esos 4,0 s de PDF, 3,5 son la tabla de competencias: `prawn-table`
# tarda 3 ms por fila y una sección trae más de mil.
#
# El issue daba por hecho que la emisión masiva tenía que ir por job porque "un
# PDF por alumno de una sección de 35 es demasiado para un request". Pero no son
# 35 PDF: es **un PDF con 35 páginas**, que es además lo que la secretaria quiere
# —un archivo para mandar a imprimir, no 35 adjuntos.
#
# Y por job habría que resolver dónde queda el archivo y cómo se lo entrega al
# usuario después. Medio segundo de espera con el archivo en la mano es mejor
# producto que una notificación diferida.
#
# ## Quién emite
#
# Dirección y secretaría. Un boletín lleva la firma del director: no lo emite el
# alumno ni el profesor de una materia.
#
# Ver MOR-98.
class ReportCardsController < ApplicationController
  before_action :require_emisor!

  def index
    @secciones = Section.del_anio_de_la_sesion.includes(:grade, :academic_period).order("grades.name", :name)
    @seccion   = @secciones.find { |s| s.id.to_s == params[:section_id] } || @secciones.first
    @lapsos    = @seccion ? EvaluationMoment.where(academic_period_id: @seccion.academic_period_id).order(:id) : []
    @alumnos   = @seccion ? inscripciones_de(@seccion) : []
    @recientes = ReportCard.del_anio_de_la_sesion
                           .includes(:evaluation_moment, enrollment: { student: :user }).recientes.limit(15)
    # La tabla muestra 15. El total va aparte para poder DECIR que está topada:
    # un listado recortado en silencio se lee como "esto es todo lo que hay".
    @total_emitidos = ReportCard.del_anio_de_la_sesion.count
  end

  def create
    seccion = Section.find(params[:section_id])
    lapso   = lapso_elegido(seccion)

    inscripciones = if params[:enrollment_id].present?
                      [seccion.enrollments.find(params[:enrollment_id])]
                    else
                      inscripciones_de(seccion)
                    end

    if inscripciones.empty?
      return redirect_to report_cards_path(section_id: seccion.id),
                         alert: "Esa sección no tiene alumnos inscritos."
    end

    boletines = emitir(inscripciones, lapso)

    log_activity(
      action: "report_cards_issued",
      message: "#{current_user.nombre_completo} emitió " \
               "#{helpers.contar(boletines.size, 'boletín', 'boletines')} " \
               "de #{seccion.grade.name} – #{seccion.name} (#{lapso&.name || 'anual'})",
      subject: seccion,
      metadata: { codigos: boletines.map(&:code) }
    )

    send_data ReportCardPdf.new(boletines).render,
              filename: nombre_de_archivo(seccion, lapso, inscripciones),
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  # Cada emisión es una fila nueva, con su propio código y su propia foto de las
  # notas. Reemitir en marzo no pisa lo que decía el papel de diciembre.
  def emitir(inscripciones, lapso)
    inscripciones.map do |inscripcion|
      ReportCard.create!(
        enrollment: inscripcion,
        evaluation_moment: lapso,
        issued_by: current_user,
        snapshot: ReportCardData.para(enrollment: inscripcion, evaluation_moment: lapso)
      )
    end
  end

  def inscripciones_de(seccion)
    seccion.enrollments
           .where(status: :regular)
           .includes(student: :user)
           .to_a
           .sort_by { |i| [i.student.user.last_name, i.student.user.first_name] }
  end

  # `anual` o el id de un lapso, buscado ENTRE LOS DEL PERÍODO DE LA SECCIÓN: un
  # id de otro año escolar simplemente no aparece.
  def lapso_elegido(seccion)
    return nil if params[:evaluation_moment_id].blank? || params[:evaluation_moment_id] == "anual"

    EvaluationMoment.where(academic_period_id: seccion.academic_period_id)
                    .find_by(id: params[:evaluation_moment_id])
  end

  def nombre_de_archivo(seccion, lapso, inscripciones)
    partes = ["boletines", seccion.grade.name, seccion.name, lapso&.name || "anual"]
    partes << inscripciones.sole.student.user.last_name if inscripciones.one?
    partes.join("-").parameterize + ".pdf"
  end

  # ⚠️ `emitir_documentos`, no `manage_students`: son dos permisos distintos y
  # compartían uno. El día que un colegio quiera que la secretaria cargue
  # alumnos pero no emita boletines, la tabla de `ApplicationController` cambia
  # en una línea en vez de desenredar tres controllers.
  def require_emisor!
    return if puede?(:emitir_documentos)

    redirect_to dashboard_path_for_user,
                alert: "Los boletines los emite la dirección o la secretaría del colegio."
  end
end
