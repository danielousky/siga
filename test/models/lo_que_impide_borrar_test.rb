require "test_helper"

# Lo que IMPIDE borrar se dice en español (QA del 8 de septiembre).
#
# Daniel intentó borrar una evaluación con notas y leyó:
#
#     «no se puede eliminar mientras tenga activity grades cargadas»
#
# El mensaje ya estaba traducido; el nombre de la asociación NO — y es el que
# se lee. El defecto alcanzaba a las VEINTISÉIS asociaciones con
# `restrict_with_error`: cada borrado bloqueado de la app le decía a un
# director el nombre de una tabla en inglés.
#
# ⚠️ Es exactamente el mismo defecto que ya se corrigió con los atributos de
# `User` —«First name no puede estar en blanco»— y volvió por la puerta de al
# lado, porque las ASOCIACIONES también pasan por `human_attribute_name` y
# nadie las había mirado.
class LoQueImpideBorrarTest < ActiveSupport::TestCase
  # Los modelos con `restrict_with_error`, leídos del código: una asociación
  # nueva entra sola en el test, sin que haya que acordarse de agregarla.
  def asociaciones_que_impiden_borrar
    Rails.root.glob("app/models/*.rb").flat_map do |archivo|
      modelo = archivo.basename(".rb").to_s.camelize.safe_constantize
      next [] unless modelo.respond_to?(:reflect_on_all_associations)

      modelo.reflect_on_all_associations
            .select { |a| a.options[:dependent] == :restrict_with_error }
            .map { |a| [ modelo, a.name ] }
    end
  end

  test "la lista no está vacía: si no, este test no prueba nada" do
    assert_operator asociaciones_que_impiden_borrar.size, :>=, 20,
      "se esperaban al menos veinte asociaciones con restrict_with_error"
  end

  test "ninguna asociación que impide borrar se lee en inglés" do
    sin_traducir = asociaciones_que_impiden_borrar.filter_map do |modelo, asociacion|
      nombre = modelo.human_attribute_name(asociacion)

      # Sin traducción, Rails humaniza el nombre de la columna: «activity
      # grades», «teacher sections». Traducido, no coincide con eso.
      "#{modelo}##{asociacion} → «#{nombre}»" if nombre == asociacion.to_s.humanize
    end

    assert_empty sin_traducir,
      "asociaciones que un director leería en inglés al no poder borrar algo:\n  " +
      sin_traducir.join("\n  ")
  end

  # ⚠️ El mensaje NO lleva género ni «cargadas»: el mismo texto sale para notas,
  # secciones, alumnos e inscripciones, y cualquier adjetivo concuerda con la
  # mitad. Decía «mientras tenga %{record} cargadas» y con la traducción puesta
  # quedó «mientras tenga notas cargadas cargadas».
  test "el mensaje se lee entero, sin concordancias rotas" do
    mensaje = I18n.t("activerecord.errors.messages.restrict_dependent_destroy.has_many",
                     record: "secciones")

    assert_equal "no se puede eliminar: todavía tiene secciones", mensaje
  end
end
