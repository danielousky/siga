# La emisión de boletines.
#
# Es el trabajo que hoy consume días de secretaría tres veces al año. Un colegio
# que pasa de dos días de armado manual a un clic recuperó la suscripción anual
# en ese solo trimestre.
#
# ## Se emite en línea, y no por job — se midió, y hay que VOLVER a medir
#
# Una sección entera, en local, el 5 de octubre de 2026 (datos + PDF):
#
#   primaria con su plan    21 alumnos · 42 hojas    2,2 s   (1,2 + 1,0)
#   Media, de lapso         22 alumnos · 22 hojas    1,7 s   (0,5 + 1,2)
#   Media, anual            22 alumnos · 22 hojas    1,1 s
#   primaria sin plan       21 alumnos · 21 hojas    1,1 s
#   Inicial                 20 alumnos · 20 hojas    0,9 s
#
# ⚠️ Aquí decía «sección de 20 ~560 ms», y era cierto cuando se midió: el
# boletín era una página con una nota por materia. Después ganó competencias,
# indicadores, rúbrica, informe y comparación con la sección, y NADIE volvió a
# medir. El día que Daniel emitió 4to Grado A tardó veintiséis segundos, con
# 40.866 consultas — ver `ReportCardData#materias`— y cuatro de esos segundos
# eran `prawn-table` dibujando mil filas — ver `TablaAMano`.
#
# Una medida escrita en un comentario envejece en silencio. La de arriba
# depende de CUÁNTO dibuja el boletín: si crece, se vuelve a tomar.
#
# ⚠️ Lo que queda por alumno son dos cosas. Generar el código QR, 16 ms: es
# Ruby puro y prueba ocho máscaras, y no baja sin cambiar de librería. Y unas 55
# consultas para armar el plan evaluado, que es el mismo para toda la sección y
# se vuelve a leer con cada alumno: eso sí tiene de dónde bajar.
#
# Y por job habría que resolver dónde queda el archivo y cómo se lo entrega al
# usuario después. Un par de segundos de espera con el archivo en la mano es
# mejor producto que una notificación diferida.
#
# ⚠️ Se evaluó en serio y se decidió que NO (Daniel, 5 de octubre de 2026): ver
# `docs/specs/emision-en-segundo-plano.md`. Se reabre si un colegio se queja de
# la espera, y ese día lo primero es medir cuánto tarda en producción.
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
    @secciones, @seccion = Section.con_la_pedida(@secciones, params[:section_id])
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
