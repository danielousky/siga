require "test_helper"

# ⚠️ No confundir con `formularios_test.rb`, que prueba otra cosa: que todos
# los formularios se VEAN como el mismo producto (misma estructura, sin
# `fieldset` sin estilo, sin campos repetidos). Este prueba cómo se PORTAN
# cuando alguien guarda con los campos vacíos.
#
# Todos los formularios: que validen, que lo digan, y que se puedan volver a
# llenar sin perder lo escrito.
#
# Sale del QA de Daniel del 1/9: *«le di guardar y no validó ningún campo de la
# materia. Revisa los formularios»*. Ahí el problema era otro —el departamento
# era obligatorio y no debía serlo— pero la pregunta de fondo quedó: ¿qué hacen
# TODOS los formularios cuando alguien guarda con los campos vacíos?
#
# ## Las tres cosas que se exigen
#
#   1. **No se guarda.** Un alta vacía que pasa deja una fila fantasma.
#   2. **Se dice qué falta**, en español y campo por campo. Un 422 en blanco es
#      un formulario que se recarga solo y nadie sabe por qué.
#   3. **Se responde 422**, no 200: Turbo solo re-renderiza el formulario si el
#      estado dice que no se pudo procesar.
class ValidacionDeFormulariosTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
    sign_in @a.director
  end

  # Cada alta con su modelo, para poder afirmar que NO se creó nada.
  ALTAS = {
    # ⚠️ La forma de los parámetros se toma del FORMULARIO, no se inventa.
    # `Student` y `Teacher` usan `fields_for :user` dentro del modelo; el de
    # representante manda `user[...]` como clave de primer nivel. Mandar la
    # forma equivocada da un 400 por `ParameterMissing` y el test dice que la
    # app está rota cuando la rota es la prueba.
    "alumno"         => [ :students_path, Student, { student: { user_attributes: { first_name: "" } } } ],
    "profesor"       => [ :teachers_path, Teacher, { teacher: { user_attributes: { first_name: "" } } } ],
    "representante"  => [ :representatives_path, Representative, { representative: { phone: "" }, user: { first_name: "" } } ],
    "grado"          => [ :grades_path, Grade, { grade: { name: "" } } ],
    "sección"        => [ :sections_path, Section, { section: { name: "", capacity: "" } } ],
    "materia"        => [ :subjects_path, Subject, { subject: { code: "", name: "" } } ],
    "departamento"   => [ :departments_path, Department, { department: { name: "" } } ],
    "inscripción"    => [ :enrollments_path, Enrollment, { enrollment: { student_id: "", section_id: "" } } ],
    "lapso"          => [ :evaluation_moments_path, EvaluationMoment, { evaluation_moment: { name: "" } } ]
  }.freeze

  test "ningún formulario de alta guarda una fila vacía" do
    fugas = ALTAS.filter_map do |que, (ruta, modelo, params)|
      antes = Current.sin_aislamiento { modelo.unscoped.count }
      post public_send(ruta), params: params
      despues = Current.sin_aislamiento { modelo.unscoped.count }

      "#{que}: se creó un #{modelo.name} con los campos vacíos" if despues > antes
    end

    assert_empty fugas, "altas que aceptan basura:\n  " + fugas.join("\n  ")
  end

  test "y todos dicen QUÉ falta, en español" do
    mudos = ALTAS.filter_map do |que, (ruta, _modelo, params)|
      post public_send(ruta), params: params

      # ⚠️ 422 y no 200: Turbo solo vuelve a pintar el formulario si el estado
      # dice que no se pudo procesar. Con 200 la pantalla se queda igual y
      # parece que el botón no hizo nada.
      next "#{que}: respondió #{response.status} en vez de 422" unless response.status == 422

      errores = css_select(".alert-danger li").map(&:text)
      next "#{que}: 422 sin ningún error escrito" if errores.empty?

      # Que estén en español: `User` sin traducir decía «First name no puede
      # estar en blanco» y así estuvo hasta MOR-151.
      en_ingles = errores.grep(/\b(First|Last|Name|Code|Blank|must exist|can't be)\b/)
      "#{que}: errores en inglés → #{en_ingles.join(', ')}" if en_ingles.any?
    end

    assert_empty mudos, "formularios que no explican el fallo:\n  " + mudos.join("\n  ")
  end

  # Lo que más molesta de un formulario que falla: tener que escribir todo otra
  # vez. Rails lo hace solo si el controller re-renderiza el objeto con sus
  # atributos — y se pierde si alguien hace `redirect_to` en el `else`.
  test "el formulario vuelve con lo que la persona ya había escrito" do
    post subjects_path, params: { subject: { code: "BIO", name: "" } }

    assert_response :unprocessable_entity
    assert_select "input[name='subject[code]'][value=?]", "BIO",
                  message: "el código escrito se perdió: hay que tipearlo de nuevo"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Las ediciones
  # ══════════════════════════════════════════════════════════════════════════

  def ediciones
    { "alumno"        => [ student_path(@a.alumno),
                           { student: { user_attributes: { id: @a.alumno.user_id, first_name: "" } } } ],
      "profesor"      => [ teacher_path(@a.registro_de_profesor),
                           { teacher: { user_attributes: { id: @a.registro_de_profesor.user_id, first_name: "" } } } ],
      "grado"         => [ grade_path(@a.grado), { grade: { name: "" } } ],
      "sección"       => [ section_path(@a.seccion), { section: { name: "" } } ],
      "materia"       => [ subject_path(@a.materia), { subject: { name: "" } } ],
      "departamento"  => [ department_path(@a.departamento), { department: { name: "" } } ],
      "año escolar"   => [ academic_period_path(@a.periodo), { academic_period: { name: "" } } ] }
  end

  test "ninguna edición deja vaciar un campo obligatorio" do
    fugas = ediciones.filter_map do |que, (ruta, params)|
      patch ruta, params: params
      next "#{que}: respondió #{response.status} en vez de 422" unless response.status == 422
      next if css_select(".alert-danger li").any?

      "#{que}: rechazó el cambio y no dijo por qué"
    end

    assert_empty fugas, "ediciones que fallan en silencio:\n  " + fugas.join("\n  ")
  end

  # ⚠️ `departamento` NO está en esta lista desde MOR-205: no tiene pantalla de
  # edición. Se edita en la propia fila del listado, con un Turbo Stream, y por
  # eso `GET /departamentos/:id/edit` en HTML manda al listado —que es donde se
  # edita— en vez de abrir un formulario que ya no existe. Lo cuida
  # `departamentos_en_linea_test`, que lo prueba en un navegador.
  test "las pantallas de edición se abren todas" do
    rotas = { "alumno" => edit_student_path(@a.alumno),
              "profesor" => edit_teacher_path(@a.registro_de_profesor),
              "grado" => edit_grade_path(@a.grado),
              "sección" => edit_section_path(@a.seccion),
              "materia" => edit_subject_path(@a.materia),
              "año escolar" => edit_academic_period_path(@a.periodo),
              "lapso" => edit_evaluation_moment_path(@a.lapso(1)),
              "inscripción" => edit_enrollment_path(@a.inscripcion) }.filter_map do |que, ruta|
      get ruta
      next "#{que} → #{response.status}" unless response.successful?
      next if css_select("form[method=post] input, form[method=post] select, form[method=post] textarea").any?

      "#{que}: la pantalla de edición no trae campos"
    end

    assert_empty rotas, "ediciones rotas:\n  " + rotas.join("\n  ")
  end
end
