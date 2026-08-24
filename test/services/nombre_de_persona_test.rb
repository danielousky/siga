require "test_helper"

# Partir el nombre de una celda en apellidos y nombres (MOR-126).
#
# Esto ADIVINA. Lo que se prueba acá no es que acierte siempre —no puede— sino
# que acierte en los casos normales y que **avise** cuando no está seguro.
class NombreDePersonaTest < ActiveSupport::TestCase
  # ── el caso normal: apellidos primero ─────────────────────────────────────

  test "tres palabras: apellido, apellido, nombre" do
    n = NombreDePersona.new("BLANCO NIEVES PEDRO")

    assert_equal "PEDRO",  n.first_name
    assert_equal "BLANCO", n.last_name
    assert_equal "NIEVES", n.second_last_name
    assert n.seguro?
  end

  test "cuatro palabras: dos apellidos y dos nombres" do
    n = NombreDePersona.new("PÉREZ GÓMEZ ANA SOFÍA")

    assert_equal "ANA SOFÍA", n.first_name
    assert_equal "PÉREZ",     n.last_name
    assert_equal "GÓMEZ",     n.second_last_name
    assert n.seguro?
  end

  test "dos palabras: un apellido y un nombre" do
    n = NombreDePersona.new("SILVA ANA")

    assert_equal "ANA",   n.first_name
    assert_equal "SILVA", n.last_name
    assert_nil n.second_last_name
    assert n.seguro?
  end

  # ── las partículas ────────────────────────────────────────────────────────

  # ⚠️ El caso que rompe la versión ingenua. Partiendo por espacios, esta
  # persona queda con el apellido "DE" y el segundo apellido "LA".
  test "las partículas se pegan a la palabra que sigue" do
    n = NombreDePersona.new("DE LA CRUZ MARÍN JOSÉ LUIS")

    assert_equal "DE LA CRUZ", n.last_name
    assert_equal "MARÍN",      n.second_last_name
    assert_equal "JOSÉ LUIS",  n.first_name
  end

  test "una sola partícula también pega" do
    n = NombreDePersona.new("DEL VALLE ROJAS CARMEN")

    assert_equal "DEL VALLE", n.last_name
    assert_equal "ROJAS",     n.second_last_name
    assert_equal "CARMEN",    n.first_name
  end

  test "la partícula acentuada y en minúscula también cuenta" do
    n = NombreDePersona.new("de los Santos Pérez María")

    assert_equal "de los Santos", n.last_name
    assert_equal "Pérez",         n.second_last_name
  end

  # Un apellido cortado es un dato cortado. Dejarlo visible es mejor que
  # esconderlo pegándolo a un nombre.
  test "una partícula al final se queda sola" do
    n = NombreDePersona.new("PÉREZ DE")

    assert_equal "PÉREZ", n.last_name
    assert_equal "DE",    n.first_name
  end

  # ── cuándo NO está seguro ─────────────────────────────────────────────────

  # No se rechaza la fila: se señala para que alguien la mire en la
  # previsualización. Puede ser tres nombres, o un apellido compuesto que no
  # empieza por partícula, como "PÉREZ DE LEÓN".
  test "cinco unidades o más piden revisión" do
    n = NombreDePersona.new("RODRÍGUEZ LÓPEZ CARLOS ANDRÉS JOSÉ")

    assert_not n.seguro?
    assert_match(/revise/i, n.motivo)
  end

  test "una sola palabra no se puede repartir" do
    n = NombreDePersona.new("MARTÍNEZ")

    assert_not n.seguro?
    assert_equal "MARTÍNEZ", n.first_name
    assert_match(/no se sabe/i, n.motivo)
  end

  test "una celda vacía se marca" do
    n = NombreDePersona.new("   ")

    assert n.vacio?
    assert_not n.seguro?
  end

  test "cuatro palabras normales sí están seguras" do
    assert NombreDePersona.new("RODRÍGUEZ LÓPEZ CARLOS ANDRÉS").seguro?
  end

  # ── el orden lo dice el encabezado ────────────────────────────────────────

  # ⚠️ La MISMA celda con el MISMO contenido, leída al revés. Adivinarlo por el
  # contenido es imposible; leerlo del título de la columna acierta.
  test "con los nombres primero, el reparto se invierte" do
    n = NombreDePersona.new("JOSÉ LUIS DE LA CRUZ MARÍN", apellidos_primero: false)

    assert_equal "JOSÉ LUIS",  n.first_name
    assert_equal "DE LA CRUZ", n.last_name
    assert_equal "MARÍN",      n.second_last_name
  end

  test "dos palabras con los nombres primero" do
    n = NombreDePersona.new("ANA SILVA", apellidos_primero: false)

    assert_equal "ANA",   n.first_name
    assert_equal "SILVA", n.last_name
  end

  test "lee el orden del encabezado" do
    assert NombreDePersona.apellidos_primero?("APELLIDOS Y NOMBRES")
    assert NombreDePersona.apellidos_primero?("apellidos y nombres del alumno")
    assert NombreDePersona.apellidos_primero?("Apellidos")

    assert_not NombreDePersona.apellidos_primero?("NOMBRES Y APELLIDOS")
    assert_not NombreDePersona.apellidos_primero?("Nombre y Apellido")
  end

  # Sin pistas en el encabezado, la convención de las planillas del MPPE.
  test "sin pistas, apellidos primero" do
    assert NombreDePersona.apellidos_primero?("ALUMNO")
    assert NombreDePersona.apellidos_primero?("")
  end

  # ── limpieza ──────────────────────────────────────────────────────────────

  test "los espacios de más no crean apellidos fantasma" do
    n = NombreDePersona.new("  RODRÍGUEZ   LÓPEZ   CARLOS  ")

    assert_equal "RODRÍGUEZ", n.last_name
    assert_equal "LÓPEZ",     n.second_last_name
    assert_equal "CARLOS",    n.first_name
  end

  test "devuelve los tres campos listos para el modelo" do
    assert_equal({ first_name: "PEDRO", last_name: "BLANCO", second_last_name: "NIEVES" },
                 NombreDePersona.new("BLANCO NIEVES PEDRO").to_h)
  end
end
