require "test_helper"

# El manual publicado: `/manual` y `/manual.pdf`.
class ManualTest < ActionDispatch::IntegrationTest
  test "el manual se abre sin cuenta" do
    get manual_path

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_match "Manual de SIGA", response.body
  end

  # ⚠️ `/manual.pdf` es la MISMA ruta con `format: :pdf` —el punto es el
  # separador del formato en Rails, siempre—. Una ruta aparte no se alcanzaría
  # nunca, y el PDF salía con el HTML adentro y `Content-Type: text/html`.
  test "el mismo enlace con .pdf entrega el PDF" do
    get manual_path(format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline/, response.headers["Content-Disposition"].to_s,
                 "en el teléfono un adjunto se baja a una carpeta que nadie encuentra")
    assert response.body.bytesize > 1_000_000, "un PDF de 72 páginas con capturas no pesa menos"
  end

  # ⚠️ Lo que justifica que no viva en `public/`: ahí el caché es de UN AÑO y el
  # navegador de un colegio se quedaría con el manual viejo hasta 2027.
  test "el manual NO se cachea un año" do
    get manual_path

    cache = response.headers["Cache-Control"].to_s
    assert_match(/max-age=(\d+)/, cache)
    assert cache[/max-age=(\d+)/, 1].to_i <= 1.day.to_i, "un documento que se corrige no se cachea un año: #{cache}"
  end

  test "el manual ofrece su propia descarga" do
    get manual_path

    assert_select "a[href=?]", "/manual.pdf"
  end

  # ⚠️ Las capturas van sueltas, no en base64: 3,5 MB que hay que bajar enteros
  # antes de la primera línea son 3,5 MB de nada en un colegio con mala señal.
  test "las capturas son archivos, no base64" do
    get manual_path

    assert_no_match(/src="data:image/, response.body)
    assert_select "img[src^=?]", "/manual/capturas/", minimum: 40
    assert_select "img[loading=lazy]", minimum: 40
  end

  test "el manual se anuncia en el sitemap y se enlaza desde la portada" do
    get sitemap_path
    assert_match %r{<loc>[^<]+/manual</loc>}, response.body

    get root_path
    assert_select "a[href=?]", manual_path
  end
end
