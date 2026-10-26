require "test_helper"

# «Áreas y profesores»: quién dicta qué en una sección, en su propia pestaña.
#
# Fue una segunda tarjeta debajo de la lista de «Alumnos» hasta que Daniel,
# mirando la muestra el 13 de octubre de 2026: *«esta sección va como una
# pestaña adicional después de Alumnos»*. Es de la DIRECCIÓN, que es quien
# asigna.
class AreasYProfesoresTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
  end

  test "la dirección la tiene, justo después de «Alumnos»" do
    sign_in @a.director

    get alumnos_section_path(@a.seccion)

    pestanas = css_select(".pestana").map { |p| p.text.squish }
    # «Horario» va al final: es de la sección entera (spec `horarios`, decisión 29).
    assert_equal [ "Alumnos", "Áreas y profesores", "Horario" ], pestanas.last(3)
  end

  test "dice quién dicta cada área, y cuál se quedó sin nadie" do
    fisica = con_el_colegio(@a.colegio) do
      Subject.create!(department: @a.departamento, code: "FIS", name: "Física")
             .tap { |area| GradeSubject.create!(grade: @a.grado, subject: area) }
    end
    sign_in @a.director

    get areas_section_path(@a.seccion)

    assert_response :success
    assert_select ".pestana.activa", text: "Áreas y profesores"
    assert_select "tbody tr", text: /Matemática.*#{@a.profesor.nombre_completo}/m
    assert_select "tbody tr", text: /Física.*Sin asignar/m
    # Se asigna desde el área: es donde vive ese formulario.
    assert_select "tbody tr a[href='#{subject_path(fisica)}']", text: "Asignar"
    assert_select "h2", text: /2 áreas, 1 sin profesor/
  end

  test "y ya no cuelga debajo de la lista de alumnos" do
    sign_in @a.director

    get alumnos_section_path(@a.seccion)

    assert_select "th", text: Teacher.model_name.human, count: 0
  end

  # No es un secreto —son sus compañeros— pero es una lista que no usa.
  test "el profesor no la ve, y si llega por la dirección vuelve a «Alumnos»" do
    sign_in @a.profesor

    get alumnos_section_path(@a.seccion, area: @a.materia.id)
    assert_select ".pestana", text: /y profesores/, count: 0

    get areas_section_path(@a.seccion, area: @a.materia.id)
    assert_redirected_to alumnos_section_path(@a.seccion, area: @a.materia.id)
  end
end
