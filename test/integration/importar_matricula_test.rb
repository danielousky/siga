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

  # Un colegio como sale de `/siga`: con su director y nada más. Sin año
  # escolar, sin grados y sin secciones.
  def entrar_a_un_colegio_recien_creado
    sign_out @a.director

    @nuevo = Current.sin_aislamiento do
      School.create!(name: "U.E. Recién Abierta", dea_code: "S-9100",
                     location: "Caracas")
    end
    directora = User.create!(first_name: "Rosa", last_name: "Peña",
                             document: "99555001", document_type: :cedula_v,
                             email: "rosa@recien.edu", password: "123123")
    con_el_colegio(@nuevo) { Admin.create!(user: directora, school: @nuevo, role: :director) }

    sign_in directora
  end

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

  # ⚠️ El botón dice «Guardar y continuar». Antes solo guardaba y volvía a la
  # misma pantalla con un aviso: la persona veía que algo pasó, no veía a dónde,
  # y volvía a apretar el mismo botón. El test viejo solo miraba el estado, no
  # a dónde llevaba.
  test "con el mapeo completo, guardar CONTINÚA a la previsualización" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    mapear_todo(importacion)

    assert_redirected_to previsualizar_importacion_path(importacion)
  end

  test "con una columna obligatoria sin mapear, se queda donde se arregla" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }

    patch importacion_path(importacion), params: { mapeo: { "APELLIDOS Y NOMBRES" => "nombre_completo" } }

    assert_redirected_to importacion_path(importacion)
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

    # ⚠️ CON EL NÚMERO, que es todo el punto de la columna. `pluralizar` devuelve
    # solo la palabra —el número lo pone `contar`— y durante un tiempo esta celda
    # decía «alumnos» a secas. Este mismo test lo dejó pasar porque su aserción
    # miraba el NOMBRE de la sección, no el conteo que su título prometía.
    assert_select "td", text: "1 alumno"
  end

  test "crear la sección desde la previsualización la deja lista" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)
    grado = con_el_colegio(@a.colegio) { Grade.find_by(name: "1er Año") }

    assert_difference -> { con_el_colegio(@a.colegio) { Section.count } }, 1 do
      post crear_seccion_importacion_path(importacion),
           params: { grade_id: grado.id, nombre: "C", cuantas: 2 }
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

  # ── el año escolar ────────────────────────────────────────────────────────

  # ⚠️ El bug que no fallaba: la importación quedaba PARTIDA entre dos años.
  #
  # Las secciones que ya existían vivían en el año pasado, pero
  # `AcademicPeriod.vigente` devuelve el que está por empezar —correcto para el
  # resto de la app, porque es el que el colegio prepara—. Los alumnos con
  # sección existente caían en un año y los de una sección nueva en el otro, sin
  # que nadie lo viera.
  test "la sección nueva se crea en el año escolar de ESTA importación" do
    viejo_periodo = con_el_colegio(@a.colegio) { AcademicPeriod.order(:start_date).first }
    proximo = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(school: @a.colegio, name: "2027-2028",
                             start_date: Date.new(2027, 9, 15), end_date: Date.new(2028, 7, 15))
    end

    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    # El colegio dice que esta matrícula es del año viejo, aunque el «vigente»
    # de la app sea el que viene.
    get previsualizar_importacion_path(importacion), params: { periodo_id: viejo_periodo.id }
    grado = con_el_colegio(@a.colegio) { Grade.find_by(name: "1er Año") }
    post crear_seccion_importacion_path(importacion),
         params: { grade_id: grado.id, nombre: "C", cuantas: 1 }

    con_el_colegio(@a.colegio) do
      seccion = Section.find_by(grade: grado, name: "C")

      assert_equal viejo_periodo, seccion.academic_period,
                   "la sección tiene que seguir al año de la importación, no al «vigente»"
      assert_not_equal proximo, seccion.academic_period
    end
  end

  test "cambiar el año escolar cambia contra qué secciones se busca" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)
    otro = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(school: @a.colegio, name: "2027-2028",
                             start_date: Date.new(2027, 9, 15), end_date: Date.new(2028, 7, 15))
    end

    get previsualizar_importacion_path(importacion), params: { periodo_id: otro.id }

    assert_response :success
    assert_equal otro, con_el_colegio(@a.colegio) { Importacion.last.periodo }
    # En un año sin ninguna sección cargada, TODAS aparecen como inexistentes.
    assert_select "button[type=submit]", text: /Crear/, minimum: 2
  end

  # ── el colegio recién dado de alta ────────────────────────────────────────

  # ⚠️ Un colegio nace SIN ningún año escolar: `Siga::ColegiosController` crea el
  # colegio y su director, nada más. Y sin año escolar no se puede crear una
  # sección —`Section` pertenece a uno— así que el importador rechazaría las 360
  # filas con un «la sección no existe» que no dice qué hacer.
  #
  # El alta guiada de un colegio nuevo es otra cosa y va aparte; esto es la red
  # para que el importador no sea un callejón mientras tanto.
  test "sin año escolar, el importador ofrece crearlo en vez de morirse" do
    entrar_a_un_colegio_recien_creado

    subir
    importacion = con_el_colegio(@nuevo) { Importacion.last }
    mapear_todo(importacion)
    follow_redirect!

    assert_response :success
    assert_select "h2", text: /crear el año escolar/i
    # Prellenado con el año escolar venezolano: de mediados de septiembre a
    # finales de julio. De agosto en adelante ya es el que arranca.
    inicio = Date.current.month >= 8 ? Date.current.year : Date.current.year - 1

    assert_select "input[name=nombre][value=?]", "#{inicio}-#{inicio + 1}"
    assert_select "input[name=desde][value=?]", "#{inicio}-09-15"
    assert_select "button[type=submit]", text: /Cargar/, count: 0
  end

  test "crearlo desde ahí deja la importación lista para seguir" do
    entrar_a_un_colegio_recien_creado
    subir
    importacion = con_el_colegio(@nuevo) { Importacion.last }
    mapear_todo(importacion)

    assert_difference -> { con_el_colegio(@nuevo) { AcademicPeriod.count } }, 1 do
      post crear_periodo_importacion_path(importacion),
           params: { nombre: "2026-2027", desde: "2026-09-15", hasta: "2027-07-31" }
    end

    # Y queda apuntada a ESE año, no al que la app considere vigente.
    assert_equal "2026-2027", con_el_colegio(@nuevo) { Importacion.last.periodo.name }
    assert_redirected_to previsualizar_importacion_path(importacion)
  end

  test "un año escolar con las fechas al revés se rechaza con su motivo" do
    entrar_a_un_colegio_recien_creado
    subir
    importacion = con_el_colegio(@nuevo) { Importacion.last }
    mapear_todo(importacion)

    assert_no_difference -> { con_el_colegio(@nuevo) { AcademicPeriod.count } } do
      post crear_periodo_importacion_path(importacion),
           params: { nombre: "2026-2027", desde: "2027-07-31", hasta: "2026-09-15" }
    end

    assert flash[:alert].present?
  end

  # ── cargar de verdad ──────────────────────────────────────────────────────

  def hasta_poder_cargar
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)
    grado = con_el_colegio(@a.colegio) { Grade.find_by(name: "1er Año") }
    post crear_seccion_importacion_path(importacion), params: { grade_id: grado.id, nombre: "C", cuantas: 1 }
    importacion
  end

  def cargar(importacion)
    patch importacion_path(importacion), params: { confirmar: "1" }
  end

  test "confirmar crea alumnos, representantes e inscripciones" do
    importacion = hasta_poder_cargar

    assert_difference -> { con_el_colegio(@a.colegio) { Student.count } }, 3 do
      assert_difference -> { con_el_colegio(@a.colegio) { Enrollment.count } }, 3 do
        assert_difference -> { con_el_colegio(@a.colegio) { Representative.count } }, 3 do
          cargar(importacion)
        end
      end
    end

    assert con_el_colegio(@a.colegio) { Importacion.last.confirmada? }
  end

  # ⚠️ Es el caso NORMAL, no la excepción: el colegio manda la planilla, ve el
  # reporte, corrige cuatro filas y la vuelve a mandar.
  test "reimportar la misma planilla no duplica a nadie" do
    cargar(hasta_poder_cargar)
    alumnos = con_el_colegio(@a.colegio) { Student.count }

    otra = hasta_poder_cargar
    cargar(otra)

    assert_equal alumnos, con_el_colegio(@a.colegio) { Student.count }
  end

  # El alumno se guarda EN MAYÚSCULA y se muestra en Tipo Título.
  test "el alumno queda con sus dos apellidos bien partidos" do
    cargar(hasta_poder_cargar)

    jose = con_el_colegio(@a.colegio) { User.find_by(cedula_escolar: "V20140000123") }

    assert_equal "JOSÉ LUIS", jose.first_name
    assert_equal "DE LA CRUZ", jose.last_name
    assert_equal "MARÍN", jose.second_last_name
    assert_equal "José Luis de la Cruz Marín", jose.nombre_completo
  end

  test "el carnet se genera cuando la planilla no lo trae" do
    cargar(hasta_poder_cargar)

    carnets = con_el_colegio(@a.colegio) { Student.pluck(:school_card) }

    assert carnets.all?(&:present?)
    assert_equal carnets.size, carnets.uniq.size, "dos alumnos no pueden compartir carnet en el mismo colegio"
  end

  # ── el reporte ────────────────────────────────────────────────────────────

  # ⚠️ Esta lista ES el producto del reporte. Sin ella, «2 sin correo» es un
  # número que nadie puede accionar; con nombre y cédula, la secretaria la
  # imprime y sabe a quién llamar.
  test "el reporte lista con nombre y cédula a los representantes sin correo" do
    importacion = hasta_poder_cargar
    cargar(importacion)
    follow_redirect!

    assert_response :success
    assert_select "h2", text: /representante sin correo/i
    assert_select "td", text: /Pérez Rojas, Luis/
  end

  test "el reporte dice cuántos alumnos y cuántas inscripciones se crearon" do
    importacion = hasta_poder_cargar
    cargar(importacion)
    follow_redirect!

    assert_select ".cifra-numero", text: "3", minimum: 2
  end

  test "confirmar dos veces no carga dos veces" do
    importacion = hasta_poder_cargar
    cargar(importacion)

    assert_no_difference -> { con_el_colegio(@a.colegio) { Student.count } } do
      cargar(importacion)
    end

    assert_redirected_to resultado_importacion_path(importacion)
  end

  test "no se puede confirmar mientras falte una sección" do
    subir
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    assert_no_difference -> { con_el_colegio(@a.colegio) { Student.count } } do
      cargar(importacion)
    end

    assert_redirected_to previsualizar_importacion_path(importacion)
  end

  # La pregunta de un colegio al que le aparecieron alumnos de más.
  test "queda registrado quién importó y desde qué archivo" do
    cargar(hasta_poder_cargar)

    rastro = con_el_colegio(@a.colegio) { ActivityLog.where(action: "matricula_importada").last }

    assert_not_nil rastro
    assert_match(/matricula_de_colegio\.csv/, rastro.message)
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
  # ── el grado que no existe ────────────────────────────────────────────────
  #
  # ⚠️ Era el único callejón que quedaba en todo el recorrido: la pantalla
  # mandaba a la persona a Configuración a crear el grado a mano y volver a
  # empezar. Ahora se crea de acá, igual que la sección y el año escolar.

  test "un grado que no existe se ofrece crear, con el corte ya propuesto" do
    con_grado_nuevo do |importacion|
      get previsualizar_importacion_path(importacion)

      assert_response :success
      assert_select "form[action=?]", crear_grado_importacion_path(importacion)
      # El corte propuesto: «3er Año C» es el grado «3er Año» con la sección «C».
      assert_select "input[name=grado][value=?]", "3er Año"
      assert_select "input[name=seccion][value=?]", "C"
    end
  end

  # Primaria dice GRADO y secundaria dice AÑO. No es una convención nuestra: es
  # cómo se nombran los niveles en Venezuela, y de ahí sale la escala (MOR-129).
  test "propone el nivel según diga «Año» o «Grado»" do
    con_grado_nuevo do |importacion|
      get previsualizar_importacion_path(importacion)

      assert_select "select[name=nivel] option[selected][value=?]", "secundaria"
    end
  end

  # Se crean los DOS de un golpe: quien llega acá está tratando de resolver una
  # sección, y dejarle el grado sin secciones lo deja a mitad de camino.
  test "crear el grado crea también su sección" do
    con_grado_nuevo do |importacion|
      assert_difference [ -> { con_el_colegio(@a.colegio) { Grade.count } },
                          -> { con_el_colegio(@a.colegio) { Section.count } } ], 1 do
        post crear_grado_importacion_path(importacion),
             params: { grado: "3er Año", seccion: "C", nivel: "secundaria", cuantas: 1 }
      end

      con_el_colegio(@a.colegio) do
        grado = Grade.find_by(name: "3er Año")
        assert grado.secundaria?
        assert grado.escala_numerica?, "en secundaria la escala es siempre numérica"
        assert_equal importacion.periodo, Section.find_by(grade: grado, name: "C").academic_period
      end
    end
  end

  # Un grado sin sección es válido: «5to Año» a secas no nombra ninguna.
  test "sin nombre de sección se crea solo el grado" do
    con_grado_nuevo do |importacion|
      assert_no_difference -> { con_el_colegio(@a.colegio) { Section.count } } do
        post crear_grado_importacion_path(importacion),
             params: { grado: "5to Año", seccion: "", nivel: "secundaria" }
      end

      assert_not_nil con_el_colegio(@a.colegio) { Grade.find_by(name: "5to Año") }
    end
  end

  # Un nombre repetido no crea basura: el índice es único por colegio.
  test "un grado que ya existe se rechaza con su motivo" do
    con_grado_nuevo do |importacion|
      existente = con_el_colegio(@a.colegio) { Grade.first.name }

      assert_no_difference -> { con_el_colegio(@a.colegio) { Grade.count } } do
        post crear_grado_importacion_path(importacion),
             params: { grado: existente, seccion: "Z", nivel: "secundaria" }
      end

      assert_match(/ya está en uso|already been taken/i, flash[:alert].to_s)
    end
  end

  # Sube la planilla que nombra «3er Año C», un grado que el colegio no tiene, y
  # deja el mapeo hecho.
  def con_grado_nuevo
    subir("matricula_con_grado_nuevo.csv")
    importacion = con_el_colegio(@a.colegio) { Importacion.last }
    mapear_todo(importacion)

    yield importacion
  end
end
