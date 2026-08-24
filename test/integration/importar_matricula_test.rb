require "test_helper"

# Subir la planilla del colegio y decir qué columna es cuál (MOR-126).
#
# Es la respuesta a la objeción que aparece en la primera conversación con
# cualquier colegio que ya tiene sistema: "¿y lo que ya tengo?".
class ImportarMatriculaTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    sign_in @a.director
  end

  def planilla(nombre = "matricula_de_colegio.csv")
    fixture_file_upload(nombre, "text/csv")
  end

  def subir(nombre = "matricula_de_colegio.csv")
    post importaciones_path, params: { importacion: { archivo: planilla(nombre) } }
  end

  def importaciones = con_el_colegio(@a.colegio) { Importacion.count }

  # ── la plantilla ──────────────────────────────────────────────────────────

  test "el colegio descarga la plantilla en blanco" do
    get plantilla_importaciones_path

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                 response.media_type
    assert_match(/matricula-.*\.xlsx/, response.headers["Content-Disposition"])
  end

  # ── subir ─────────────────────────────────────────────────────────────────

  test "subir una planilla la deja lista para mapear" do
    assert_difference "importaciones", 1 do
      subir
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success

    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    assert_equal "matricula_de_colegio.csv", importacion.nombre_del_archivo
    assert_equal 3, importacion.filas_leidas, "tres alumnos: el subtotal no cuenta"
    assert_equal @a.director, importacion.subido_por
  end

  # ⚠️ Un archivo que no se puede leer NO queda registrado.
  #
  # Si quedara, la secretaria vería una fila rota en el listado sin saber qué
  # hacer con ella. Se rechaza con el archivo todavía en su computadora.
  test "una planilla que no se puede leer se rechaza sin dejar rastro" do
    assert_no_difference "importaciones" do
      subir("no_es_una_planilla.csv")
    end

    assert_response :unprocessable_entity
    assert_match(/encabezados/i, flash[:alert])
  end

  test "subir sin elegir archivo lo dice" do
    assert_no_difference "importaciones" do
      post importaciones_path, params: { importacion: {} }
    end

    assert_response :unprocessable_entity
  end

  # ── la pantalla del mapeo ─────────────────────────────────────────────────

  test "propone el mapeo y muestra un valor de ejemplo de cada columna" do
    subir
    follow_redirect!

    # El valor de ejemplo es lo que hace usable la pantalla: «AÑO/SECC» no dice
    # nada, «1er Año A» al lado lo dice todo.
    assert_select "span.muestra-de-celda", text: "1er Año A"
    assert_select "span.muestra-de-celda", text: "DE LA CRUZ MARÍN JOSÉ LUIS"

    # Y el mapeo ya viene propuesto, para que solo haya que corregir.
    assert_select "select[name='mapeo[AÑO/SECC]'] option[selected][value=seccion]"
    assert_select "select[name='mapeo[CORREO REPRESENTANTE]'] option[selected][value=correo_del_representante]"
  end

  # Que diga en qué fila encontró los encabezados no es un detalle técnico: si
  # se equivocó, es lo único que permite darse cuenta antes de cargar 360
  # alumnos con las columnas corridas.
  test "dice en qué fila encontró los encabezados" do
    subir
    follow_redirect!

    assert_select "dd", text: /Fila 4 del archivo/
  end

  test "lista las filas que ignoró para poder revisarlas" do
    subir
    follow_redirect!

    assert_select "td", text: /SUBTOTAL 1er AÑO/
  end

  # ── lo que bloquea ────────────────────────────────────────────────────────

  test "avisa cuáles columnas obligatorias faltan" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    patch importacion_path(importacion), params: { mapeo: { "APELLIDOS Y NOMBRES" => "nombre_completo" } }
    follow_redirect!

    assert_select "ul.lista-faltantes li strong", text: "SECCIÓN"
    assert_not con_el_colegio(@a.colegio) { Importacion.last.mapeada? }
  end

  test "con las obligatorias mapeadas, la importación queda lista" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    patch importacion_path(importacion), params: { mapeo: {
      "APELLIDOS Y NOMBRES" => "nombre_completo",
      "AÑO/SECC" => "seccion",
      "REPRESENTANTE" => "representante",
      "CEDULA REPRESENTANTE" => "cedula_del_representante"
    } }

    assert con_el_colegio(@a.colegio) { Importacion.last.mapeada? }
  end

  # Una columna que la persona deja en «No importar» llega vacía. Guardarla como
  # `=> ""` la haría contar como mapeada a nada.
  test "las columnas que se dejan sin importar no se guardan" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    patch importacion_path(importacion), params: { mapeo: {
      "Nº" => "", "APELLIDOS Y NOMBRES" => "nombre_completo"
    } }

    assert_not con_el_colegio(@a.colegio) { Importacion.last.mapeo.key?("Nº") }
  end

  # ── la previsualización ───────────────────────────────────────────────────

  def mapear_todo(importacion)
    patch importacion_path(importacion), params: { mapeo: {
      "APELLIDOS Y NOMBRES" => "nombre_completo", "C.I." => "documento",
      "CEDULA ESCOLAR" => "cedula_escolar", "F. NACIM." => "fecha_de_nacimiento",
      "SEXO" => "sexo", "AÑO/SECC" => "seccion", "REPRESENTANTE" => "representante",
      "CEDULA REPRESENTANTE" => "cedula_del_representante",
      "CORREO REPRESENTANTE" => "correo_del_representante"
    } }
  end

  test "la previsualización dice cuántas entran y cuántas no, sin escribir nada" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    assert_no_difference -> { con_el_colegio(@a.colegio) { Student.count } } do
      get previsualizar_importacion_path(importacion)
    end

    assert_response :success
    assert_select ".cifra-de-importacion", minimum: 2
  end

  # El mapeo automático ya cubre las cuatro obligatorias, así que para llegar
  # acá hay que haber quitado una a mano.
  test "sin mapear las obligatorias no deja previsualizar" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    patch importacion_path(importacion), params: { mapeo: { "APELLIDOS Y NOMBRES" => "nombre_completo" } }
    get previsualizar_importacion_path(importacion)

    assert_redirected_to importacion_path(importacion)
  end

  # ⚠️ El caso que Daniel pidió: la planilla nombra una sección que no existe.
  # Ni se crea sola —un dedazo dejaría «1er Año Á» para siempre— ni se manda a
  # la persona a otra pantalla. Se muestra qué falta, CON CUÁNTOS ALUMNOS la
  # esperan, y se crea de un clic.
  test "una sección que no existe se ofrece crear, con su conteo" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    get previsualizar_importacion_path(importacion)

    assert_response :success
    assert_select "td", text: /1er Año C/
    assert_select "button[type=submit]", text: /Crear .*C/
  end

  test "crear la sección desde la previsualización la deja lista" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)
    grado = con_el_colegio(@a.colegio) { Grade.find_by(name: "1er Año") }

    assert_difference -> { con_el_colegio(@a.colegio) { Section.count } }, 1 do
      post crear_seccion_importacion_path(importacion),
           params: { grade_id: grado.id, nombre: "C", alumnos: 2 }
    end

    seccion = con_el_colegio(@a.colegio) { Section.find_by(grade: grado, name: "C") }

    assert_not_nil seccion
    assert_operator seccion.capacity, :>=, 30, "la capacidad no puede quedar por debajo de los que ya la esperan"
  end

  test "el botón de cargar no aparece mientras falte una sección" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    get previsualizar_importacion_path(importacion)

    assert_select "button[type=submit]", text: /Cargar/, count: 0
  end

  # ── quién puede ───────────────────────────────────────────────────────────

  test "un profesor no puede importar matrícula" do
    sign_out @a.director
    sign_in @a.profesor

    assert_no_difference "importaciones" do
      subir
    end

    assert_response :redirect
  end

  # ⚠️ El archivo trae los datos de 360 menores. Lo que lo aísla es la fila que
  # lo referencia: Active Storage no tiene `school_id`.
  test "la importación de otro colegio no se alcanza" do
    subir
    ajena = con_el_colegio(@a.colegio) { Importacion.last }

    sign_out @a.director
    sign_in @b.director

    get importacion_path(ajena)

    # 404 y no 403: un 403 confirmaría que el registro existe.
    assert_response :not_found
  end

  test "descartar una importación libera el archivo" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    delete importacion_path(importacion)

    assert con_el_colegio(@a.colegio) { Importacion.find(importacion.id).descartada? }
  end
end
