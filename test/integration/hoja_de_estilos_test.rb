require "test_helper"

# La hoja de estilos, revisada por lo que el navegador NO avisa (MOR-149).
#
# ## Por qué existe
#
# Escribí el desplegable del menú del teléfono con `background:
# var(--surface-raised)` y `box-shadow: var(--shadow-md)`. Ninguna de las dos
# existe en este proyecto —la superficie se llama `--surface-elevated`, y las
# sombras van literales—, así que ese desplegable habría salido **transparente y
# sin sombra**, con sus enlaces encima de la tabla de alumnos.
#
# Lo peor es cómo falla: el CSS ignora en silencio una variable que no existe.
# No lo atrapa el CI, ni el HTML, ni mirar la página en escritorio. Solo se ve
# abriendo esa pantalla, en un teléfono.
#
# Va con `controladores_registrados_test`: los dos cruzan lo que un archivo
# DECLARA contra lo que otro DEFINE, que es donde este proyecto se rompe en
# silencio.
class HojaDeEstilosTest < ActiveSupport::TestCase
  # `var(--x)` y `var(--x, algo)`.
  USOS = /var\(\s*(--[a-zA-Z0-9-]+)/
  # Una definición es `--x:` al empezar una declaración: dentro de un bloque,
  # después de un punto y coma, o abriendo un `style` en línea. Así no se
  # confunde con un uso.
  DEFINICIONES = /(?:^\s*|[;{"']\s*)(--[a-zA-Z0-9-]+)\s*:/

  test "toda variable CSS que se usa está definida" do
    hojas.each do |hoja|
      css = hoja.read
      usadas = css.scan(USOS).flatten.uniq

      huerfanas = usadas.reject { |variable| definidas.include?(variable) }

      assert_empty huerfanas,
                   "#{hoja.basename} usa variables que nadie define: " \
                   "#{huerfanas.join(', ')}. El CSS las ignora en silencio, así que " \
                   "lo que dependa de ellas sale sin color, sin sombra o sin " \
                   "espaciado — y solo se nota mirando esa pantalla."
    end
  end

  private

  # ⚠️ No todas se definen en el CSS.
  #
  # `--avatar-color` sale de Ruby, en un `style` en línea: el color de un avatar
  # depende del NOMBRE de la persona, y eso no se puede escribir en una hoja
  # estática. Se buscan también ahí en vez de llevar una lista de excepciones a
  # mano — una lista hay que acordarse de actualizarla, y nadie se acuerda.
  def definidas
    @definidas ||= begin
      fuentes = hojas + Rails.root.glob("app/{helpers,views}/**/*.{rb,haml}")

      fuentes.flat_map { |archivo| archivo.read.scan(DEFINICIONES).flatten }.to_set
    end
  end

  def hojas
    archivos = Rails.root.glob("app/assets/stylesheets/*.css")
    assert archivos.any?, "no se encontró ninguna hoja de estilos"
    archivos
  end

  # ⚠️ El tooltip del navegador no se usa (MOR-173).
  #
  # Daniel: «mira el tooltip, es de HTML puro. Revisalos todos». El `title`
  # nativo no se puede estilar, tarda un segundo largo en aparecer, sale con la
  # tipografía del sistema y **en el teléfono no existe** — que es donde un
  # profesor carga notas.
  #
  # `data-tooltip` lo reemplaza, con `:focus-visible` además del hover para que
  # quien navega con teclado también lo lea.
  test "ninguna vista usa el tooltip nativo del navegador" do
    nativos = (Rails.root.glob("app/views/**/*.haml") + Rails.root.glob("app/javascript/**/*.js")).filter_map do |ruta|
      texto = ruta.read
      # `title:` de un `link_to`/`text_field`, o `.title =` desde JavaScript.
      next unless texto.match?(/[^_a-z]title:\s*["']/) || texto.match?(/\.title\s*=/)

      ruta.relative_path_from(Rails.root).to_s
    end

    assert_empty nativos,
      "usan el `title` del navegador en vez de `data-tooltip`:\n  " + nativos.join("\n  ")
  end
end
