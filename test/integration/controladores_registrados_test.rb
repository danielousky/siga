require "test_helper"

# Todo `data-controller` de una vista tiene que estar registrado (MOR-149).
#
# ## Por qué existe este test
#
# El buscador de `⌘K` y el menú encogible se entregaron **rotos**: el HTML estaba
# perfecto, el CSS estaba perfecto, el JavaScript estaba escrito — y ninguno de
# los dos se registró en `controllers/index.js`.
#
# Lo peor no fue el olvido: fue que **no se notaba desde el servidor**. Stimulus
# no protesta cuando encuentra un `data-controller` que no conoce, así que el
# HTML se veía correcto en cada verificación que hice. Yo confirmé que el botón
# estaba en la página y di por hecho que funcionaba. Solo se descubre haciendo
# clic, y eso lo hizo Daniel.
#
# Este test hace lo que yo no hice: cruzar lo que las vistas declaran contra lo
# que el JavaScript registra.
class ControladoresRegistradosTest < ActiveSupport::TestCase
  # Las tres formas en que una vista Haml puede declarar un controlador:
  #
  #     %div{"data-controller": "busqueda"}
  #     %div{data: {controller: "asistencia"}}
  #     .card{data: { controller: "carga-notas", ... }}
  DECLARACIONES = /(?:"data-controller":|data-controller=|controller:)\s*"([^"]+)"/

  test "todo controlador declarado en una vista está registrado en index.js" do
    registro = Rails.root.join("app/javascript/controllers/index.js").read

    declarados.each do |nombre, donde|
      assert_includes registro, "application.register(\"#{nombre}\"",
                      "«#{nombre}» se declara en #{donde} y NO está registrado en " \
                      "controllers/index.js. Stimulus lo ignora en silencio: el HTML se " \
                      "ve bien y no pasa nada al hacer clic."
    end
  end

  # El otro lado del mismo error: un archivo de controlador que nadie importa es
  # código muerto que parece vivo.
  test "todo archivo de controlador está registrado" do
    registro = Rails.root.join("app/javascript/controllers/index.js").read

    Dir[Rails.root.join("app/javascript/controllers/*_controller.js")].each do |ruta|
      archivo = File.basename(ruta)
      nombre = archivo.sub("_controller.js", "").tr("_", "-")

      assert_includes registro, "application.register(\"#{nombre}\"",
                      "existe #{archivo} y nadie lo registra: es código muerto que " \
                      "parece vivo."
    end
  end

  # ⚠️ El caso concreto que se rompió: los dos controladores del rediseño.
  #
  # Se nombran a mano y no por descubrimiento para que borrar uno por accidente
  # haga fallar el test en vez de reducirlo a cero comprobaciones.
  test "el buscador global y el menú encogible están conectados" do
    registro = Rails.root.join("app/javascript/controllers/index.js").read

    assert_includes registro, "application.register(\"busqueda\"",
                    "el buscador de ⌘K no responde si no está registrado"
    assert_includes registro, "application.register(\"sidebar\"",
                    "el botón de encoger el menú no hace nada si no está registrado"
  end

  private

  def declarados
    Dir[Rails.root.join("app/views/**/*.haml")].flat_map do |ruta|
      corta = ruta.sub("#{Rails.root}/", "")

      File.read(ruta).scan(DECLARACIONES).flatten.flat_map(&:split).uniq.map { |n| [ n, corta ] }
    end.uniq
  end
end
