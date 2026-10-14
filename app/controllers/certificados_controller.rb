# Los certificados de fin de año, emitidos por sección.
#
# Ver `docs/specs/certificados-en-documentos.md`.
#
# ## Por qué existe, si los certificados ya existían
#
# Existían desde el 11 de septiembre de 2026 (`MOR-99`) y nadie los encontraba.
# Cyndi los listó como faltantes; Daniel, el 1 de octubre: *«creo que ella nunca
# vio los certificados, no los encontró»*. Estaban en la última tarjeta de la
# ficha de cada alumno, mientras el menú «Documentos» ofrecía Boletines y
# Constancias y nada más.
#
#     Documentos
#     [ Boletines | Constancias | Certificados ]
#
# ## ⚠️ Es la tercera hermana, y se comporta como las otras dos
#
# «Elegir sección, elegir alumno, emitir». Un alumno o toda la sección, en un
# solo PDF con una página por alumno — que es lo que la secretaria quiere: un
# archivo para mandar a imprimir, no veinticuatro adjuntos.
#
# La tarjeta de la ficha NO se fue: la mamá que llega por el papel de su hijo
# sigue siendo un caso, y ahí está el Excel de la 31059, que es de a uno.
#
# ## Por qué no se congelan, como tampoco las constancias
#
# Certifican el expediente tal como está hoy. Si el colegio corrige una nota mal
# cargada, el certificado siguiente tiene que decir la corregida: congelarlo
# convertiría un error en un documento oficial permanente. Lo que queda es el
# rastro de quién emitió qué.
class CertificadosController < ApplicationController
  before_action :require_emisor!

  def index
    # ⚠️ El año Y el nivel de la sesión. Con «Primaria» elegido arriba, una
    # lista con las secciones de bachillerato adentro es el filtro que aparece
    # puesto y no filtra (`CLAUDE.md § 8.b`).
    @secciones = Section.del_anio_de_la_sesion.del_nivel_de_la_sesion
                        .includes(:grade, :academic_period).order("grades.name", :name)
    @secciones, @seccion = Section.con_la_pedida(@secciones, params[:section_id])
    @certificados = CertificadosDeLaSeccion.new(seccion: @seccion) if @seccion
  end

  def create
    seccion = Section.find(params[:section_id])
    certificados = CertificadosDeLaSeccion.new(seccion: seccion, director: director)
    inscripciones = las_que_se_emiten(seccion, certificados)

    return redirect_to(certificados_path(section_id: seccion.id), alert: por_que_no_hay(certificados)) if inscripciones.empty?

    registrar(certificados, inscripciones)

    send_data certificados.pdf_de(inscripciones).render,
              filename: certificados.nombre_del_archivo(inscripciones),
              type: "application/pdf", disposition: "attachment"
  end

  private

  # ⚠️ Eligiendo a UN alumno sale, también si repite: «fuera del lote» no es
  # «bloqueado». Lo que no sale nunca es un retirado — `regular` lo deja fuera
  # con un 404, igual que una inscripción de otra sección.
  def las_que_se_emiten(seccion, certificados)
    return certificados.del_lote if params[:enrollment_id].blank?

    [ seccion.enrollments.regular.find(params[:enrollment_id]) ]
  end

  # Dos motivos distintos, y no se pueden decir igual: una sección vacía no
  # tiene arreglo desde esta pantalla; una donde todos quedaron fuera del lote,
  # sí — eligiéndolos de a uno.
  def por_que_no_hay(certificados)
    return "Esa sección no tiene alumnos inscritos." if certificados.inscripciones.empty?

    "Ningún alumno de esa sección entra en «toda la sección». Elija al alumno para emitir el suyo."
  end

  # Quien firma es el director del colegio de la sesión. Sin uno cargado, las
  # casillas quedan como líneas para llenar a mano.
  def director = Admin.find_by(school: Current.school, role: :director)

  # ⚠️ Contra el ALUMNO si es uno, contra la SECCIÓN si es el lote.
  #
  # De a uno es el mismo rastro que deja la ficha, con la misma acción: quien
  # abra la bitácora de ese alumno tiene que ver su certificado venga de donde
  # venga. El lote es UN hecho —«emitió los de 6to A»— y no veinticuatro filas:
  # la bitácora contesta quién hizo qué, no es un archivo de documentos.
  def registrar(certificados, inscripciones)
    seccion = certificados.seccion

    if inscripciones.one?
      alumno = inscripciones.first.student
      log_activity(action: certificados.accion_de_auditoria, subject: alumno,
                   message: "#{current_user.nombre_completo} emitió #{certificados.papel} de #{alumno.user.nombre_completo}")
    else
      log_activity(action: certificados.accion_de_auditoria, subject: seccion,
                   message: "#{current_user.nombre_completo} emitió «#{certificados.papel}» para " \
                            "#{helpers.contar(inscripciones.size, 'alumno', 'alumnos')} " \
                            "de #{seccion.grade.name} – #{seccion.name}")
    end
  end

  # ⚠️ `emitir_documentos`, el mismo permiso de sus dos hermanas: las tres
  # pestañas las abre la misma gente, o la barra ofrecería una que rebota.
  def require_emisor!
    return if puede?(:emitir_documentos)

    redirect_to dashboard_path_for_user,
                alert: "Los certificados los emite la dirección o la secretaría del colegio."
  end
end
