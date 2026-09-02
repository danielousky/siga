require "test_helper"

# El día 1 de un cliente nuevo: un colegio sin absolutamente nada.
#
# Es el estado en el que está TODO colegio que se registra por `/registrarse`
# (MOR-158), y el que menos se prueba: los tests arman escenarios completos
# porque es lo que hace falta para probar cualquier otra cosa.
#
# El QA de Daniel del 1 de septiembre encontró dos callejones acá: entrar a
# `/materias/new` y recibir «Departamento debe existir» —de un paso que la app
# presenta como opcional— y entrar a `/secciones/new` y ver tres desplegables
# vacíos sin ninguna explicación.
class ColegioVacioTest < ActionDispatch::IntegrationTest
  setup do
    @colegio = Current.sin_aislamiento do
      School.create!(name: "Colegio Recién Registrado", dea_code: "TESTVACIO", location: "Caracas")
    end
    @director = User.create!(first_name: "Directora", last_name: "Nueva",
                             email: "dir.colegio.vacio@test.test", password: "123123",
                             document: "V-77665544", document_type: :cedula_v)
    con_el_colegio(@colegio) { Admin.create!(user: @director, school: @colegio, role: :director) }
  end

  # ⚠️ Que responda 200 no alcanza: un callejón responde 200. Lo que se exige es
  # que la pantalla DIGA algo — o el formulario, o por qué todavía no.
  ALTAS = {
    "/materias/new"      => "materias",
    "/secciones/new"     => "secciones",
    "/inscripciones/new" => "inscripciones",
    "/lapsos/new"        => "lapsos",
    "/grados/new"        => "grados",
    "/departamentos/new" => "departamentos",
    "/profesores/new"    => "profesores",
    "/alumnos/new"       => "alumnos"
  }.freeze

  test "ningún formulario de alta es un callejón en un colegio vacío" do
    sign_in @director

    mudos = ALTAS.filter_map do |ruta, que|
      get ruta
      next "#{ruta} → #{response.status}" unless response.successful?

      # O hay un formulario que se puede llenar, o hay un cartel que explica por
      # qué todavía no. Las dos cosas juntas también valen; ninguna, no.
      hay_form   = css_select("form input[type=text], form input[type=date], form textarea").any?
      hay_cartel = css_select(".empty-state h3, .nota-ayuda").any?

      "#{ruta} (#{que}): ni formulario que llenar ni explicación" unless hay_form || hay_cartel
    end

    assert_empty mudos, "formularios de alta que dejan a un colegio nuevo sin saber qué hacer:\n  " +
                        mudos.join("\n  ")
  end

  # El caso exacto de Daniel: el paso 3 del plan, en un colegio sin
  # departamentos. Antes devolvía «Departamento debe existir».
  test "se puede crear la primera materia sin haber creado ningún departamento" do
    sign_in @director

    post subjects_path, params: { subject: { code: "MAT", name: "Matemática" } }

    creada = Current.sin_aislamiento { Subject.unscoped.find_by(code: "MAT", school_id: @colegio.id) }
    assert creada, "un colegio nuevo no pudo crear su primera materia"
    assert_equal @colegio.id, creada.school_id
  end

  # Y el que NO se puede todavía tiene que decir qué falta y llevar hasta ahí.
  test "una sección sin grados explica qué falta y ofrece el camino" do
    sign_in @director

    get new_section_path

    assert_select ".empty-state h3", text: /Todavía no se puede crear una sección/
    assert_select ".empty-state strong", text: /niveles/
    assert_select ".empty-state a[href*='niveles']"
  end

  # El panel es lo primero que ve, y tiene que abrir aunque no haya NADA.
  test "el panel abre y no explota sin datos" do
    sign_in @director

    get dashboards_administrador_url

    assert_response :success
    assert_select ".contexto-colegio-nombre", text: @colegio.name
  end
end
