require "test_helper"

# Pegar la lista, en vez de subir el archivo.
#
#     ┌─ Cómo la va a traer ──────────────────────────────┐
#     │  (Subir un archivo) ( Pegar la lista )            │
#     │  ┌──────────────────────────────────────────────┐ │
#     │  │ APELLIDOS Y NOMBRES ⇥ C.I. ⇥ AÑO/SECC       │ │
#     │  │ López Medina, Álvaro ⇥ V-30123456 ⇥ 1er A   │ │
#     │  └──────────────────────────────────────────────┘ │
#     └───────────────────────────────────────────────────┘
#
# ## ⚠️ No es otro importador
#
# La secretaria tiene la lista abierta en Excel al lado. Guardar el archivo,
# buscarlo en el explorador y subirlo son cuatro pasos que no aportan nada
# cuando lo que quiere es seleccionar, copiar y pegar. Lo que pasa después es
# IDÉNTICO: la misma `Planilla`, la misma previsualización, los mismos avisos.
#
# ⚠️ Y no hace falta convertir nada: `Planilla` ya adivina el separador del
# propio texto —Excel copia con TABULACIONES, un CSV pegado a mano trae comas o
# punto y coma— que es exactamente el problema que ya resolvía al leer archivos.
class PegarLaListaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
    sign_in @a.director
  end

  # Lo que sale de seleccionar tres filas en Excel y pulsar copiar.
  DE_EXCEL = <<~TEXTO
    APELLIDOS Y NOMBRES\tC.I.\tCEDULA ESCOLAR\tF. NACIM.\tSEXO\tAÑO/SECC
    Pegado Uno, Ana\t\tV20150000111\t03/04/2015\tF\t1er Grado A
    Pegado Dos, Luis\t\tV20150000222\t12/07/2015\tM\t1er Grado A
  TEXTO

  def pegar(texto = DE_EXCEL, tipo: "matricula")
    post importaciones_path, params: { importacion: { tipo: tipo, pegado: texto } }
  end

  # ── La puerta ─────────────────────────────────────────────────────────────

  test "el formulario ofrece las dos formas de traerla" do
    get new_importacion_path(tipo: "matricula")

    assert_response :success
    assert_select "input[type=file][name='importacion[archivo]']"
    assert_select "textarea[name='importacion[pegado]']"
  end

  # ⚠️ Ninguno de los dos es obligatorio por separado —el `required` del archivo
  # impedía enviar el formulario con la lista pegada— así que la exigencia vive
  # en el servidor.
  test "sin archivo y sin pegado, lo dice" do
    assert_no_difference -> { con_el_colegio(@a.colegio) { Importacion.count } } do
      post importaciones_path, params: { importacion: { tipo: "matricula" } }
    end

    assert_match(/Suba una planilla o pegue la lista/, flash[:alert].to_s)
  end

  # ── Pegar ─────────────────────────────────────────────────────────────────

  test "lo pegado entra por el mismo camino que un archivo" do
    assert_difference -> { con_el_colegio(@a.colegio) { Importacion.count } }, 1 do
      pegar
    end

    importacion = con_el_colegio(@a.colegio) { Importacion.order(:id).last }
    assert_equal 2, importacion.filas_leidas
    assert_equal "matricula", importacion.tipo
  end

  # ⚠️ Excel copia con TABULACIONES, no con comas. Es el mismo problema que
  # `Planilla` ya resolvía al leer un archivo, y por eso pegar no necesitó
  # ningún analizador nuevo.
  test "reconoce las tabulaciones de un copiar y pegar de Excel" do
    pegar

    importacion = con_el_colegio(@a.colegio) { Importacion.order(:id).last }
    encabezados = importacion.planilla.encabezados

    assert_includes encabezados, "APELLIDOS Y NOMBRES"
    assert_includes encabezados, "AÑO/SECC"
  end

  test "y también las comas de un CSV pegado a mano" do
    pegar "APELLIDOS Y NOMBRES,CEDULA ESCOLAR,AÑO/SECC\nPegado Tres, Eva,V20150000333,1er Grado A\n"

    importacion = con_el_colegio(@a.colegio) { Importacion.order(:id).last }
    assert_includes importacion.planilla.encabezados, "CEDULA ESCOLAR"
  end

  # ⚠️ Se guarda como archivo igual: la previsualización vuelve a LEER la
  # planilla en cada pantalla —el mapeo, la muestra, la confirmación— y sin
  # archivo no habría de dónde. Además la importación es la bitácora de quién
  # cargó qué, y «se pegó una lista» sin la lista no contesta nada.
  test "lo pegado queda guardado, como cualquier planilla" do
    pegar

    importacion = con_el_colegio(@a.colegio) { Importacion.order(:id).last }
    assert importacion.archivo.attached?
    assert_match(/\Apegado-/, importacion.nombre_del_archivo)

    # Y la pantalla siguiente lo puede volver a leer.
    get importacion_path(importacion)
    assert_response :success
  end

  # ── Lo que no se puede leer ───────────────────────────────────────────────

  test "un pegado sin nada aprovechable se rechaza con un motivo" do
    assert_no_difference -> { con_el_colegio(@a.colegio) { Importacion.count } } do
      pegar "hola qué tal"
    end

    assert_not_nil flash[:alert]
  end
end
