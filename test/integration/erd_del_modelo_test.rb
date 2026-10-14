require "test_helper"
require "rake"

# El ERD se GENERA, y tiene que seguir siendo Mermaid válido.
#
# ## Por qué esto necesita un test
#
# El documento «Modelo de datos» de Linear tenía el diagrama escrito a mano y
# envejeció exactamente como el propio `modelo.rake` advierte que envejecen las
# cosas escritas a mano: decía «27 tablas de dominio · 22 con RLS» cuando ya eran
# 31 y 26, y seguía dibujando el profesor guía colgado del GRADO tres semanas
# después de haberlo movido a la sección.
#
# ⚠️ Y un diagrama roto **no falla**: Mermaid no renderiza y el documento queda
# con un bloque de código en bruto que nadie mira dos veces. Por eso lo que se
# prueba es la SINTAXIS, no que la tarea corra.
class ErdDelModeloTest < ActiveSupport::TestCase
  # ⚠️ Sin `Rails.application.load_tasks` la tarea no existe en el proceso de
  # test, y `Rake::Task[]` levanta — que se vería como un test roto y no como un
  # ERD roto.
  def erd
    @@erd ||= begin
      Rails.application.load_tasks unless Rake::Task.task_defined?("modelo:erd")
      salida = StringIO.new
      $stdout = salida
      Rake::Task["modelo:erd"].invoke
      $stdout = STDOUT
      salida.string
    end
  end

  def cuerpo = erd[/```mermaid\n(.*)\n```/m, 1].lines.map(&:chomp)

  test "sale un bloque mermaid con su erDiagram" do
    assert_match(/\A```mermaid\n/, erd)
    assert_equal "erDiagram", cuerpo.first
  end

  # Cada relación tiene la forma que Mermaid espera. Una sola mal formada tumba
  # el diagrama ENTERO, no solo su línea.
  test "todas las relaciones están bien formadas" do
    relaciones = cuerpo.grep(/\|\|--/)

    assert_operator relaciones.size, :>, 40, "faltan relaciones: algo dejó de leerse"
    malas = relaciones.reject { |l| l.match?(/\A    \w+ \|\|--o[|{] \w+ : ".*"\z/) }
    assert_empty malas, "relaciones que Mermaid no va a parsear:\n#{malas.join("\n")}"
  end

  # ⚠️ El tipo NO puede traer paréntesis ni espacios: `numeric(5,2)` rompe el
  # parseo por la coma, y pasó.
  test "todos los atributos están bien formados" do
    atributos = cuerpo.select { |l| l.start_with?("        ") }

    assert_operator atributos.size, :>, 150
    malos = atributos.reject { |l| l.match?(/\A        \w+ \w+( PK| FK| UK)?( ".*")?\z/) }
    assert_empty malos, "atributos que Mermaid no va a parsear:\n#{malos.join("\n")}"
  end

  test "las llaves de cada entidad abren y cierran" do
    assert_equal cuerpo.count { |l| l.end_with?("{") },
                 cuerpo.count { |l| l.strip == "}" }
  end

  # Una relación hacia una tabla sin bloque de atributos la dibuja Mermaid como
  # una caja vacía y sin nombre: se ve como un error de datos y no lo es.
  test "ninguna relación apunta a una entidad sin declarar" do
    declaradas = cuerpo.filter_map { |l| l[/\A    (\w+) \{\z/, 1] }.to_set
    referidas = cuerpo.grep(/\|\|--/).flat_map { |l| l.scan(/\A    (\w+) \|\|--o[|{] (\w+) :/).flatten }

    assert_empty referidas.uniq - declaradas.to_a
  end

  # ⚠️ El guarda que evita que el diagrama envejezca: si aparece una tabla nueva
  # y nadie la ubica en `ORDEN`, cae al final del diagrama sin que nadie lo note.
  test "toda tabla de dominio está ubicada en el orden de lectura" do
    declaradas = cuerpo.filter_map { |l| l[/\A    (\w+) \{\z/, 1] }
    # `ORDEN` se define dentro del `namespace :modelo` de un `.rake`, y en Ruby
    # una constante asignada dentro de un bloque queda en el TOPE léxico — o sea
    # que es `::ORDEN`. Es el mismo estilo que ya tenía `RUTA` en ese archivo.
    sin_ubicar = declaradas - ::ORDEN

    assert_empty sin_ubicar,
                 "tablas nuevas sin lugar en `ORDEN` de modelo.rake: #{sin_ubicar.join(', ')}"
  end

  # ⚠️ El diagrama del REPO está al día con el esquema (13 de octubre de 2026).
  #
  # Daniel, sobre los diagramas ER de febrero que vivían en la carpeta madre:
  # *«el diagrama ER, actualizarlo siempre»*. Generarlo bien no alcanzaba —eso
  # ya lo cuidan los tests de arriba—: nadie lo corría. Ahora vive escrito en
  # `docs/modelo/`, y una migración que no lo regenera pone el CI en rojo.
  test "docs/modelo/diagrama-er.md es el diagrama de hoy" do
    escrito = Rails.root.join("docs/modelo/diagrama-er.md")

    assert escrito.exist?, "falta docs/modelo/diagrama-er.md: corra `bin/rails modelo:documentos`"
    assert_equal erd, escrito.read,
                 "el esquema cambió y el diagrama no: corra `bin/rails modelo:documentos`, que " \
                 "regenera docs/modelo/ y el PDF, y súbalos con la migración"
  end
end
