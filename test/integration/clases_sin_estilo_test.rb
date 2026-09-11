require "test_helper"

# Una clase que las vistas usan y el CSS no define.
#
# ## Por qué existe
#
# El 9 de septiembre, dos borrados de CSS escritos con un script se llevaron por
# delante lo que no debían: primero el bloque de `.plan-conectar` —el panel para
# enganchar evaluaciones— y después ciento setenta clases, entre ellas
# `.btn-guardar` y toda la cabecera. El patrón era el mismo: buscar el nombre
# del selector y borrar hasta el siguiente `}`, que con un selector múltiple
# terminado en coma se salta el bloque entero y sigue.
#
# ⚠️ **Lo grave no fue el borrado: fue que nada se enteró.** Sin
# `position: absolute`, un `<details>` deja de flotar y empuja la lista — pero
# abre, cierra y guarda igual, así que su test de sistema siguió en verde. El
# CSS no tiene compilador: lo que falta no da error, da una pantalla fea que
# alguien tiene que mirar.
class ClasesSinEstiloTest < ActiveSupport::TestCase
  VISTAS = Rails.root.glob("app/views/**/*.html.haml").freeze
  HOJAS  = Rails.root.glob("app/assets/stylesheets/*.css").freeze

  # Prefijos de clases que NO se declaran en el CSS del proyecto:
  #
  #   · las que arma el JavaScript al vuelo y solo existen en el navegador,
  #   · las que otro CSS del propio Rails o del navegador ya conoce,
  #   · las de utilidad que sí están, pero escritas dentro de otro selector.
  #
  # ⚠️ La lista se mantiene corta a propósito: cada entrada es un agujero por
  # donde vuelve a pasar el borrado que este test viene a impedir.
  CONOCIDAS = %w[
    hidden sr-only turbo-frame
  ].freeze

  # ⚠️ Las que YA estaban sin una sola regla el 9 de septiembre, cuando se
  # escribió este test. Casi todas son contenedores que solo agrupan —el CSS
  # les llega por un selector de descendencia— y alguna es un nombre que quedó
  # de un renombrado a medias.
  #
  # La lista está aquí para CONGELAR esa deuda, no para tolerarla: lo que
  # importa es que no crezca, y lo que se limpie sale de acá y no vuelve.
  YA_ESTABAN = %w[
    arranque-listo atrasado-dato carga-rapida contexto-anio-gestionar
    lista lista-errores portal-competencia que-evalua siga-form
  ].freeze

  def clases_de_las_vistas
    VISTAS.flat_map do |vista|
      texto = vista.read
      # ⚠️ Solo las clases ESCRITAS ENTERAS. Una interpolada —`btn-#{tono}`— no
      # se puede resolver leyendo el archivo, y darla por buena o por mala es
      # inventar: se salta.
      texto.scan(/class: "([^"#]+)"/).flatten
           .flat_map(&:split)
           .concat(texto.scan(/^\s*[%.#][\w-]*((?:\.[\w-]+)+)/).flatten.flat_map { |c| c.split(".") })
           .reject { |c| c.blank? || c.start_with?("-") }
           .map { |c| [ c, vista.relative_path_from(Rails.root).to_s ] }
    end
  end

  def clases_del_css
    @clases_del_css ||= HOJAS.flat_map { |h| h.read.scan(/\.([a-zA-Z][\w-]*)/).flatten }.to_set
  end

  test "la lista no está vacía: si no, este test no prueba nada" do
    assert_operator clases_de_las_vistas.size, :>=, 500,
      "se esperaban al menos quinientas clases escritas en las vistas"
  end

  test "toda clase escrita en una vista existe en el CSS" do
    huerfanas = clases_de_las_vistas.reject { |clase, _| clases_del_css.include?(clase) }
                                    .reject { |clase, _| CONOCIDAS.any? { |c| clase.start_with?(c) } }
                                    .reject { |clase, _| YA_ESTABAN.include?(clase) }
                                    .group_by(&:first)
                                    .transform_values { |pares| pares.map(&:last).uniq }

    assert_empty huerfanas,
      "clases sin una sola regla en el CSS. O se borró su bloque sin querer, o " \
      "hay un nombre mal escrito — las dos cosas se ven en pantalla y en ningún " \
      "log:\n  " + huerfanas.map { |clase, vistas| ".#{clase} → #{vistas.first(3).join(', ')}" }.join("\n  ")
  end
end
