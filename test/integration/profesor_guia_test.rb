require "test_helper"

# El guía es de la sección; el coordinador, del grado (MOR-209).
#
# ## Por qué este test mira PALABRAS y no solo comportamiento
#
# Al renombrar la columna busqué el identificador —`leader_teacher`— y arreglé
# todos sus usos. El listado de grados siguió mostrando **«Profesor guía»** como
# encabezado, porque ese texto es un literal en la plantilla y no contiene el
# nombre de ninguna columna. Lo encontró Daniel, mirando la pantalla.
#
# El comportamiento estaba bien y la etiqueta mentía, que en esta zona es lo
# mismo que estar mal: la confusión que este cambio vino a deshacer es de
# vocabulario, y una vista que llama «profesor guía» al coordinador la reinstala
# entera.
class ProfesorGuiaTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
    con_el_colegio(@a.colegio) do
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
      @a.grado.update!(coordinator_teacher: @a.registro_de_profesor)
    end
  end

  # ── el vocabulario ────────────────────────────────────────────────────────

  test "las pantallas del grado hablan de coordinador, nunca de profesor guía" do
    [ grades_path, grade_path(@a.grado), edit_grade_path(@a.grado) ].each do |ruta|
      get ruta

      assert_response :success
      assert_match(/[Cc]oordinador/, response.body,
                   "#{ruta} no nombra al coordinador por ningún lado")
    end
  end

  test "el listado de grados NO rotula la columna como profesor guía" do
    get grades_path

    encabezados = css_select("th").map(&:text).map(&:strip)

    assert_includes encabezados, "Coordinador"
    assert_not_includes encabezados, "Profesor guía",
                        "el listado de grados volvió a llamar «profesor guía» al " \
                        "coordinador: es la confusión que MOR-209 vino a deshacer"
  end

  test "las pantallas de la sección sí hablan de profesor guía" do
    [ sections_path, section_path(@a.seccion) ].each do |ruta|
      get ruta

      assert_response :success
      assert_match(/Profesor guía/, response.body,
                   "#{ruta} no dice quién es el profesor guía, que es de la sección")
    end
  end

  # ── lo vinculado ──────────────────────────────────────────────────────────

  # Desde el grado se ve el guía de CADA sección. Es lo que el listado no podía
  # mostrar cuando el guía colgaba del grado —era el mismo para todas— y es donde
  # el director ve de un vistazo cuál se quedó sin asignar.
  test "la ficha del grado muestra el guía de cada una de sus secciones" do
    otra = con_el_colegio(@a.colegio) do
      Section.create!(grade: @a.grado, academic_period: @a.seccion.academic_period,
                      name: "Z", capacity: 30, leader_teacher: nil)
    end

    get grade_path(@a.grado)

    listado = css_select("li.ficha-seccion").map(&:text).map(&:squish)

    assert listado.any? { |l| l.include?("guía:") },
           "la sección con guía no lo muestra en la ficha del grado"
    assert listado.any? { |l| l.include?("Sin profesor guía") },
           "la sección #{otra.name} no tiene guía y la ficha del grado no lo avisa"
  end

  test "la ficha del profesor distingue lo que guía de lo que coordina" do
    get teacher_path(@a.registro_de_profesor)

    assert_response :success
    assert_match(/guía de/, response.body, "no dice de qué sección es guía")
    assert_match(/coordina/, response.body, "no dice qué grado coordina")
  end

  # ── el formulario ─────────────────────────────────────────────────────────

  # Un rótulo correcto no alcanza si el campo no se guarda: el `permit` es donde
  # un renombre se queda a medias sin que nada falle — el formulario acepta, y el
  # valor se descarta en silencio.
  test "el guía se puede asignar desde el formulario de la sección" do
    otro = con_el_colegio(@a.colegio) do
      persona = User.create!(first_name: "Otra", last_name: "Guía",
                             email: "otra.guia@aislamiento.test", password: "123123",
                             document: "V-11223399", document_type: :cedula_v)
      Teacher.create!(user: persona, school: @a.colegio)
    end

    patch section_path(@a.seccion), params: { section: { leader_teacher_id: otro.id } }

    assert_equal otro.id, @a.seccion.reload.leader_teacher_id,
                 "el formulario de la sección no guarda el profesor guía"
  end

  test "el coordinador se puede asignar desde el formulario del grado" do
    patch grade_path(@a.grado), params: { grade: { coordinator_teacher_id: @a.registro_de_profesor.id } }

    assert_equal @a.registro_de_profesor.id, @a.grado.reload.coordinator_teacher_id,
                 "el formulario del grado no guarda el coordinador"
  end
end
