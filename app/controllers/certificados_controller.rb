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
  include EntregaDocumentos

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

    # ⚠️ El Excel se BAJA, en la misma pestaña (su botón lleva
    # `formtarget="_self"`): no hay visor que lo muestre.
    return entregar_xlsx(certificados.xlsx_de(inscripciones)) if params[:formato] == "xlsx" && certificados.excel?

    abrir_la_impresion impresion_de_certificados_path(
      firma: firmar_la_impresion("seccion" => seccion.id, "ids" => inscripciones.map(&:id),
                                 "nombre" => certificados.nombre_del_archivo(inscripciones)),
      format: :pdf
    )
  end

  # Los certificados que se acaban de emitir, en la pestaña que abrió «Emitir».
  #
  # ⚠️ Se dibujan otra vez de la base, como siempre: certifican el expediente
  # de HOY (ver arriba). Lo que no se repite es la auditoría — quedó al emitir,
  # y recargar la pestaña no es emitir otro papel.
  def impresion
    seccion = Section.find(la_impresion.fetch("seccion"))
    certificados = CertificadosDeLaSeccion.new(seccion: seccion, director: director)
    inscripciones = en_el_orden_de_la_firma(seccion.enrollments.includes(student: :user),
                                            la_impresion.fetch("ids"))

    entregar_pdf certificados.pdf_de(inscripciones), la_impresion.fetch("nombre")
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
