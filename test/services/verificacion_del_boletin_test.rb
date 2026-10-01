require "test_helper"

# El pie del boletín: firma del colegio y código verificable (MOR-135).
class VerificacionDelBoletinTest < ActiveSupport::TestCase
  setup do
    @esc = escenario_academico(alumnos: 1)
    @boletin = con_el_colegio(@esc.colegio) do
      ReportCard.new(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1),
                     code: "BOL-ABC-123")
    end
  end

  def url = ReportCardPdf.new([]).send(:url_de_verificacion, @boletin)

  # Un papel impreso no tiene contexto: "/verificar/BOL-ABC-123" no le sirve a
  # nadie que escanee el código.
  test "el QR lleva la URL completa, no la ruta" do
    ENV["SIGA_HOST"] = "siga.example.com"
    assert_equal "https://siga.example.com/verificar/BOL-ABC-123", url
  ensure
    ENV.delete("SIGA_HOST")
  end

  # Sin esto, un boletín generado en desarrollo lleva un QR que apunta a
  # `https://localhost:3000` — o sea, a ninguna parte— y el error aparece recién
  # cuando alguien lo escanea.
  test "en local el QR no promete https" do
    ENV["SIGA_HOST"] = "localhost:3000"
    assert_equal "http://localhost:3000/verificar/BOL-ABC-123", url
  ensure
    ENV.delete("SIGA_HOST")
  end

  # Un QR que no se puede generar no puede tumbar un boletín: el código escrito
  # al lado es lo que de verdad verifica.
  test "el boletín se emite aunque el QR falle" do
    con_el_colegio(@esc.colegio) do
      boletin = ReportCard.create!(
        enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1),
        issued_by: User.create!(first_name: "D", last_name: "T", email: "d@qr.test", password: "123123",
                        document: "V-#{"d@qr.test".bytes.sum}"),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1))
      )

      # Se rompe la GENERACIÓN del QR, no el método que la envuelve: ahí adentro
      # está el `rescue` que este test quiere comprobar. Reemplazar
      # `dibujar_qr` lo eliminaría, y el test pasaría a probar lo contrario.
      original = RQRCodeCore::QRCode.method(:new)
      RQRCodeCore::QRCode.define_singleton_method(:new) { |*| raise "no se pudo generar el QR" }

      begin
        assert_nothing_raised { ReportCardPdf.new([boletin]).render }
      ensure
        RQRCodeCore::QRCode.define_singleton_method(:new, original)
      end
    end
  end

  # En el papel el sello se estampa SOBRE la firma: uno junto a una firma en
  # blanco se puede recortar y pegar en otro documento.
  test "el sello se dibuja después de la firma, para quedar encima" do
    codigo = Rails.root.join("app/services/report_card_pdf.rb").read
    cuerpo = codigo[/def firma\(pdf, boletin\).*?\n  end/m]

    assert cuerpo, "no se encontró el método `firma`"
    assert cuerpo.index("pdf.image escaneada") < cuerpo.index("sello(pdf, estampa"),
      "el sello tiene que dibujarse DESPUÉS de la firma: en un PDF lo último tapa lo anterior"
  end

  # Un sello opaco encima de la firma la borraría, que es lo contrario de lo que
  # se busca: la tinta del sello deja ver el trazo del bolígrafo debajo.
  test "el sello se dibuja con transparencia" do
    codigo = Rails.root.join("app/services/report_card_pdf.rb").read

    assert_match(/pdf\.transparent\(0\.\d+\)/, codigo[/def sello\(.*?\n  end/m].to_s,
      "el sello tiene que ir con transparencia para no tapar la firma")
  end

  # Un sello que no se puede dibujar no puede tumbar un boletín.
  test "el boletín se emite aunque el sello falle" do
    con_el_colegio(@esc.colegio) do
      @esc.colegio.sello.attach(io: StringIO.new("no soy un png"), filename: "s.png", content_type: "image/png")

      boletin = ReportCard.create!(
        enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1),
        issued_by: User.create!(first_name: "D", last_name: "S", email: "d@sello.test", password: "123123",
                        document: "V-#{"d@sello.test".bytes.sum}"),
        snapshot: ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1))
      )

      assert_nothing_raised { ReportCardPdf.new([boletin]).render }
    end
  end

  # ── El pie no se corta contra el borde de la hoja ─────────────────────────
  #
  # Daniel, 1 de octubre de 2026, con el PDF de 4to Grado A abierto: *«se está
  # cortando el foot de algunos documentos»*. El código de verificación quedaba
  # a media línea contra el borde del papel y el QR partido por la mitad.
  #
  #     …
  #     ───────────────────────────────
  #     Código de verificación: BOL-NAYC-XVCV          ▓▓▓▓▓
  #     Cualquiera puede comprobar este b…             ▓▓▓▓▓
  #     ═════════════ borde de la hoja ═════════════════════
  #
  # Pasaba en «algunos» porque depende de DÓNDE termina la tabla: el texto de
  # arriba salta solo a la hoja siguiente cuando no cabe, pero el bloque del
  # código es una caja de alto fijo y el QR son cuadros con coordenadas — Prawn
  # los dibuja donde se le dice, también fuera del papel.
  #
  # ⚠️ Por eso el test BARRE la cantidad de materias: el corte solo aparece en
  # una franja de alturas, y con un boletín de ejemplo cualquiera el test pasa
  # en verde con el error adentro — que es como estuvo todo este tiempo.
  #
  # ⚠️ Y mira COORDENADAS, no texto: lo que no puede pasar es que algo se pinte
  # por debajo del margen inferior, y eso está escrito en el PDF como números.
  test "el pie nunca se pinta por debajo del margen, termine donde termine la tabla" do
    con_el_colegio(@esc.colegio) do
      base = ReportCardData.para(enrollment: @esc.inscripcion(1), evaluation_moment: @esc.lapso(1))

      (12..44).each do |cuantas|
        @boletin.snapshot = base.merge(
          "materias" => Array.new(cuantas) { |i| { "materia" => "Materia #{i + 1}", "nota" => 15 } }
        )

        mas_bajo = lo_mas_bajo_de(ReportCardPdf.new([ @boletin ]).render)

        assert_operator mas_bajo, :>=, ReportCardPdf::MARGEN - 1,
                        "con #{cuantas} materias algo se pinta a #{mas_bajo.round} pt del borde: " \
                        "por debajo del margen de #{ReportCardPdf::MARGEN}, o sea cortado"
      end
    end
  end

  private

  # La coordenada más baja en la que el PDF pinta un rectángulo o escribe un
  # texto, en puntos desde el borde inferior de la hoja.
  #
  # Prawn escribe sin comprimir, así que las órdenes están a la vista:
  #
  #     x y ancho alto re     un rectángulo, con `y` en su borde de ABAJO
  #     x y Td                dónde arranca un renglón de texto
  def lo_mas_bajo_de(pdf)
    contenido = pdf.b
    rectangulos = contenido.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\b/).map { |_, y, _, _| y.to_f }
    renglones   = contenido.scan(/(-?[\d.]+) (-?[\d.]+) Td\b/).map { |_, y| y.to_f }

    (rectangulos + renglones).min
  end
end
