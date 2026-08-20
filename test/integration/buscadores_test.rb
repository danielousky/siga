require "test_helper"

# Los tres buscadores de la app, probados escribiendo SIN acentos.
#
# El bug de MOR-137 no era que la búsqueda estuviera rota: era que funcionaba en
# la mitad de los apellidos. "ramos" encontraba a Ramos, "lopez" no encontraba a
# López. Se prueba con uno sin tilde, anda, y se da por bueno.
#
# Por eso cada caso de acá busca **sin acentos un apellido que los lleva**, que
# es lo que hace cualquiera que use el sistema.
class BuscadoresTest < ActionDispatch::IntegrationTest
  setup do
    @a = colegio_completo("Colegio A")

    con_el_colegio(@a.colegio) do
      @alumna = User.create!(first_name: "Ana", last_name: "López", password: "123123",
                             email: "ana.lopez@buscadores.test", document: "V-9001")
      estudiante = Student.create!(user: @alumna, school: @a.colegio, school_card: "BUS-1")
      Enrollment.create!(student: estudiante, section: @a.seccion,
                         enrollment_date: Date.new(2025, 9, 20))
    end
  end

  test "estudiantes · buscar sin tilde encuentra el apellido con tilde" do
    sign_in @a.director

    get students_url(q: "lopez")

    assert_response :success
    assert_match(/López/, response.body, "buscando “lopez” no apareció López")
  end

  test "inscripciones · buscar sin tilde encuentra el apellido con tilde" do
    sign_in @a.director

    get enrollments_url(q: "lopez")

    assert_response :success
    assert_match(/López/, response.body, "buscando “lopez” no apareció López")
  end

  test "auditoría · buscar sin tilde encuentra al usuario con tilde" do
    sign_in @alumna    # deja un registro de login a su nombre
    sign_out @alumna
    sign_in @a.director

    get dashboards_activity_logs_url(usuario_q: "lopez")

    assert_response :success
    assert_match(/López/, response.body, "buscando “lopez” no apareció López")
  end

  # Las cuatro formas de escribirlo tienen que dar lo mismo. Antes solo andaba
  # la exacta con tilde.
  %w[lopez López LOPEZ Lopez].each do |escrito|
    test "estudiantes · “#{escrito}” devuelve lo mismo que las demás formas" do
      sign_in @a.director

      get students_url(q: escrito)

      assert_response :success
      assert_match(/López/, response.body)
    end
  end

  # Y el aislamiento sigue mandando: un buscador más permisivo no puede volverse
  # una rendija entre colegios.
  test "el buscador no alcanza al alumno del otro colegio" do
    b = colegio_completo("Colegio B")
    con_el_colegio(b.colegio) do
      ajena = User.create!(first_name: "Otra", last_name: "López", password: "123123",
                           email: "otra.lopez@buscadores.test", document: "V-9002")
      Student.create!(user: ajena, school: b.colegio, school_card: "BUS-2")
    end

    sign_in @a.director
    get students_url(q: "lopez")

    assert_response :success
    assert_match(/ana\.lopez@buscadores\.test|López/, response.body)
    assert_no_match(/otra\.lopez@buscadores\.test/, response.body,
                    "el buscador cruzó al otro colegio")
  end
end
