require "test_helper"

# Los certificados de fin de año, por sección
# (`docs/specs/certificados-en-documentos.md`).
#
# Existían desde el 11 de septiembre de 2026 y nadie los encontraba: estaban en
# la última tarjeta de la ficha de cada alumno. Daniel, el 1 de octubre: *«creo
# que ella nunca vio los certificados, no los encontró»*.
#
# Lo que más se prueba acá NO es que salga un PDF —eso ya lo probaban los
# armadores— sino lo que cambia al emitir de a veinticuatro:
#
#     que cada página sea de SU alumno, y no la primera repetida
#     que el lote no imprima «promovido» de quien repite
#     que la pantalla diga antes lo que el PDF haría en silencio
class CertificadosTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)   # «6to Grado – A», dos alumnos
    @uno, @dos = @a.escenario.inscripciones
  end

  # ── Emitir ────────────────────────────────────────────────────────────────

  test "la dirección emite el certificado de un alumno" do
    sign_in @a.director

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @uno.id }

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF"), "tiene que salir un PDF de verdad"
    # El mismo arranque que usa la ficha: el archivo se llama igual venga de
    # donde venga.
    assert_match(/certificado-primaria-prueba\.pdf/, response.headers["Content-Disposition"])
    assert_equal 1, paginas_de(response.body).size
  end

  # ⚠️ El test que justifica a todos los demás.
  #
  # Los tres dibujantes guardaban los datos de UN alumno en el objeto. Al
  # dibujar varios, una página puede arrastrar los datos de la anterior sin que
  # nada falle: el PDF sale, tiene sus dos páginas, y las dos dicen el mismo
  # nombre. Un test que solo mire `%PDF` —o que solo cuente páginas— pasa igual.
  test "toda la sección sale en un PDF, y cada página es de SU alumno" do
    sign_in @a.director

    post certificados_path, params: { section_id: @a.seccion.id }

    assert_response :success
    assert_match(/certificado-primaria-6to-grado-a\.pdf/, response.headers["Content-Disposition"])

    primera, segunda = paginas = paginas_de(response.body)

    assert_equal 2, paginas.size, "una página por alumno"
    assert_includes primera, "Alumno1"
    assert_not_includes primera, "Alumno2", "la primera página trae al segundo alumno"
    assert_includes segunda, "Alumno2"
    assert_not_includes segunda, "Alumno1", "la segunda página repite al primero"
  end

  # ── El grado decide el papel ──────────────────────────────────────────────
  #
  # No lo elige quien emite, y por eso la pantalla lo DICE antes del botón: en
  # las otras dos pestañas el papel es siempre el mismo, acá no.

  test "6to Grado lleva el certificado, y la pantalla lo dice antes de emitir" do
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "strong", "Certificado de Educación Primaria"

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @uno.id }

    assert_includes paginas_de(response.body).first, "CERTIFICADO"
  end

  test "cualquier otro grado de primaria lleva la constancia de prosecución" do
    con_el_colegio(@a.colegio) { @a.grado.update!(name: "3er Grado") }
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "strong", "Constancia de Prosecución"

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @uno.id }

    assert_match(/prosecucion-primaria-prueba\.pdf/, response.headers["Content-Disposition"])
    assert_includes paginas_de(response.body).first, "CONSTANCIA DE PROSECUCIÓN"
  end

  test "Educación Inicial lleva los suyos, sin literal que avisar" do
    jardin, directora = jardin_con_su_directora   # «1er Nivel», dos niños
    sign_in directora

    get certificados_path(section_id: jardin.seccion.id)

    assert_select "strong", "Constancia de Prosecución de Educación Inicial"
    # En Inicial no hay calificación, así que no hay literal que pueda faltar.
    assert_select ".plan-sin-evaluar", false

    con_el_colegio(jardin.colegio) { jardin.grado.update!(name: "3er Nivel") }
    get certificados_path(section_id: jardin.seccion.id)

    assert_select "strong", "Certificación de Estudios de Educación Inicial"

    post certificados_path, params: { section_id: jardin.seccion.id }

    assert_response :success
    assert_match(/certificacion-inicial-3er-nivel-a\.pdf/, response.headers["Content-Disposition"])

    primera, segunda = paginas = paginas_de(response.body)

    assert_equal 2, paginas.size
    assert_includes primera, "Alumno1"
    assert_includes segunda, "Alumno2"
    # ⚠️ Una palabra sola, no la frase: donde el párrafo cambia de línea Prawn
    # se come el espacio, y «continuará estudios» puede salir pegado.
    assert_includes segunda, "continuará", "el III Grupo continúa a primaria"
  end

  test "Media lleva la 31059, de un alumno o de toda la sección" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)   # «1er Año»
    sign_in liceo.director

    get certificados_path(section_id: liceo.seccion.id)

    assert_select "strong", "Certificación de Calificaciones (31059)"

    post certificados_path, params: { section_id: liceo.seccion.id }

    assert_response :success
    assert_match(/certificacion-31059-1er-ano-a\.pdf/, response.headers["Content-Disposition"])

    paginas = paginas_de(response.body)

    # La 31059 escribe apellidos y nombres en MAYÚSCULA, como el formato.
    assert_equal 2, paginas.size, "con un año cursado, la 31059 cabe en una página por alumno"
    assert_includes paginas.first, "ALUMNO1"
    assert_not_includes paginas.first, "ALUMNO2"
    assert_includes paginas.last, "ALUMNO2"
    assert_not_includes paginas.last, "ALUMNO1"
  end

  # ── Quien repite queda fuera del lote ─────────────────────────────────────
  #
  # Decisión de Daniel, 1 de octubre de 2026. El papel de primaria dice «siendo
  # promovido(a)» sin mirar las notas: de a uno lo decide quien lo firma, de a
  # veinticuatro nadie lo mira.

  test "quien repite no sale con toda la sección, y la pantalla dice quién y por qué" do
    que_repita(@dos)
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    # El desplegable dice cuántos SALEN, no cuántos tiene la sección.
    assert_select "select#enrollment_id option", text: "Toda la sección (1 alumno)"
    assert_select ".plan-sin-evaluar strong", "Prueba, Alumno2"
    assert_select ".plan-sin-evaluar", /repite, arrastra Matemática/

    post certificados_path, params: { section_id: @a.seccion.id }

    pagina, = paginas = paginas_de(response.body)

    assert_equal 1, paginas.size
    assert_includes pagina, "Alumno1"
    assert_not_includes pagina, "Alumno2"
  end

  # ⚠️ No es un bloqueo. La promoción la confirma el director y en primaria la
  # norma no es clara: SIGA no le niega el papel, le quita la posibilidad de
  # imprimirlo sin enterarse.
  test "eligiéndolo a él, sí se emite" do
    que_repita(@dos)
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "select#enrollment_id option", text: "Prueba, Alumno2"

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @dos.id }

    assert_response :success
    assert_includes paginas_de(response.body).first, "Alumno2"
  end

  test "si todos repiten, la pantalla no ofrece un lote que no existe" do
    que_repita(@uno)
    que_repita(@dos)
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "select#enrollment_id option", text: /Toda la sección/, count: 0
    assert_select "select#enrollment_id option", 2

    # Y armando la petición a mano, tampoco sale un PDF vacío.
    post certificados_path, params: { section_id: @a.seccion.id }

    assert_redirected_to certificados_path(section_id: @a.seccion.id)
    assert_match(/Ningún alumno de esa sección entra/, flash[:alert])
  end

  # ⚠️ La regla es del PAPEL, no de la pantalla. La 31059 no dice que el alumno
  # fue promovido: es el historial de sus notas, y es cierta también para quien
  # repite. Sacarlo del lote sería negarle un papel que no miente.
  test "en Media el que repite SÍ sale con toda la sección" do
    liceo = colegio_completo("Liceo", nivel: :secundaria)
    que_repita(liceo.escenario.inscripcion(2), en: liceo)
    sign_in liceo.director

    get certificados_path(section_id: liceo.seccion.id)

    assert_select "select#enrollment_id option", text: "Toda la sección (2 alumnos)"
    assert_select ".plan-sin-evaluar", false
  end

  # ── Quien no tiene calificación definitiva ────────────────────────────────

  # ⚠️ «Sin datos» NO es «repite». Un colegio en su primer año con SIGA tiene
  # las notas del año pasado en papel: el certificado sale igual, con el literal
  # como una línea para llenar a mano. Tratarlo como repitiente dejaría la
  # pestaña vacía justo para el cliente nuevo.
  test "sin calificación definitiva sale igual, y la pantalla lo avisa antes" do
    con_el_colegio(@a.colegio) do
      FinalGradeBook.where(enrollment: [ @uno, @dos ]).delete_all
      definitiva(@uno, 18)
    end
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "select#enrollment_id option", text: "Toda la sección (2 alumnos)"
    assert_select ".plan-sin-evaluar", /1 alumno no tiene calificación definitiva/

    post certificados_path, params: { section_id: @a.seccion.id }

    assert_equal 2, paginas_de(response.body).size
  end

  test "con todas las definitivas cargadas no hay nada que avisar" do
    con_el_colegio(@a.colegio) { [ @uno, @dos ].each { |i| definitiva(i, 17) } }
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select ".plan-sin-evaluar", false
  end

  # ── Los retirados ─────────────────────────────────────────────────────────

  # Un retirado no terminó el año: su papel diría que cursó un grado que dejó a
  # la mitad. Es el criterio de la ficha, que solo ofrece el documento a quien
  # tiene una inscripción activa.
  test "un retirado no aparece ni en el lote ni en el desplegable" do
    con_el_colegio(@a.colegio) { @dos.update!(status: :retirado) }
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "select#enrollment_id option", text: "Toda la sección (1 alumno)"
    assert_select "select#enrollment_id option", text: "Prueba, Alumno2", count: 0

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @dos.id }

    assert_response :not_found
  end

  test "una sección sin alumnos lo dice, en vez de ofrecer un botón" do
    con_el_colegio(@a.colegio) { [ @uno, @dos ].each { |i| i.update!(status: :retirado) } }
    sign_in @a.director

    get certificados_path(section_id: @a.seccion.id)

    assert_select "select#enrollment_id", false
    assert_select ".nota-pendiente", /no tiene alumnos inscritos/
  end

  # ── El rastro ─────────────────────────────────────────────────────────────

  # De a uno es el MISMO rastro que deja la ficha, con la misma acción: quien
  # abra la bitácora de ese alumno tiene que ver su certificado venga de donde
  # venga.
  test "de a uno, queda el rastro contra el alumno" do
    sign_in @a.director

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @uno.id }

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.where(action: "documento_de_primaria_emitido").last

      assert rastro.present?, "un certificado sin rastro de quién lo emitió no sirve como documento"
      assert_equal @uno.student, rastro.subject
      assert_match(/emitió Certificado de Educación Primaria de Alumno1 Prueba/, rastro.message)
    end
  end

  # El lote es UN hecho, no veinticuatro filas.
  test "el lote deja un solo rastro, contra la sección" do
    sign_in @a.director

    assert_difference -> { con_el_colegio(@a.colegio) { ActivityLog.where(action: "documento_de_primaria_emitido").count } }, 1 do
      post certificados_path, params: { section_id: @a.seccion.id }
    end

    con_el_colegio(@a.colegio) do
      rastro = ActivityLog.where(action: "documento_de_primaria_emitido").last

      assert_equal @a.seccion, rastro.subject
      assert_match(/para 2 alumnos de 6to Grado – A/, rastro.message)
    end
  end

  # ── Aislamiento y permisos ────────────────────────────────────────────────

  test "no se emite el certificado de una sección de otro colegio" do
    sign_in @a.director

    post certificados_path, params: { section_id: @b.seccion.id }

    assert_response :not_found
  end

  test "ni el de un alumno de otra sección, pidiéndolo a mano" do
    sign_in @a.director

    post certificados_path, params: { section_id: @a.seccion.id, enrollment_id: @b.inscripcion.id }

    assert_response :not_found
  end

  test "un profesor no emite certificados" do
    sign_in @a.profesor

    get certificados_path

    assert_redirected_to dashboards_profesor_path
  end

  test "un estudiante tampoco" do
    sign_in @a.estudiante

    get certificados_path

    assert_redirected_to dashboards_estudiante_path
  end

  private

  # ⚠️ A mano, y no con `colegio_completo`: ese le carga una nota de 17 al
  # primer alumno, y en Educación Inicial la calificación es un TEXTO — el
  # modelo la rechaza, con razón.
  def jardin_con_su_directora
    jardin = escenario_academico(nombre: "Jardín", nivel: :preescolar, alumnos: 2)
    directora = con_el_colegio(jardin.colegio) do
      usuario("dir", jardin.colegio.id).tap { |u| Admin.create!(user: u, school: jardin.colegio, role: :director) }
    end

    [ jardin, directora ]
  end

  # Una calificación definitiva, como la deja el importador de historial.
  def definitiva(inscripcion, nota, materia: @a.materia)
    libro = FinalGradeBook.find_or_initialize_by(enrollment: inscripcion, subject: materia)
    libro.update!(annual_average: nota, final_score: nota, origen: :importada)
  end

  # ⚠️ Con el tope en CERO, una sola aplazada alcanza para repetir. El tope de
  # fábrica es 2 y el escenario tiene una materia: llegar a tres aplazadas sería
  # armar un pensum entero para probar una comparación.
  def que_repita(inscripcion, en: @a)
    Current.sin_aislamiento { en.colegio.update!(tope_de_arrastre: 0) }
    con_el_colegio(en.colegio) { definitiva(inscripcion, 8, materia: en.materia) }
  end

  # El texto de cada página, sin una gema que lea PDF.
  #
  # Prawn escribe sin comprimir: cada página es un `stream` con operadores de
  # texto (`BT … ET`), y cada trozo va en hexadecimal dentro de un arreglo `TJ`
  # —partido por el interletraje, y por eso se JUNTAN:
  #
  #     [<416c756d> 12 <6e6f31>] TJ    →   «Alum» + «no1»   →   «Alumno1»
  #
  # Los bytes son Windows-1252, que es lo que cubren las fuentes de fábrica de
  # Prawn (ver `DibujaDocumentosOficiales`); se pasan a UTF-8 para poder
  # comparar «PROSECUCIÓN» con su acento.
  #
  # ⚠️ Existe porque sin él no se puede probar lo único que importa de emitir
  # varios: que cada página diga lo de su alumno. Contar páginas no alcanza.
  def paginas_de(pdf)
    pdf.b.scan(/stream\r?\n(.*?)endstream/m).filter_map do |(contenido)|
      next unless contenido.include?("BT\n")

      contenido.scan(/<([0-9a-f]+)>/i).map { |(hex)| [ hex ].pack("H*") }.join
               .force_encoding("Windows-1252").encode("UTF-8")
    end
  end
end
