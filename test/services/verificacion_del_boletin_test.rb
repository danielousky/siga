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
        issued_by: User.create!(name: "D", last_name: "T", email: "d@qr.test", password: "123123"),
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
end
