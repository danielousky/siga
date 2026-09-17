# Emisión de constancias de estudio.
#
# Es el documento que más pide una familia y el que ningún sistema barato emite:
# hoy la secretaría lo escribe en Word, uno por uno, cada vez que alguien lo pide
# — y siempre lo piden para mañana.
#
# ## Por qué NO se congela como el boletín
#
# El boletín certifica CALIFICACIONES y por eso guarda un snapshot: lo que decía
# en diciembre tiene que seguir diciéndolo en marzo (`MOR-98`).
#
# La constancia certifica una SITUACIÓN DE HOY — que esta persona está inscrita
# en este grado, en este año. Emitirla dos veces con seis meses de diferencia y
# que las dos digan lo mismo cuando el alumno cambió de grado convertiría un
# documento en un papel falso. Se dibuja de la base, a propósito.
class ConstanciasController < ApplicationController
  before_action :require_emisor!

  def index
    @secciones = Section.includes(:grade, :academic_period).order("grades.name", :name)
    @seccion   = @secciones.find { |s| s.id.to_s == params[:section_id] } || @secciones.first
    @alumnos   = @seccion ? inscripciones_de(@seccion) : []
  end

  def create
    seccion = Section.find(params[:section_id])

    inscripciones = if params[:enrollment_id].present?
                      [seccion.enrollments.find(params[:enrollment_id])]
                    else
                      inscripciones_de(seccion)
                    end

    return redirect_to(constancias_path(section_id: seccion.id),
                       alert: "Esa sección no tiene alumnos inscritos.") if inscripciones.empty?

    # ⚠️ Se EMITE y queda el rastro, con su código. Ver `Constancia`: lo que se
    # guarda no es «este alumno estudia aquí» —eso es de hoy y cambia— sino «el
    # colegio emitió este papel ese día, y decía esto», que es lo que un tercero
    # necesita comprobar.
    constancias = inscripciones.map { |i| Constancia.emitir!(i, por: current_user) }
    registrar(inscripciones, seccion)

    send_data ConstanciaDeEstudiosPdf.new(constancias).render,
              filename: nombre_del_archivo(seccion, inscripciones),
              type: "application/pdf", disposition: "attachment"
  end

  private

  def inscripciones_de(seccion)
    seccion.enrollments.includes(student: :user, section: [:grade, :academic_period])
           .to_a.sort_by { |i| [i.student.user.last_name, i.student.user.first_name] }
  end

  # No se guarda el documento —no se congela— pero sí QUIÉN lo emitió y para
  # quién. Una constancia es un papel con firma del director: que después nadie
  # pueda saber quién la sacó es justo lo que no puede pasar.
  def registrar(inscripciones, seccion)
    log_activity(
      action: "constancia_emitida",
      message: "#{current_user.nombre_completo} emitió " \
               "#{inscripciones.size == 1 ? 'una constancia' : "#{inscripciones.size} constancias"} " \
               "de #{seccion.grade.name} – #{seccion.name}"
    )
  end

  def nombre_del_archivo(seccion, inscripciones)
    if inscripciones.one?
      alumno = inscripciones.first.student.user
      "constancia-#{alumno.last_name.parameterize}-#{alumno.first_name.parameterize}.pdf"
    else
      "constancias-#{seccion.grade.name.parameterize}-#{seccion.name.parameterize}.pdf"
    end
  end

  # ⚠️ `emitir_documentos`, no `manage_students`: son dos permisos distintos y
  # compartían uno. El día que un colegio quiera que la secretaria cargue
  # alumnos pero no emita boletines, la tabla de `ApplicationController` cambia
  # en una línea en vez de desenredar tres controllers.
  def require_emisor!
    return if puede?(:emitir_documentos)

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para emitir constancias."
  end
end
