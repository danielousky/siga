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
