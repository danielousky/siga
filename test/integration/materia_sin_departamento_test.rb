require "test_helper"

# Una materia se crea SIN departamento (QA del 1 de septiembre).
#
# Daniel, en el paso 3 de 8 de la puesta en marcha: *«me pide departamento,
# primero deberían estar creados los departamentos (si los hubiera)»*.
#
# El plan de arranque marcaba el paso de departamentos como `opcional: true`
# desde MOR-154, con el comentario «un colegio de 150 alumnos no tiene
# departamentos». El modelo decía lo contrario. Un colegio recién registrado
# llenaba código y nombre, guardaba, y recibía «Departamento debe existir»: para
# seguir tenía que irse a un paso que la app le presentó como omitible.
class MateriaSinDepartamentoTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
  end

  # ⚠️ La aserción exige las DOS mitades: que la materia exista Y que tenga
  # colegio. Contar filas no alcanza — una materia sin `school_id` se crea, pasa
  # el test, y después no la ve nadie porque el RLS filtra por esa columna.
  #
  # ⚠️ Y se cuenta dentro de `sin_aislamiento`: `unscoped` quita el
  # `default_scope` pero NO el RLS, así que el mismo conteo devuelve cosas
  # distintas antes y después de una petición, según qué colegio quedó fijado.
  test "se crea sin departamento, y queda en el colegio de la sesión" do
    sign_in @a.director

    assert_difference -> { Current.sin_aislamiento { Subject.unscoped.count } }, 1 do
      post subjects_path, params: { subject: { code: "BIO", name: "Biología", department_id: "" } }
    end

    creada = Current.sin_aislamiento { Subject.unscoped.order(:id).last }
    assert_nil creada.department_id, "no se pidió departamento y no debería tener uno"
    assert_equal @a.colegio.id, creada.school_id,
                 "sin colegio la materia no la ve nadie: el RLS filtra por ahí"
  end

  test "y sigue viéndose en el listado del colegio, no en el del vecino" do
    sign_in @a.director
    post subjects_path, params: { subject: { code: "BIO", name: "Biología" } }

    get subjects_path
    assert_select "td", text: "BIOLOGÍA"

    sign_in @b.director
    get subjects_path
    assert_select "td", text: "BIOLOGÍA", count: 0,
                  message: "una materia sin departamento se coló al otro colegio"
  end

  test "con departamento sigue funcionando igual" do
    sign_in @a.director

    post subjects_path, params: { subject: { code: "QUI", name: "Química",
                                             department_id: @a.departamento.id } }

    creada = Current.sin_aislamiento { Subject.unscoped.order(:id).last }
    assert_equal @a.departamento.id, creada.department_id
    assert_equal @a.colegio.id, creada.school_id
  end

  # Lo que Daniel vio en pantalla: tres campos iguales, sin ninguna marca de
  # cuál es obligatorio. La convención de la app es marcar los OPCIONALES.
  test "el formulario dice que el departamento es opcional" do
    sign_in @a.director

    get new_subject_path

    assert_select ".solicitud-opcional", text: "opcional"
  end

  # El plan de puesta en marcha tiene que decir lo mismo que el modelo.
  test "en el plan, los departamentos van antes que las materias" do
    orden = Current.en_el_colegio(@a.colegio) { PasosDeArranque.new(@a.colegio).pasos.map(&:clave) }

    assert orden.index(:departamentos) < orden.index(:materias),
           "el plan manda crear las materias antes que los departamentos que las agrupan"
  end
end
