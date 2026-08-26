# Los documentos que el MPPE exige y el colegio hoy llena a mano (MOR-99).
#
#     31059      Certificación de Calificaciones · Educación Media General
#                de 1º a 5º año en un solo papel, en PDF o en Excel
#     primaria   Certificado de Educación Primaria (al terminar 6to Grado)
#                Constancia de Prosecución (al aprobar cualquier otro grado)
#
# ## Por qué NO se congela como el boletín
#
# El boletín guarda un snapshot porque certifica lo que decía en diciembre
# (`MOR-98`). Estos certifican **el expediente completo tal como está hoy**: si
# el colegio corrige una nota mal cargada, la certificación siguiente tiene que
# decir la nota corregida. Congelarla convertiría un error en un documento
# oficial permanente.
#
# Lo que sí queda es el rastro: cada emisión se audita.
class DocumentosOficialesController < ApplicationController
  before_action :require_emisor!

  # La 31059, en PDF o en Excel.
  #
  # ⚠️ El Excel no es un capricho: el formato tiene casillas que SIGA no puede
  # llenar —el teléfono del plantel, el grupo de Participación, los datos del
  # director de la zona educativa— y mientras esto se asienta va a haber más. Con
  # solo el PDF, el colegio queda bloqueado esperando que nosotros cambiemos algo.
  def certificacion
    alumno = Student.find(params[:student_id])
    armador = CertificacionDeCalificaciones.new(student: alumno)

    unless armador.emitible?
      return redirect_to student_path(alumno),
                         alert: "La certificación 31059 es de Educación Media General, y " \
                                "#{alumno.user.first_name} no tiene años de bachillerato cargados."
    end

    datos = armador.datos.merge("firmante" => firmante)
    registrar("certificacion_emitida", alumno, "Certificación de Calificaciones (31059)")

    case params[:format]
    when "xlsx" then enviar_xlsx(CertificacionXlsx.new(datos))
    else enviar_pdf(CertificacionPdf.new(datos), "certificacion-31059-#{apellido(alumno)}.pdf")
    end
  end

  # El certificado o la constancia de primaria, según a dónde promueva el grado.
  def primaria
    inscripcion = Enrollment.find(params[:enrollment_id])
    armador = DocumentoDePrimaria.new(enrollment: inscripcion, firmante: firmante_admin)

    unless armador.emitible?
      return redirect_to student_path(inscripcion.student),
                         alert: "Este documento es de Educación Primaria. Para bachillerato, " \
                                "use la Certificación de Calificaciones."
    end

    datos = armador.datos
    registrar("documento_de_primaria_emitido", inscripcion.student,
              datos["tipo"] == "certificado" ? "Certificado de Educación Primaria" : "Constancia de Prosecución")

    enviar_pdf(DocumentoDePrimariaPdf.new(datos),
               "#{datos['tipo']}-primaria-#{apellido(inscripcion.student)}.pdf")
  end

  private

  def enviar_pdf(documento, nombre)
    send_data documento.render, filename: nombre, type: "application/pdf", disposition: "inline"
  end

  def enviar_xlsx(documento)
    send_data documento.to_stream.read, filename: documento.nombre_de_archivo,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def apellido(alumno) = alumno.user.apellidos.to_s.parameterize.presence || alumno.id.to_s

  # Quien firma es el director del colegio de la sesión. Si el colegio no tiene
  # uno cargado, las casillas quedan como líneas para llenar a mano — que es lo
  # que hace el papel oficial.
  def firmante_admin = Admin.find_by(school: Current.school, role: :director)

  def firmante
    director = firmante_admin
    return {} if director.nil?

    { "nombre" => director.user.nombre_completo, "documento" => director.user.identificador }
  end

  # ⚠️ Se audita QUE se emitió, no qué decía.
  #
  # El documento se dibuja de la base cada vez, así que guardar una copia sería
  # guardar una foto que puede contradecir a la siguiente. Lo que importa del
  # rastro es quién pidió un certificado de quién y cuándo.
  def registrar(accion, alumno, que)
    log_activity(action: accion,
                 message: "#{current_user.nombre_completo} emitió #{que} de #{alumno.user.nombre_completo}",
                 subject: alumno)
  end

  def require_emisor!
    return if can_manage_students?

    redirect_to dashboard_path_for_user, alert: "No tienes permiso para emitir documentos oficiales."
  end
end
