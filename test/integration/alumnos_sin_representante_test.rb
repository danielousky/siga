require "test_helper"

# Los alumnos que nadie representa: contarlos bien y poder resolverlo (MOR-180).
#
# ## El bug que había debajo
#
# El panel decía «200 alumnos no tienen representante registrado» en un colegio
# de 200 con cuatro vínculos cargados. La consulta comparaba
# `students.user_id` contra `student_representatives.student_id` —ids de dos
# tablas distintas— así que ninguno coincidía nunca.
#
# ⚠️ Lo peor de ese modo de fallar es que **el número se ve creíble**: un colegio
# que acaba de importar su matrícula sin representantes esperaría justo eso, y
# nadie lo cuestiona hasta que carga uno y el número no baja.
class AlumnosSinRepresentanteTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    @con_representante = @a.alumno
    @representante = con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "MARÍA", last_name: "PÉREZ",
                             email: "maria.sinrep@test.test", document: "V-88776655")
      rep = Representative.create!(user: persona, school: @a.colegio)
      StudentRepresentative.create!(representative: rep, student: @con_representante)
      rep
    end

    @sin_representante = con_el_colegio(@a.colegio) do
      Student.where.not(id: @con_representante.id).first
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Contar bien
  # ══════════════════════════════════════════════════════════════════════════

  test "el scope cuenta solo a los que de verdad no tienen" do
    con_el_colegio(@a.colegio) do
      sin = Student.sin_representante

      assert_not_includes sin, @con_representante,
                          "cuenta como sin representante a uno que sí tiene"
      assert_includes sin, @sin_representante
      assert_equal Student.count - 1, sin.count
    end
  end

  # ⚠️ La comparación es por `id`, no por `user_id`. Con `user_id` el conteo daba
  # la matrícula completa siempre.
  test "un colegio donde todos tienen representante no reporta ninguno" do
    con_el_colegio(@a.colegio) do
      Student.sin_representante.find_each do |alumno|
        StudentRepresentative.create!(representative: @representante, student: alumno)
      end

      assert_equal 0, Student.sin_representante.count,
                    "el conteo compara ids de tablas distintas y nunca llega a cero"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Del aviso al detalle
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «ahí dice que 200 alumnos no tienen representantes registrados,
  # debería llevarme una vista donde me dé el detalle de eso».

  test "el aviso del panel lleva al listado filtrado, no al padrón de representantes" do
    sign_in @a.director

    get dashboards_administrador_url

    # ⚠️ Dentro del bloque «Para atender», no en la página entera: el MENÚ
    # siempre enlaza a `/representantes` y eso está bien.
    assert_select ".pendientes a[href=?]", students_path(sin_representante: 1)
    assert_select ".pendientes a[href=?]", representatives_path, count: 0,
                  message: "el aviso habla de alumnos: el padrón de representantes es donde justamente no están"
  end

  test "el listado filtrado muestra solo a los que faltan" do
    sign_in @a.director

    get students_path(sin_representante: 1)

    assert_response :success
    # ⚠️ Se compara con lo que se VE: el nombre se guarda en mayúscula y se
    # muestra en Tipo Título (`Normaliza.titulo`).
    visibles = css_select("tbody .persona-linea-nombre").map(&:text)

    assert_includes visibles, @sin_representante.user.apellidos_y_nombres
    assert_not_includes visibles, @con_representante.user.apellidos_y_nombres,
                        "el que ya tiene representante no debería aparecer en el filtro"
  end

  test "y sin el filtro salen todos" do
    sign_in @a.director

    get students_path

    visibles = css_select("tbody .persona-linea-nombre").map(&:text)
    assert_includes visibles, @con_representante.user.apellidos_y_nombres
  end

  # ══════════════════════════════════════════════════════════════════════════
  # No preguntar lo deducible
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel: «un enlace a registrar representante que tenga como parámetro el id
  # del estudiante y precargarlo... NO PREGUNTEMOS LO DEDUCIBLE».

  test "la ficha de un alumno sin representante ofrece registrarlo, con él puesto" do
    sign_in @a.director

    get student_path(@sin_representante)

    assert_select ".empty-state h3", text: "Sin representante registrado"
    assert_select "a[href=?]", new_representative_path(alumno_id: @sin_representante.id)
  end

  test "y el formulario abre con su casilla ya marcada" do
    sign_in @a.director

    get new_representative_path(alumno_id: @sin_representante.id)

    assert_response :success
    assert_select "input[type=checkbox][value=?][checked]", @sin_representante.id.to_s
    # ⚠️ Y se DICE: marcar una casilla entre doscientas, en silencio, es una
    # decisión invisible — quien no la vea puede guardar creyendo que no vinculó
    # a nadie.
    assert_match(/Va a quedar como representante de/, response.body)
  end

  test "sin el parámetro, ninguna casilla viene marcada" do
    sign_in @a.director

    get new_representative_path

    assert_select "input[type=checkbox][checked]", count: 0
  end

  # El id viene del request: acotado por el `default_scope`, no por un `if`.
  test "un alumno de otro colegio no se precarga" do
    sign_in @a.director

    get new_representative_path(alumno_id: @b.alumno.id)

    assert_response :success
    assert_select "input[type=checkbox][checked]", count: 0
    assert_no_match(/Va a quedar como representante de/, response.body)
  end

  # Y de punta a punta: se crea y el alumno queda vinculado.
  test "se registra el representante y el alumno queda emparejado" do
    sign_in @a.director

    post representatives_path, params: {
      user: { first_name: "CARMEN", last_name: "LÓPEZ", document: "V-11224488", document_type: "cedula_v" },
      representative: { phone: "0414-1234567" },
      student_ids: [ @sin_representante.id ]
    }

    con_el_colegio(@a.colegio) do
      assert_not_includes Student.sin_representante, @sin_representante.reload,
                          "el alumno debería haber quedado con representante"
    end
  end
end
