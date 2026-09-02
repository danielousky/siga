require "test_helper"

# Guardar es VERDE, eliminar es ROJO (MOR-207).
#
# Daniel: *«el tono de ese botón debe tender a verde, al igual que todos todos
# los submit, actuales y de ahora en más»* y *«el botón de eliminar debe tener un
# tono rojo»*.
#
# ⚠️ Esto MODIFICA la regla de color de `MOR-135`, que reservaba verde, rojo y
# ámbar para el DATO. Lo que cambia es el alcance, no la regla:
#
#     SIGUE SIENDO DEL DATO          PASA A SER DEL CONTROL
#     ─────────────────────          ──────────────────────
#     la nota en rojo del aplazado   el verde de GUARDAR
#     el ámbar de una anomalía       el rojo de ELIMINAR
#     los chips de estado
#
# Conviven porque no comparten forma: una nota en rojo es un número dentro de
# una tabla; el rojo de borrar es el fondo de un botón con una papelera.
class TonoDeLosBotonesTest < ActiveSupport::TestCase
  VISTAS = Rails.root.glob("app/views/**/*.haml").freeze

  test "ningún submit se quedó en azul" do
    azules = VISTAS.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        next unless linea.match?(/submit/)
        next unless linea.match?(/btn btn-primary/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 80]}"
      end
    end

    assert_empty azules,
      "submits que siguen en azul; guardar es verde (`btn-guardar`):\n  " + azules.join("\n  ")
  end

  # ⚠️ Los que llevan OTRO tono a propósito no entran: `btn-documento` para lo
  # que sale —«Emitir y descargar»— y `btn-accion` para lo que hace mucho de una
  # vez —«Promover a 200 alumnos»—. Esa distinción es de `MOR-172` y es la que
  # hace que un botón diga qué hace; volverlos verdes la borraría.
  test "los submits con tono propio lo conservan" do
    con_tono = VISTAS.flat_map do |vista|
      vista.read.lines.filter_map { |l| l[/btn-(documento|accion)/, 0] if l.match?(/submit/) }
    end

    assert_includes con_tono, "btn-documento", "«Emitir y descargar» es un documento, no un guardado"
    assert_includes con_tono, "btn-accion", "«Promover» hace mucho de una vez"
  end

  test "los dos tonos existen en la hoja de estilos" do
    hoja = Rails.root.join("app/assets/stylesheets/system.css").read

    assert_match(/^\.btn-guardar \{/, hoja)
    assert_match(/--guardar-primary:/, hoja)
    assert_match(/--eliminar-primary:/, hoja)
  end
end
