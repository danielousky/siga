# Lo que en la instancia de MUESTRA no se le puede hacer a una cuenta de entrada
# (`Muestra::TODAS`).
#
# La muestra es de todos los que la visitan a la vez, con la misma clave. Sin
# esto, el primero que entra como director y borra al profesor —o le quita el
# cargo al propio director— deja rota la puerta para todos los que vengan
# después, hasta que la muestra se restablezca de noche.
#
#     NO SE BORRA      el rol con que esa cuenta entra
#     NO CAMBIA        su cargo, si es de dirección
#
# El correo y la contraseña los cuida `User` (`la_puerta_de_la_muestra_no_cambia`).
#
# ⚠️ Todo lo demás SÍ se puede tocar: de eso se trata. Esto no protege los datos
# de la muestra —para eso está el restablecido de cada noche—, protege las
# PUERTAS.
#
# Fuera de la muestra no hace nada: `Muestra.protege?` pregunta primero si la
# instancia lo es.
module PuertaDeLaMuestra
  extend ActiveSupport::Concern

  NO_SE_BORRA = "En el colegio de muestra esta cuenta es una de las puertas de entrada: " \
                "no se puede eliminar.".freeze

  included do
    # ⚠️ `prepend: true`: tiene que frenar ANTES de que `dependent: :destroy`
    # se lleve lo que cuelga del rol. Abortar después dejaría el rol en pie y
    # sin sus secciones.
    before_destroy :conservar_la_puerta_de_la_muestra, prepend: true
    validate :conservar_el_cargo_de_la_puerta, on: :update
  end

  private

  def conservar_la_puerta_de_la_muestra
    return unless Muestra.protege?(user)

    errors.add(:base, NO_SE_BORRA)
    throw :abort
  end

  def conservar_el_cargo_de_la_puerta
    return unless has_attribute?(:role) && will_save_change_to_role? && Muestra.protege?(user)

    errors.add(:role, "no se cambia en el colegio de muestra: es una de las puertas de entrada")
  end
end
