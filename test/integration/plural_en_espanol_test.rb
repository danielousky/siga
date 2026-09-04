require "test_helper"

# El plural de la app se escribe, no se deduce.
#
# `String#pluralize` y el `pluralize` de las vistas usan el inflector **inglés**,
# y la app está en español. El problema no es que falle: es que **acierta por
# casualidad** en las palabras terminadas en vocal, así que se usa sin pensar y
# el día que la palabra lleva tilde o termina en consonante sale un texto roto en
# una pantalla que ve una familia.
#
#     "alumno".pluralize(2)    # => "alumnos"    ✓ por casualidad
#     "boletín".pluralize(2)   # => "boletíns"   ✗
#     "profesor".pluralize(2)  # => "profesors"  ✗
#     "sección".pluralize(2)   # => "sección"    ✗ ni la pluraliza
#     "estaba".pluralize(2)    # => "estabas"    ✗ un verbo, además
#
# `ApplicationHelper#pluralizar` y `#contar` llevan las dos formas escritas, y
# existen desde MOR-210. Este test es lo que impide que el atajo inglés vuelva a
# entrar de a poco — el último caso lo escribí yo mismo en MOR-166, teniendo el
# helper a la vista.
#
# ## Lo que sí se permite
#
# `pluralize(n, "x", plural: "y")` con las dos formas explícitas es correcto: es
# lo mismo que hace `contar`. Lo que se prohíbe es dejar que Rails adivine.
class PluralEnEspanolTest < ActiveSupport::TestCase
  # Un `pluralize` de una sola palabra, sin `plural:` — o sea, adivinando.
  ADIVINANDO = /\bpluralize\(\s*[^,)]+,\s*["'][^"']+["']\s*\)/
  # `"palabra".pluralize` a secas.
  SOBRE_UNA_CADENA = /["'][^"']+["']\.pluralize\b/

  # Los `inflections.rb` declaran plurales a medida a propósito: ahí es donde
  # vive la excepción, no en las vistas.
  EXENTOS = %w[config/initializers/inflections.rb].freeze

  test "nada le pide a Rails que adivine un plural en español" do
    ofensas = []

    (Rails.root.glob("app/**/*.{rb,haml}") + Rails.root.glob("lib/**/*.rb")).each do |ruta|
      relativa = ruta.relative_path_from(Rails.root).to_s
      next if EXENTOS.include?(relativa)

      ruta.read.each_line.with_index(1) do |linea, n|
        # Los comentarios explican justamente por qué NO se usa. Ver el helper.
        next if linea.strip.start_with?("#", "-#")

        [ ADIVINANDO, SOBRE_UNA_CADENA ].each do |patron|
          ofensas << "#{relativa}:#{n} — #{linea.strip}" if linea.match?(patron)
        end
      end
    end

    assert_empty ofensas,
      "El inflector de Rails es inglés y acierta por casualidad. Usa " \
      "`contar(n, \"singular\", \"plural\")` o `pluralizar`, que llevan las dos " \
      "formas escritas:\n  " + ofensas.join("\n  ")
  end

  # La otra mitad: que el helper haga lo que dice, con las palabras que de
  # verdad aparecen en la app y que el inflector inglés rompe.
  test "el helper acierta donde Rails falla" do
    ayuda = Class.new { include ApplicationHelper }.new

    { [ "boletín", "boletines" ] => "boletines",
      [ "sección", "secciones" ] => "secciones",
      [ "profesor", "profesores" ] => "profesores",
      [ "lápiz", "lápices" ] => "lápices" }.each do |(singular, plural), esperado|
      assert_equal esperado, ayuda.pluralizar(2, singular, plural)
      assert_equal singular, ayuda.pluralizar(1, singular, plural)
      refute_equal singular.pluralize(2), esperado,
                   "«#{singular}» ya no sirve de ejemplo: el inflector inglés ahora acierta"
    end
  end
end
