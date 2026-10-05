# El aviso de que el boletín ya se puede ver.
#
# Daniel: *«"ya puede descargar la boleta" si está solvente, si no "póngase al
# día para poder visualizar la boleta de su hijo"»*.
#
# ## ⚠️ Dos redacciones, y no es cortesía
#
# Mandarle a una familia en mora «ya puede descargarlo» es prometerle una
# pantalla que la va a rebotar. El correo tiene que decir la verdad de lo que va
# a encontrar al hacer clic.
#
#     al día   →  «está listo, acá lo descarga»
#     en mora  →  «está listo; para verlo hace falta ponerse al día»
#
# ⚠️ Y el de la mora NO es un correo de cobranza. No lleva el monto, no dice
# cuántos meses debe y no reclama: dice que el documento existe y qué falta para
# abrirlo. La deuda con su detalle vive en «Mis pagos», que es donde se resuelve.
#
# ⚠️ Lo escribe el COLEGIO, no SIGA: sale con su cabecera (`a_nombre_de`). Para
# la familia esto viene de la escuela de su hijo.
class BoletinMailer < ApplicationMailer
  def liberado(boletin)
    @boletin = boletin
    @inscripcion = boletin.enrollment
    @alumno = @inscripcion.student.user
    @colegio = @inscripcion.section.grade.school
    @titulo = boletin.titulo
    @al_dia = EstadoDeCuenta.de(@inscripcion).al_dia?
    @url = @al_dia ? representante_url : pagos_url
    a_nombre_de(@colegio)

    destinatarios = correos_de_la_familia
    return if destinatarios.empty?

    mail to: destinatarios,
         # ⚠️ El nombre en TÍTULO, no como se guarda. `first_name` vive en
         # mayúscula —así lo normaliza el formulario— y «el boletín de ALUMNO1»
         # en el asunto de un correo se lee como un grito.
         subject: "#{@colegio.name}: el boletín de #{Normaliza.titulo(@alumno.first_name)} " \
                  "ya está disponible"
  end

  private

  # ⚠️ A TODOS los representantes con correo, no solo al principal.
  #
  # En una familia separada el boletín le interesa a los dos, y quien tiene la
  # sesión abierta no siempre es quien figura como principal. Sin correo no se
  # manda nada —no hay a dónde— y eso no es un error: el colegio se lo entrega
  # en papel, como siempre.
  def correos_de_la_familia
    StudentRepresentative.where(student_id: @inscripcion.student_id)
                         .includes(representative: :user)
                         .filter_map { |v| v.representative.user.email.presence }
                         .uniq
  end
end
