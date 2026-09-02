require "test_helper"

# La firma del director, escaneada (MOR-135).
#
# ⚠️ NO es una firma digital: es un facsímil, como el sello de goma. Lo que hace
# comprobable un boletín es su código de verificación y el QR.
class FirmaDelColegioTest < ActiveSupport::TestCase
  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "U.E. Firma", dea_code: "FIR001", location: "Caracas")
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

  # ── El sello ──────────────────────────────────────────────────────────────

  test "el sello se valida como la firma" do
    @colegio.sello.attach(io: StringIO.new("x"), filename: "s.gif", content_type: "image/gif")

    assert_not @colegio.valid?
    assert_match(/PNG o JPG/, @colegio.errors[:sello].first)
  end

  test "un sello ilegible devuelve nil en vez de explotar" do
    assert_nil @colegio.sello_para_pdf

    @colegio.sello.attach(io: StringIO.new("x"), filename: "s.svg", content_type: "image/svg+xml")
    assert_nil @colegio.sello_para_pdf
  end

  # Los tres adjuntos comparten la misma validación: si una cambia, cambian las
  # tres. Antes el logo tenía la suya escrita aparte y la firma habría quedado
  # atrás el día que cambiaran las reglas.
  test "escudo, firma y sello comparten validación" do
    %i[logo firma sello].each do |campo|
      colegio = Current.sin_aislamiento do
        School.create!(name: "U.E. #{campo}", dea_code: "V#{campo}", location: "Caracas")
      end
      colegio.public_send(campo).attach(io: StringIO.new("x" * (School::PESO_MAXIMO + 1)),
                                        filename: "x.png", content_type: "image/png")

      assert_not colegio.valid?, "#{campo} debería rechazar un archivo de más de 2 MB"
      assert_match(/2 MB/, colegio.errors[campo].first)
    end
  end
end
