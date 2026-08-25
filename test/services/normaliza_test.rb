require "test_helper"

class NormalizaTest < ActiveSupport::TestCase
  # ── el sexo, que depende de la columna entera ─────────────────────────────

  test "M y F es masculino y femenino" do
    mapa = Normaliza.sexos(%w[M F M F])

    assert_equal :male,   mapa["m"]
    assert_equal :female, mapa["f"]
  end

  # La convención de las planillas del MPPE.
  test "V y H es varón y hembra" do
    mapa = Normaliza.sexos(%w[V H V])

    assert_equal :male,   mapa["v"]
    assert_equal :female, mapa["h"]
  end

  # ⚠️ El caso que obliga a mirar la columna entera y no cada celda.
  #
  # En hombre/mujer, la H es MASCULINA y la M es FEMENINA — exactamente al revés
  # de las otras dos convenciones. Leyendo celda por celda, un colegio que usa
  # esta escala queda con todos los sexos invertidos, en silencio.
  test "H y M juntas es hombre y mujer, o sea al revés" do
    mapa = Normaliza.sexos(%w[H M H M])

    assert_equal :male,   mapa["h"]
    assert_equal :female, mapa["m"]
  end

  test "sin la M, la H sigue siendo hembra" do
    mapa = Normaliza.sexos(%w[V H])

    assert_equal :female, mapa["h"]
  end

  test "entiende la palabra completa y no le importan los acentos" do
    mapa = Normaliza.sexos([ "Masculino", "FEMENINO", "varón", "Hembra" ])

    assert_equal :male,   mapa["masculino"]
    assert_equal :female, mapa["femenino"]
    assert_equal :male,   mapa["varon"]
    assert_equal :female, mapa["hembra"]
  end

  test "lo que no se entiende queda en nulo" do
    mapa = Normaliza.sexos([ "N/A", "?", "" ])

    assert_nil mapa["n/a"]
    assert_nil mapa["?"]
    assert_not mapa.key?("")
  end

  test "una celda suelta usa la convención del MPPE" do
    assert_equal :male,   Normaliza.sexo("V")
    assert_equal :female, Normaliza.sexo("H")
    assert_equal :male,   Normaliza.sexo("M")
    assert_nil Normaliza.sexo("")
  end

  # ── el correo ─────────────────────────────────────────────────────────────

  test "el correo se guarda en minúscula y sin espacios" do
    assert_equal "maria.marin@gmail.com", Normaliza.correo("  Maria.Marin@Gmail.com ")
  end

  # Media dirección no sirve para nada y ocupa el índice único.
  test "lo que no es un correo se descarta" do
    [ "correo-malo", "n/a", "sin correo", "@gmail.com", "maria@", "maria@gmail" ].each do |basura|
      assert_nil Normaliza.correo(basura), "#{basura.inspect} no debería pasar"
    end
  end

  test "una celda vacía no es un correo" do
    assert_nil Normaliza.correo("")
    assert_nil Normaliza.correo(nil)
  end

  # ── el teléfono ───────────────────────────────────────────────────────────

  # No se normaliza a un formato: en Venezuela conviven varios y todos sirven
  # para llamar. Inventarle un canónico solo destruye información.
  test "el teléfono se guarda como lo escribió el colegio" do
    assert_equal "0414-1234567",     Normaliza.telefono(" 0414-1234567 ")
    assert_equal "(0212) 555-1234",  Normaliza.telefono("(0212)  555-1234")
    assert_equal "+58 414 1234567",  Normaliza.telefono("+58  414  1234567")
    assert_nil Normaliza.telefono("  ")
  end
end
