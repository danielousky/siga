# Lo que Control de Estudio cierra deja de poder tocarse (MOR-136 / QA de Cyndi).
#
# Daniel: *«al dar el visto bueno… el profe ya no puede modificar las notas»*.
#
# ## ⚠️ Vive en el MODELO, no en la pantalla
#
# Un límite que solo existe en un controller no es un límite: la próxima
# pantalla que escriba notas —un importador, una acción en lote, una API— no se
# entera. Acá cualquier escritura pasa por la misma validación.
#
# Quien lo incluye dice de qué par (sección, lapso) depende:
#
#     se_cierra_con_el_lapso   # columnas propias: section_id, evaluation_moment_id
#     se_cierra_con_el_lapso :evaluation_activity   # las de su actividad
module SeCierraConElLapso
  extend ActiveSupport::Concern

  class_methods do
    def se_cierra_con_el_lapso(por = nil)
      define_method(:llave_del_cierre) do
        origen = por.nil? ? self : public_send(por)
        return [ nil, nil ] if origen.nil?

        [ origen.section_id, origen.evaluation_moment_id ]
      end
      private :llave_del_cierre

      validate :el_lapso_no_esta_cerrado
      before_destroy :impedir_si_el_lapso_esta_cerrado
    end
  end

  private

  def el_lapso_no_esta_cerrado
    return unless lapso_cerrado?

    errors.add(:base, "Control de Estudio ya cerró este lapso: las notas no se pueden cambiar.")
  end

  # ⚠️ Borrar también es cambiar. Sin esto, vaciar el campo de la planilla
  # —que es como se borra una nota— se saltaba el cierre entero.
  def impedir_si_el_lapso_esta_cerrado
    return unless lapso_cerrado?

    errors.add(:base, "Control de Estudio ya cerró este lapso: las notas no se pueden borrar.")
    throw :abort
  end

  def lapso_cerrado?
    seccion, lapso = llave_del_cierre
    SectionClosure.cerrado?(section_id: seccion, evaluation_moment_id: lapso)
  end
end
