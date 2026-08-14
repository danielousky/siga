require "test_helper"

# El sistema de diseño (MOR-135).
#
# ## Por qué existe este test
#
# Esta app **no carga Bootstrap**. Pero se generó con andamios de Rails, que
# escriben clases de Bootstrap, y nadie las revisó: durante meses hubo
# **44 botones** apuntando a variantes que ninguna hoja de estilo define.
#
#     btn-outline-primary    23 usos    ← "Volver", en todos los andamios
#     btn-danger             15 usos    ← TODOS los botones de borrar
#     btn-outline-secondary   6 usos    ← "Editar", en todos los andamios
#
# Un botón así no explota: hereda `.btn` —que le da relleno y borde
# transparente— y se dibuja como texto suelto. Se ve exactamente como una
# pantalla a medio hacer, y por eso Daniel dijo que las vistas parecían de otro
# sistema. Nada en el pipeline lo notaba, porque el HTML es válido y el test
# de humo devuelve 200.
class SistemaDeDisenoTest < ActiveSupport::TestCase
  VISTAS = Rails.root.glob("app/views/**/*.haml").freeze
  HOJA   = Rails.root.join("app/assets/stylesheets/system.css").freeze

  # Las clases de una vista Haml se escriben de DOS maneras, y hay que mirar las
  # dos. Este test nació mirando solo la primera y se le escapó
  # `%small.form-text.text-muted`, que es Bootstrap puro:
  #
  #     class: "btn btn-danger"     ← atributo
  #     %small.form-text            ← abreviatura de Haml
  #     .card-academic              ← abreviatura, con %div implícito
  #
  # Se ignoran los comentarios (`-#`), para que una vista que EXPLICA una clase
  # vieja no se confunda con una que la usa.
  def self.clases_de(texto)
    sin_comentarios = texto.lines.reject { |l| l.strip.start_with?("-#") }.join

    atributos = sin_comentarios.scan(/class[:=]\s*["']([^"']+)["']/).flatten.flat_map(&:split)

    abreviadas = sin_comentarios.scan(/^\s*(?:%[a-z][a-z0-9]*)?((?:\.[a-zA-Z0-9_-]+)+)/)
                                .flatten.flat_map { |c| c.split(".").reject(&:empty?) }

    (atributos + abreviadas).to_set
  end

  test "toda clase de botón usada en una vista está definida en la hoja de estilo" do
    definidas = HOJA.read.scan(/^\.(btn[a-z0-9-]*)/).flatten.to_set
    usadas    = VISTAS.flat_map { |r| self.class.clases_de(r.read).to_a }.grep(/\Abtn/).to_set

    huerfanas = usadas - definidas

    assert_empty huerfanas,
      "Estas clases de botón se usan en las vistas y no existen en system.css, " \
      "así que se dibujan como texto suelto: #{huerfanas.to_a.sort.join(', ')}"
  end

  # Bootstrap no está cargado. Cualquiera de estas se dibuja como nada.
  #
  # `d-flex`, `gap-1..3`, `align-items-center`, `justify-content-between|center`
  # y `text-center` NO están en la lista: son utilidades que `system.css` define
  # a propósito. Comparten nombre con Bootstrap y esa es toda la coincidencia.
  #
  # (Y el comentario va acá afuera y no adentro del `%w[]`, donde un `#` no
  # comenta nada: se vuelve un elemento más del arreglo.)
  BOOTSTRAP = %w[
    card card-body card-title card-text
    col-sm-3 col-sm-9 row
    table-striped table-bordered
    text-muted form-text
    bg-success bg-warning bg-danger badge
    justify-content-end
  ].to_set.freeze

  test "no quedan restos de Bootstrap en las vistas" do
    encontrados = VISTAS.filter_map do |ruta|
      sucias = self.class.clases_de(ruta.read) & BOOTSTRAP
      "#{ruta.relative_path_from(Rails.root)}: #{sucias.to_a.sort.join(', ')}" if sucias.any?
    end

    assert_empty encontrados,
      "Estas vistas usan clases de Bootstrap, que esta app no carga:\n  #{encontrados.join("\n  ")}"
  end
end
