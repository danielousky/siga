# La descarga de UN boletín por parte de la familia.
#
# Daniel: *«la boleta debe ser posible descargarla por parte del
# representante»*. Hasta ahora la familia veía que el boletín existía y tenía
# que pedirlo por la oficina.
#
# ## ⚠️ Tres preguntas antes de entregarlo, y ninguna sobra
#
#     ¿es de su representado?   o cambiar el id en la URL entrega el de otro
#     ¿está liberado?           un emitido sin revisar no es de nadie todavía
#     ¿está al día?             la deuda con el colegio bloquea el contenido
#
# La tercera la hace `ExigeEstarAlDia`, la misma que ya bloquea las notas: si el
# botón se muestra pero la URL se comparte, el bloqueo tiene que seguir de pie.
class BoletinesController < ApplicationController
  include ExigeEstarAlDia

  before_action :require_representante!
  before_action :set_boletin

  def show
    return if exigir_estar_al_dia!(@boletin.enrollment)

    send_data ReportCardPdf.new([ @boletin ]).render,
              filename: nombre_del_archivo,
              type: "application/pdf", disposition: "attachment"
  end

  private

  def set_boletin
    representante = Representative.find_by(user_id: current_user.id)
    raise ActiveRecord::RecordNotFound if representante.nil?

    # ⚠️ El filtro va en la CONSULTA y no en un `if` después: así un id ajeno da
    # 404 en vez de entregar el documento de otra familia.
    mios = Enrollment.where(student_id: representante.students.select(:id))
    @boletin = ReportCard.liberados.where(enrollment_id: mios.select(:id)).find(params[:id])
  end

  def nombre_del_archivo
    alumno = @boletin.enrollment.student.user
    "boletin-#{alumno.last_name.parameterize}-#{alumno.first_name.parameterize}-" \
      "#{@boletin.titulo.parameterize}.pdf"
  end

  def require_representante!
    return if representante?

    redirect_to dashboard_path_for_user, alert: "Esta sección es para representantes."
  end
end
