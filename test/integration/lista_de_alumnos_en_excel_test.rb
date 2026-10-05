require "test_helper"

# La lista de alumnos de una sección, en Excel (`.xlsx`).
#
# Un colegio venezolano vive de listas en papel —la de la cartelera, la de
# coordinación, la de la salida pedagógica, la del MPPE— y la de SIGA estaba
# SOLO en pantalla: la secretaria la volvía a tipear, y desde ahí las dos listas
# empiezan a separarse.
#
#     /secciones/12/alumnos.xlsx   una sección   · quien ve la sección
#     /secciones.xlsx              el colegio    · solo la dirección
#
# ⚠️ `.xlsx` de verdad y no un CSV renombrado: un CSV no dice con qué está
# separado y Excel en español NO usa coma — el archivo abre con todo en una
# columna o con los acentos rotos.
class ListaDeAlumnosEnExcelTest < ActionDispatch::IntegrationTest
  EXCEL = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    sign_in @a.director
  end

  def hoja_de(cuerpo)
    archivo = Tempfile.new([ "lista", ".xlsx" ], binmode: true)
    archivo.write(cuerpo)
    archivo.flush
    Roo::Excelx.new(archivo.path)
  end

  # Los archivos de imagen que el libro lleva adentro, con su peso. Un `.xlsx`
  # es un zip, y las imágenes viven en `xl/media/`.
  #
  # ⚠️ El resultado se saca de ADENTRO del bloque: `open_buffer` con bloque no
  # devuelve lo que el bloque calcula.
  def imagenes_de(cuerpo)
    imagenes = nil
    Zip::File.open_buffer(StringIO.new(cuerpo)) do |zip|
      imagenes = zip.entries.select { |entrada| entrada.name.start_with?("xl/media/") }.to_h { |e| [ e.name, e.size ] }
    end
    imagenes
  end

  def ponerle_escudo_al_colegio
    con_el_colegio(@a.colegio) do
      @a.colegio.logo.attach(io: File.open(Rails.root.join("app/assets/images/escudo_vzla.png")),
                             filename: "escudo.png", content_type: "image/png")
    end
  end

  # ── Con el escudo del colegio ─────────────────────────────────────────────
  #
  # Daniel, 5 de octubre de 2026, al pulsar «Descargar las listas»: un
  # `IOError: closed stream` en vez del Excel. El colegio de la demostración
  # tenía escudo; los de estos tests, hasta hoy, ninguno — y con escudo es como
  # está todo colegio de verdad.
  #
  # ⚠️ Lo que fallaba no era armar el libro: era CERRAR LA PETICIÓN. La
  # miniatura del escudo se pedía como una variante de Active Storage, que se
  # guarda al confirmar la transacción — y acá la transacción es la petición
  # entera (`con_el_colegio_de_la_sesion`). Para entonces el archivo temporal
  # de la miniatura ya no existía. Y ni siquiera llegaba a usarse: el libro
  # salía SIN escudo, porque al pedirla todavía no estaba guardada.
  test "con escudo cargado, la lista se descarga por las dos puertas — y lo lleva" do
    ponerle_escudo_al_colegio
    original = @a.colegio.logo.blob.byte_size

    { "una sección" => alumnos_section_path(@a.seccion, format: :xlsx),
      "el colegio"  => sections_path(format: :xlsx) }.each do |cual, ruta|
      get ruta

      assert_response :success, "la descarga de #{cual} se cayó con el escudo cargado"
      assert_equal EXCEL, response.media_type

      imagenes = imagenes_de(response.body)
      assert_equal 1, imagenes.size, "la lista de #{cual} salió sin el escudo"
      # Reducido: el que sube un colegio pesa hasta 2 MB, y va uno por hoja.
      assert_operator imagenes.values.first, :<, original / 2,
                      "el escudo de la lista de #{cual} va sin reducir: #{imagenes.values.first} de #{original} bytes"
    end
  end

  # ⚠️ Nada de lo que arma la lista puede quedar pendiente «para cuando se
  # confirme la transacción»: dentro de una petición, eso es cuando ya terminó.
  test "bajar la lista no deja variantes del escudo a medio guardar" do
    ponerle_escudo_al_colegio

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      get sections_path(format: :xlsx)
      get sections_path(format: :xlsx)
    end

    assert_response :success
    assert_equal 1, imagenes_de(response.body).size, "la segunda descarga también lleva su escudo"
  end

  # ⚠️ Una planilla sin escudo sirve; una que no se descarga, no. `ruby-vips`
  # levanta `LoadError` cuando `libvips` no está instalada —pasó en el CI de
  # GitHub— y eso NO es un `StandardError`: un `rescue` a secas lo deja pasar.
  test "sin la librería de imágenes, la lista baja igual — sin escudo" do
    ponerle_escudo_al_colegio
    de_verdad = ActiveStorage::Variation.instance_method(:transform)
    ActiveStorage::Variation.define_method(:transform) { |*| raise LoadError, "Could not open library 'vips.so.42'" }

    get sections_path(format: :xlsx)

    assert_response :success
    assert_empty imagenes_de(response.body)
  ensure
    ActiveStorage::Variation.define_method(:transform, de_verdad)
  end

  # ── Una sección ───────────────────────────────────────────────────────────

  test "la pestaña de alumnos se descarga en Excel" do
    get alumnos_section_path(@a.seccion, format: :xlsx)

    assert_response :success
    assert_equal EXCEL, response.media_type
    assert_match(/filename=".*\.xlsx"/, response.headers["Content-Disposition"])
  end

  test "lleva el membrete, los encabezados y a cada alumno" do
    get alumnos_section_path(@a.seccion, format: :xlsx)
    hoja = hoja_de(response.body)

    # El membrete: colegio, sección y año. Sin la fecha, una lista impresa se
    # confunde con la del mes pasado.
    assert_equal @a.colegio.name, hoja.cell(1, 2)
    assert_match(/#{@a.seccion.grade.name}/, hoja.cell(3, 2))
    assert_match(/#{@a.seccion.academic_period.name}/, hoja.cell(3, 2))
    assert_match(/alumnos inscritos/, hoja.cell(4, 2))

    # Los encabezados, en la fila 6, que es donde empieza la tabla.
    encabezados = (1..ListaDeAlumnosXlsx::COLUMNAS.size).map { |c| hoja.cell(6, c) }
    assert_equal ListaDeAlumnosXlsx::COLUMNAS.map(&:titulo), encabezados

    # Y el alumno, con su número de orden.
    assert_equal 1, hoja.cell(7, 1)
    assert_equal @a.escenario.alumno.user.apellidos, hoja.cell(7, 2)
  end

  test "lleva al representante y su teléfono, que es para lo que se baja" do
    con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Carmen", last_name: "Pérez",
                             email: "carmen.#{@a.colegio.id}@familia.test",
                             document: "V-#{@a.colegio.id}66", document_type: :cedula_v)
      representante = Representative.create!(user: usuario, school: @a.colegio, phone: "0414-1234567")
      StudentRepresentative.create!(student: @a.escenario.alumno, representative: representante,
                                    parentesco: :madre, principal: true)
    end

    get alumnos_section_path(@a.seccion, format: :xlsx)
    fila = hoja_de(response.body).row(7)

    assert_includes fila, "Carmen Pérez"
    assert_includes fila, "Madre"
    assert_includes fila, "0414-1234567"
  end

  # ⚠️ La cédula sale ESCRITA como se dice —«V-12345678»— y no como vive en la
  # columna, que es solo el número: la nacionalidad es `document_type`.
  test "la cédula sale con su sigla" do
    con_el_colegio(@a.colegio) do
      @a.escenario.alumno.user.update!(document: "28123456", document_type: :cedula_v)
    end

    get alumnos_section_path(@a.seccion, format: :xlsx)

    assert_includes hoja_de(response.body).row(7), "V-28123456"
  end

  # ── El colegio entero ─────────────────────────────────────────────────────

  test "el listado de secciones baja una hoja por sección" do
    otra = con_el_colegio(@a.colegio) do
      Section.create!(grade: @a.seccion.grade, academic_period: @a.seccion.academic_period,
                      name: "Z", capacity: 30)
    end

    get sections_path(format: :xlsx)

    assert_response :success
    hojas = hoja_de(response.body).sheets
    assert_includes hojas, "#{@a.seccion.grade.name} #{@a.seccion.name}"
    assert_includes hojas, "#{otra.grade.name} #{otra.name}"
  end

  # ⚠️ El Excel lleva lo FILTRADO, no la página: quien filtró un grado espera
  # ese grado entero, no los primeros veinte renglones de la pantalla.
  test "respeta el filtro de grado" do
    otro_grado = con_el_colegio(@a.colegio) do
      grado = Grade.create!(school: @a.colegio, level: :primaria, name: "5to Grado")
      Section.create!(grade: grado, academic_period: @a.seccion.academic_period, name: "A", capacity: 30)
      grado
    end

    get sections_path(grade_id: otro_grado.id, format: :xlsx)

    assert_equal [ "5to Grado A" ], hoja_de(response.body).sheets
  end

  # ── Quién puede ───────────────────────────────────────────────────────────

  test "el profesor baja la lista de SU sección" do
    sign_in @a.profesor

    get alumnos_section_path(@a.seccion, format: :xlsx)

    assert_response :success
  end

  # ⚠️ Su lista es la de su sección. Trescientos sesenta alumnos con el teléfono
  # de cada familia es otra cosa, y quien lo impide es `require_admin_access!`
  # sobre `index` — el profesor ni siquiera entra al listado de secciones.
  test "el profesor NO baja el colegio entero" do
    sign_in @a.profesor

    get sections_path(format: :xlsx)

    assert_redirected_to dashboards_profesor_path
  end

  test "un profesor de otro colegio no llega a la sección" do
    sign_in @b.profesor

    get alumnos_section_path(@a.seccion, format: :xlsx)

    assert_response :not_found
  end
end
