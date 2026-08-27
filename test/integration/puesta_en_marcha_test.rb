require "test_helper"

# El mapa de la puesta en marcha (MOR-154).
#
# ## Lo que este test protege
#
# El progreso NO se guarda: se deduce de los datos. Es la decisión que sostiene
# todo el diseño, y la que alguien va a querer «optimizar» con una columna
# `pasos_completados` el día que esto se sienta lento. Estos tests fallan si eso
# pasa, porque prueban justamente lo que una bandera no puede hacer: enterarse
# de lo que ocurrió por otra puerta.
class PuestaEnMarchaTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # ⚠️ El caso que ninguna bandera resuelve.
  #
  # La secretaria entra por el MENÚ a cargar las materias —no por el mapa— y el
  # paso tiene que ponerse en verde solo. Con una columna, el tablero seguiría
  # diciendo «pendiente» y quien lo ve concluye que el sistema no se entera de
  # lo que hace.
  test "un paso se pone en verde aunque el trabajo se haya hecho por otra puerta" do
    vacio, = colegio_vacio

    con_el_colegio(vacio) do
      assert_not paso(:departamentos, vacio).listo?

      Department.create!(school: vacio, name: "Ciencias")

      assert paso(:departamentos, vacio).listo?,
             "el paso no se enteró de un departamento creado por fuera del mapa"
    end
  end

  # Y al revés, que es la otra mitad y la que ninguna bandera hace: deshacer
  # devuelve el paso a pendiente, solo.
  test "borrar lo último devuelve el paso a pendiente" do
    vacio, = colegio_vacio

    con_el_colegio(vacio) do
      departamento = Department.create!(school: vacio, name: "Ciencias")
      assert paso(:departamentos, vacio).listo?

      departamento.destroy!

      assert_not paso(:departamentos, vacio).listo?,
                 "borrar el último departamento dejó el paso en verde"
    end
  end

  # Un colegio ya configurado no ve el mapa nunca. No hay que apagarlo a mano.
  test "el mapa no aparece en un colegio que ya arrancó" do
    get dashboards_administrador_path

    assert_response :success
    assert_select ".puesta-en-marcha", 0,
                  "el colegio tiene grados, período, materias, secciones, profesores y " \
                  "alumnos: el mapa no tiene nada que decirle"
  end

  test "el mapa aparece y ordena los pasos en un colegio vacío" do
    vacio, director = colegio_vacio
    sign_in director

    get dashboards_administrador_path

    assert_response :success
    assert_select ".puesta-en-marcha", 1
    assert_select "li.paso", 8

    con_el_colegio(vacio) do
      claves = PasosDeArranque.para(vacio).map(&:clave)
      assert_equal :niveles, claves.first, "lo primero es elegir los niveles"
    end
  end

  # ⚠️ Un paso bloqueado NO lleva su botón apagado: lleva otro botón, que va a
  # lo que lo desbloquea. Un control deshabilitado es una pregunta sin respuesta
  # y quien navega con teclado ni siquiera lo puede enfocar para averiguar.
  test "el paso bloqueado ofrece el camino, no un botón apagado" do
    vacio, director = colegio_vacio
    sign_in director

    get dashboards_administrador_path

    assert_select "li.paso--bloqueado", minimum: 1
    assert_select "li.paso--bloqueado .btn", minimum: 1
    assert_select "[disabled]", 0,
                  "hay un control deshabilitado: no se puede enfocar para saber por qué"
    assert_match(/Antes hace falta/, response.body)
  end

  # La única cosa que el arranque guarda, porque es la única que no se deduce:
  # un colegio sin departamentos se ve igual que uno que no los cargó todavía.
  test "un paso opcional se puede omitir y retomar" do
    vacio, director = colegio_vacio
    sign_in director

    post omitir_paso_path("departamentos")
    assert_equal [ "departamentos" ], vacio.reload.pasos_omitidos
    con_el_colegio(vacio) { assert_equal :omitido, paso(:departamentos, vacio).estado }

    post retomar_paso_path("departamentos")
    assert_empty vacio.reload.pasos_omitidos
  end

  # Sin esto, cualquier clave se guardaría en la columna y un paso OBLIGATORIO
  # quedaría escondido: un colegio sin alumnos creyendo que ya arrancó.
  test "no se puede omitir un paso obligatorio" do
    vacio, director = colegio_vacio
    sign_in director

    post omitir_paso_path("alumnos")

    assert_response :not_found
    assert_empty vacio.reload.pasos_omitidos
  end

  # ── la franja ─────────────────────────────────────────────────────────────

  # ⚠️ El parámetro se CONSUME y la URL queda limpia: la que la secretaria copia
  # y manda por WhatsApp tiene que ser `/subjects`, no una con basura pegada.
  test "entrar a un paso guarda el recorrido y limpia la URL" do
    _vacio, director = colegio_vacio
    sign_in director

    get "#{subjects_path}?recorrido=materias"

    assert_redirected_to subjects_path
    follow_redirect!
    assert_select "nav.franja", 1
    assert_match(/Volver al plan/, response.body)
  end

  # El recorrido sobrevive a navegar por dentro sin arrastrar query strings.
  test "la franja sigue en pie al navegar a otra pantalla" do
    _vacio, director = colegio_vacio
    sign_in director
    get "#{subjects_path}?recorrido=materias"

    get teachers_path

    assert_select "nav.franja", 1
    assert_match(/va por/, response.body,
                 "se desvió a otra pantalla y la franja finge que sigue en el paso")
  end

  # Cuando el colegio termina de arrancar, la franja desaparece sola. Nadie la
  # apaga: es la misma pregunta contra los datos.
  test "la franja no aparece en un colegio que ya arrancó" do
    get "#{subjects_path}?recorrido=materias"
    follow_redirect! while response.redirect?

    assert_select "nav.franja", 0
  end

  test "la equis del recorrido lo cierra" do
    _vacio, director = colegio_vacio
    sign_in director
    get "#{subjects_path}?recorrido=materias"
    follow_redirect!
    assert_select "nav.franja", 1

    get "#{subjects_path}?recorrido=salir"
    follow_redirect!

    assert_select "nav.franja", 0
  end

  # ⚠️ «Listo, seguir» es NAVEGACIÓN, no una marca. Presionarlo sin hacer el
  # trabajo deja el paso pendiente — la forma honesta de dejar saltar adelante
  # sin mentir sobre el estado.
  test "seguir sin hacer nada no marca el paso como listo" do
    vacio, director = colegio_vacio
    sign_in director

    get "#{subjects_path}?recorrido=materias"
    follow_redirect!
    get "#{teachers_path}?recorrido=profesores"
    follow_redirect!

    con_el_colegio(vacio) do
      assert_not paso(:materias, vacio).listo?,
                 "avanzar en la franja marcó un paso que nadie hizo"
    end
  end

  # ── las precondiciones en los estados vacíos ──────────────────────────────

  # ⚠️ La precondición se dice DONDE EL PROBLEMA SE VE, no se esconde apagando
  # el menú. Apagar entradas según precondiciones se siente roto y aleatorio
  # —«ayer estaba Secciones»—; el lugar útil es esta pantalla, vacía, con la
  # persona parada acá.
  test "una lista vacía dice qué hace falta antes, y lleva ahí" do
    _vacio, director = colegio_vacio
    sign_in director

    get sections_path

    assert_response :success
    assert_select ".empty-state", 1
    assert_match(/Antes hace falta/, response.body)
    assert_select ".empty-state a.btn", { minimum: 1 },
                  "el estado vacío bloqueado no ofrece salida"
    assert_select "[disabled]", 0
  end

  # Sin precondición pendiente, el estado vacío ofrece hacer el trabajo.
  test "una lista vacía sin bloqueo ofrece cargar" do
    _vacio, director = colegio_vacio
    sign_in director

    get teachers_path

    assert_select ".empty-state", 1
    assert_match(/Todavía no hay profesores/, response.body)
    assert_select ".empty-state a.btn", minimum: 1
  end

  # El texto sale de `PasosDeArranque`: la pantalla y el mapa dicen lo mismo, y
  # renombrar el paso arrastra a los dos.
  test "el estado vacío y el mapa hablan del mismo paso" do
    vacio, director = colegio_vacio
    sign_in director

    esperado = con_el_colegio(vacio) { paso(:profesores, vacio).vacio }

    get teachers_path
    assert_match(/#{Regexp.escape(esperado)}/, response.body)
  end

  # Con datos cargados no hay estado vacío: la tabla ocupa su lugar.
  test "una lista con datos no muestra el estado vacío" do
    get teachers_path

    assert_select ".empty-state", 0
    assert_select "table.table-academic", minimum: 1
  end

  private

  def paso(clave, colegio = @a.colegio)
    PasosDeArranque.para(colegio).find { |p| p.clave == clave }
  end

  def colegio_vacio
    colegio = School.create!(name: "Colegio Recién Nacido", dea_code: "NUEVO-#{Process.pid}",
                             location: "Caracas", school_type: :secondary)
    persona = User.create!(first_name: "Nueva", last_name: "Directora",
                           email: "nueva.directora@aislamiento.test", password: "123123",
                           document: "V-77889900", document_type: :cedula_v)
    Current.sin_aislamiento { Admin.create!(user: persona, school: colegio, role: :director) }

    [ colegio, persona ]
  end
end
