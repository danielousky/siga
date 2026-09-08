require "test_helper"

# Las traducciones, revisadas por lo que ya se rompió.
#
# ## ⚠️ Una clave repetida en el YAML se pierde EN SILENCIO
#
# Se agregaron las asociaciones de `restrict_with_error` bajo `attributes:` y
# ocho de los modelos YA estaban ahí. YAML no se queja: la segunda clave gana y
# la primera desaparece entera. El síntoma fueron dos tests que buscaban
# rótulos —«Identificador», «Nivel»— que habían dejado de existir sin que nadie
# tocara esa línea.
#
# Es la misma trampa que dos `data:` en una llamada de Haml, en otro archivo: el
# lenguaje admite el duplicado y se queda con uno.
class TraduccionesTest < ActiveSupport::TestCase
  ARCHIVOS = Rails.root.glob("config/locales/*.yml").freeze

  test "ningún archivo de traducción repite una clave en el mismo nivel" do
    repetidas = ARCHIVOS.flat_map do |archivo|
      pila, vistas, culpables = [], {}, []

      archivo.readlines.each_with_index do |linea, n|
        next if linea.strip.empty? || linea.lstrip.start_with?("#")
        clave = linea[/\A( *)([\w.-]+):/, 2] or next
        sangria = linea[/\A */].size

        pila.pop while pila.any? && pila.last >= sangria
        vistas.delete_if { |(s, _), _| s >= sangria && s != sangria }
        pila << sangria

        camino = [ sangria, clave ]
        if (antes = vistas[camino])
          culpables << "#{archivo.basename}:#{n + 1} «#{clave}» ya estaba en la línea #{antes}"
        end
        vistas[camino] = n + 1
      end

      culpables
    end

    assert_empty repetidas,
      "claves repetidas: YAML se queda con la ÚLTIMA y pierde la otra sin avisar:\n  " +
      repetidas.join("\n  ")
  end

  test "el español no tiene claves vacías" do
    vacias = []
    recorrer = lambda do |nodo, camino|
      case nodo
      when Hash  then nodo.each { |k, v| recorrer.call(v, camino + [ k ]) }
      when Array then nodo.each_with_index { |v, i| recorrer.call(v, camino + [ i ]) }
      when nil   then vacias << camino.join(".")
      end
    end
    recorrer.call(YAML.load_file(Rails.root.join("config/locales/es.yml")), [])

    assert_empty vacias, "claves sin valor, que se muestran como el nombre de la clave:\n  " + vacias.join("\n  ")
  end
end
