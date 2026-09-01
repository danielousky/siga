require "test_helper"

# El identificador de una sección: «A», no «Sección A del turno de la mañana».
#
# Daniel, mirando el formulario: *«lo natural del nombre es que siempre sean los
# mismos… debería llamarse identificador en lugar de nombre, esto además permite
# que se entienda como un campo no demasiado libre»*. Y: *«si ya hay secciones
# debería hacerlas seleccionables… se siente como que el sistema está
# autoaprendiendo»*.
#
# ## Por qué el formato importa más de lo que parece
#
# El identificador sale impreso en el boletín y en los documentos del MPPE. Y
# para el índice único, «A », « A» y «a» son secciones DISTINTAS: sin normalizar,
# el mismo colegio crea la sección A dos veces y lo descubre cuando la matrícula
# le queda partida en dos listas.
class IdentificadorDeSeccionTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El formato
  # ══════════════════════════════════════════════════════════════════════════

  test "acepta letras y números, sin espacios ni símbolos" do
    con_el_colegio(@a.colegio) do
      %w[C U1 2 AB].each do |identificador|
        seccion = Section.new(grade: @a.grado, academic_period: @a.periodo,
                              name: identificador, capacity: 30)
        assert seccion.valid?, "«#{identificador}» debería servir: #{seccion.errors.full_messages}"
      end
    end
  end

  test "rechaza espacios, símbolos y texto libre" do
    con_el_colegio(@a.colegio) do
      [ "Sección A", "A-1", "A ", "3° A", "" ].each do |identificador|
        seccion = Section.new(grade: @a.grado, academic_period: @a.periodo,
                              name: identificador, capacity: 30)
        assert_not seccion.valid?, "«#{identificador}» no debería servir como identificador"
      end
    end
  end

  # ⚠️ La normalización es lo que impide la sección duplicada. «a» y «A» pasan
  # los dos el formato, pero para el índice único son dos filas.
  test "se guarda en mayúscula y sin espacios alrededor" do
    con_el_colegio(@a.colegio) do
      seccion = Section.create!(grade: @a.grado, academic_period: @a.periodo,
                                name: "  c  ", capacity: 30)
      assert_equal "C", seccion.name
    end
  end

  test "y por eso «a» choca con la sección «A» que ya existe" do
    con_el_colegio(@a.colegio) do
      repetida = Section.new(grade: @a.grado, academic_period: @a.periodo,
                             name: @a.seccion.name.downcase, capacity: 30)

      assert_not repetida.valid?, "sin normalizar, el colegio tendría dos secciones A"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El vocabulario que el colegio va formando
  # ══════════════════════════════════════════════════════════════════════════

  test "sugiere los identificadores que el colegio ya usa, del más usado al menos" do
    con_el_colegio(@a.colegio) do
      otro = Grade.create!(school: @a.colegio, name: "2do Año")
      Section.create!(grade: otro, academic_period: @a.periodo, name: "A", capacity: 30)
      Section.create!(grade: otro, academic_period: @a.periodo, name: "B", capacity: 30)

      # «A» aparece dos veces y «B» una, así que «A» va primero.
      assert_equal %w[A B], Section.identificadores_usados
    end
  end

  # ⚠️ El vocabulario es del COLEGIO, no del año. Un año nuevo empieza sin
  # secciones, y ahí es justamente cuando la sugerencia más sirve.
  test "el vocabulario sobrevive al cambio de año escolar" do
    nuevo = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end

    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: nuevo.id }

    get new_section_path
    assert_response :success
    assert_select "datalist#identificadores-usados option[value=?]", @a.seccion.name
  end

  test "el formulario ofrece las sugerencias sin encerrar" do
    sign_in @a.director

    get new_section_path

    # Un `input` con `datalist`, no un `select`: el colegio que abre su primera
    # sección «D» tiene que poder escribirla.
    assert_select "input[name='section[name]'][list=?]", "identificadores-usados"
    assert_select "select[name='section[name]']", count: 0
  end

  # ⚠️ Las tres capas, y las tres hacen falta. Sin `pattern`, el error llega
  # después de guardar; sin la clase, quien escribe «c» ve «c» y cree que se
  # guardó así.
  test "el campo impide escribir espacios y se ve en mayúscula" do
    sign_in @a.director

    get new_section_path

    assert_select "input[name='section[name]'][pattern=?]", "[A-Za-z0-9]+"
    assert_select "input[name='section[name]'].campo-mayuscula"
    # ⚠️ La capa que faltaba: `pattern` impide ENVIAR, no escribir. Sin esto se
    # podía teclear «A Ñ{*}¡» y descubrir el error recién al guardar.
    assert_select "input[name='section[name]'][data-controller=?]", "campo-filtrado"
    assert_select "input[name='section[name]'][data-campo-filtrado-permite-value=?]", "A-Za-z0-9"
  end

  test "el rótulo dice «Identificador», no «Nombre»" do
    sign_in @a.director

    get new_section_path

    assert_select "label[for=section_name]", text: /Identificador/
  end

  # Y de punta a punta: el colegio nuevo puede escribir uno que nadie usó.
  test "se puede crear una sección con un identificador nuevo" do
    sign_in @a.director

    post sections_path, params: { section: { name: "d", grade_id: @a.grado.id, capacity: 25 } }

    creada = Current.sin_aislamiento { Section.unscoped.order(:id).last }
    assert_equal "D", creada.name, "se guarda normalizado"
  end

  test "y el error explica qué se admite" do
    sign_in @a.director

    post sections_path, params: { section: { name: "Sección A", grade_id: @a.grado.id, capacity: 25 } }

    assert_response :unprocessable_entity
    assert_select ".alert-danger li", text: /solo admite letras y números/
  end
end
