require "test_helper"

# Leer fechas de una planilla, en formato venezolano (MOR-126).
class FechaDePlanillaTest < ActiveSupport::TestCase
  # ── día/mes/año ───────────────────────────────────────────────────────────

  test "lee día/mes/año" do
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new("12/03/2014").fecha
  end

  test "acepta el día y el mes sin cero adelante" do
    assert_equal Date.new(2013, 7, 3), FechaDePlanilla.new("3/7/2013").fecha
  end

  test "acepta guiones y puntos como separador" do
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new("12-03-2014").fecha
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new("12.03.2014").fecha
  end

  test "lee el formato ISO" do
    assert_equal Date.new(2014, 5, 20), FechaDePlanilla.new("2014-05-20").fecha
  end

  # ── el peligro silencioso ─────────────────────────────────────────────────

  # ⚠️ Esto es lo más importante de esta clase.
  #
  # `03/12/2014` parsea bien leído como día/mes (3 de diciembre) Y leído como
  # mes/día (12 de marzo). Si la planilla salió de un Excel en inglés, TODAS las
  # fechas con día y mes ≤ 12 quedan cambiadas y nadie se entera. No se puede
  # resolver mirando el dato — se puede CONTAR y preguntar.
  test "marca como ambigua la fecha que se leería distinto en un Excel en inglés" do
    assert FechaDePlanilla.new("03/12/2014").ambigua?
    assert FechaDePlanilla.new("12/03/2014").ambigua?
  end

  # Con un día mayor a 12 no hay dos lecturas: no existe el mes 22. Por eso
  # basta con que UNA fecha del archivo sea inequívoca para saber en qué formato
  # está todo.
  test "no es ambigua cuando el día pasa de 12" do
    assert_not FechaDePlanilla.new("22/11/2014").ambigua?
    assert_not FechaDePlanilla.new("31/01/2014").ambigua?
  end

  test "no es ambigua cuando el día y el mes son iguales" do
    assert_not FechaDePlanilla.new("05/05/2014").ambigua?
  end

  test "el formato ISO nunca es ambiguo" do
    assert_not FechaDePlanilla.new("2014-03-12").ambigua?
  end

  # ── lo que ya viene como fecha ────────────────────────────────────────────

  # roo devuelve objetos `Date` para las celdas con formato de fecha de un
  # .xlsx. Volver a parsearlas como texto sería inventar un problema.
  test "deja pasar lo que ya es una fecha" do
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new(Date.new(2014, 3, 12)).fecha
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new(Time.zone.local(2014, 3, 12, 10, 30)).fecha
  end

  # ── el número de serie de Excel ───────────────────────────────────────────

  test "traduce el número de serie de Excel" do
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new(41_710).fecha
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new("41710").fecha
  end

  # ⚠️ Sin acotar el rango, un año suelto se leería como número de serie: `2014`
  # daría el 7 de julio de 1905, que es una fecha perfectamente válida y
  # perfectamente falsa.
  test "un año suelto no es un número de serie" do
    fecha = FechaDePlanilla.new("2014")

    assert_not fecha.valida?
    assert_match(/no parece una fecha/, fecha.motivo)
  end

  # ── el año de dos dígitos ─────────────────────────────────────────────────

  test "el año de dos dígitos que caería en el futuro es del siglo pasado" do
    # Un alumno nacido en 2014.
    assert_equal Date.new(2014, 3, 12), FechaDePlanilla.new("12/03/14").fecha
    # Una profesora nacida en 1980 — con 2080 estaría en el futuro.
    assert_equal Date.new(1980, 6, 15), FechaDePlanilla.new("15/06/80").fecha
  end

  # ── lo que no se puede leer ───────────────────────────────────────────────

  test "una celda vacía no es un error" do
    fecha = FechaDePlanilla.new("")

    assert fecha.vacia?
    assert_not fecha.valida?
    assert_nil fecha.motivo
  end

  test "un día que no existe se rechaza con su motivo" do
    fecha = FechaDePlanilla.new("31/02/2014")

    assert_not fecha.valida?
    assert_match(/no es una fecha que exista/, fecha.motivo)
  end

  test "un texto cualquiera se rechaza" do
    fecha = FechaDePlanilla.new("sin fecha")

    assert_not fecha.valida?
    assert_match(/no parece una fecha/, fecha.motivo)
  end

  test "se muestra en el formato en que la escribió el colegio" do
    assert_equal "12/03/2014", FechaDePlanilla.new("2014-03-12").to_s
  end
end
