# Lo que una familia en mora NO puede ver (spec: `docs/specs/pagos-de-la-familia.md`).
#
# Daniel: *«ellos deben siempre poder ingresar a la sesión. Lo que no pueden ver
# es… ni las constancias de estudios, ni ver las boletas, ni la asistencia, ni
# nada del contenido relevante»*.
#
# ## ⚠️ NO es la deuda del colegio con SIGA, y son fáciles de mezclar
#
#     EL COLEGIO le debe a SIGA          LA FAMILIA le debe al COLEGIO
#     ─────────────────────────          ─────────────────────────────
#     el sistema pasa a solo lectura     el representante entra igual
#     las constancias SIGUEN saliendo    y NO ve notas, asistencia ni
#     (§ MOR-108: el perjuicio no        constancias
#      puede ser del alumno)
#
# La primera es de SIGA y su cliente; esta es del colegio y su representado, y el
# colegio es quien decide. `RespetaLaSuscripcion` es la otra y no se toca.
#
# ## ⚠️ Se ENTRA, no se expulsa
#
# La sesión funciona, el menú está y las pantallas bloqueadas muestran un aviso
# que explica qué pasa y lleva a reportar el pago. Una puerta cerrada sin
# explicación es una llamada al colegio.
#
# ## ⚠️ Y el bloqueo es por INSCRIPCIÓN, no por representante
#
# Una madre con dos hijos puede estar al día con uno y deber por el otro.
# Bloquearle los dos la castiga por una deuda que no tiene.
module ExigeEstarAlDia
  extend ActiveSupport::Concern

  included do
    helper_method :estado_de_cuenta_de, :bloqueado_por_deuda?
  end

  private

  def estado_de_cuenta_de(enrollment)
    return nil if enrollment.nil?

    @estados_de_cuenta ||= {}
    @estados_de_cuenta[enrollment.id] ||= EstadoDeCuenta.de(enrollment)
  end

  # ⚠️ Solo alcanza a la FAMILIA. La dirección y el profesor ven las notas de un
  # alumno en mora igual: son quienes tienen que trabajar con él, y esconderles
  # el dato convierte una gestión de cobranza en un problema pedagógico.
  def bloqueado_por_deuda?(enrollment)
    return false unless representante? || estudiante?

    estado_de_cuenta_de(enrollment)&.en_mora? || false
  end

  # Corta la acción con el aviso amable. Devuelve `true` si cortó, para que
  # quien la llame haga `return if ...`.
  def exigir_estar_al_dia!(enrollment)
    return false unless bloqueado_por_deuda?(enrollment)

    @estado_de_cuenta = estado_de_cuenta_de(enrollment)
    @inscripcion_bloqueada = enrollment
    render "shared/al_dia_primero", status: :payment_required
    true
  end
end
