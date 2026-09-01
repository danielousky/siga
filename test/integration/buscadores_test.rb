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

  # ══════════════════════════════════════════════════════════════════════════
  # Buscar como se escribe: varias palabras, en cualquier orden (MOR-183)
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «busqué a López Guzmán en el buscador de estudiantes y no lo
  # encontró. Un primer día con el sistema habría sido frustrante».
  #
  # La versión anterior mandaba el término ENTERO contra cada columna por
  # separado, así que «López Guzmán» solo habría aparecido si esas dos palabras
  # estuvieran juntas en UNA columna. Están en dos: `last_name` y
  # `second_last_name` — que además ni siquiera estaba entre los campos.
  test "los dos apellidos juntos encuentran al alumno" do
    alumno = con_el_colegio(@a.colegio) do
      @a.alumno.user.update!(first_name: "ÁLVARO", last_name: "LÓPEZ", second_last_name: "GUZMÁN")
      @a.alumno
    end
    sign_in @a.director

    [ "López Guzmán", "Guzmán López", "alvaro lopez", "LOPEZ GUZMAN" ].each do |termino|
      get students_path(q: termino)

      encontrados = css_select(".persona-linea-nombre").map(&:text)
      assert_includes encontrados, alumno.user.apellidos_y_nombres,
                      "buscar «#{termino}» no encontró a quien se llama así"
    end
  end

  # ⚠️ Escribir más ACOTA. Con OR entre palabras, agregar un término traería MÁS
  # resultados, que es lo contrario de lo que uno espera de un buscador.
  test "agregar una palabra acota en vez de ampliar" do
    con_el_colegio(@a.colegio) do
      @a.alumno.user.update!(first_name: "ÁLVARO", last_name: "LÓPEZ", second_last_name: "GUZMÁN")
    end
    sign_in @a.director

    get students_path(q: "López")
    con_apellido = css_select(".persona-linea-nombre").size

    get students_path(q: "López zzzz")
    assert_equal 0, css_select(".persona-linea-nombre").size,
                 "la segunda palabra tiene que descartar, no sumar"
    assert con_apellido.positive?
  end

  # Y «no hay» no es lo mismo que «no encontré»: leer «Todavía no hay alumnos»
  # con doscientos cargados dice que la matrícula no existe.
  test "una búsqueda sin resultados no dice que el colegio está vacío" do
    sign_in @a.director

    get students_path(q: "zzz-nadie-se-llama-asi")

    assert_select ".empty-state h3", text: /Ningún alumno coincide/
    assert_no_match(/Todavía no hay alumnos/, response.body)
  end
end
