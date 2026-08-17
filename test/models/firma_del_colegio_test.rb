require "test_helper"

# La firma del director, escaneada (MOR-135).
#
# ⚠️ NO es una firma digital: es un facsímil, como el sello de goma. Lo que hace
# comprobable un boletín es su código de verificación y el QR.
class FirmaDelColegioTest < ActiveSupport::TestCase
  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "U.E. Firma", dea_code: "FIR-001", location: "Caracas", school_type: :secondary)
    end
  end

  def adjuntar(nombre, tipo, bytes = "x")
    @colegio.firma.attach(io: StringIO.new(bytes), filename: nombre, content_type: tipo)
  end

  test "acepta PNG y JPG, que son los que Prawn imprime" do
    adjuntar("firma.png", "image/png")
    assert @colegio.valid?, @colegio.errors.full_messages.to_sentence
  end

  test "rechaza un formato que no se puede imprimir" do
    adjuntar("firma.svg", "image/svg+xml")

    assert_not @colegio.valid?
    assert_match(/PNG o JPG/, @colegio.errors[:firma].first)
  end

  test "rechaza un archivo pesado: la conexión de un colegio no lo aguanta" do
    adjuntar("firma.png", "image/png", "x" * (School::PESO_MAXIMO + 1))

    assert_not @colegio.valid?
    assert_match(/2 MB/, @colegio.errors[:firma].first)
  end

  # Un documento oficial no se puede caer porque alguien subió una imagen rara:
  # sale sin firma, que es feo pero sirve.
  test "una firma ilegible devuelve nil en vez de explotar" do
    assert_nil @colegio.firma_para_pdf

    adjuntar("firma.svg", "image/svg+xml")
    assert_nil @colegio.firma_para_pdf, "un formato no imprimible no debe llegar a Prawn"
  end

  # El escudo y la firma comparten validación: si una se rompe, la otra también.
  test "el escudo sigue validándose igual" do
    @colegio.logo.attach(io: StringIO.new("x"), filename: "l.gif", content_type: "image/gif")

    assert_not @colegio.valid?
    assert_match(/PNG o JPG/, @colegio.errors[:logo].first)
  end
end
