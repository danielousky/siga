require "test_helper"

# El formulario de una evaluación (MOR-223).
class FormularioDeEvaluacionTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
  end

  # ⚠️ Cada sección UNA vez. Un colegio que ya copió su estructura al año
  # siguiente tiene las mismas secciones en los dos, y el desplegable las
  # mostraba todas: treinta y dos renglones donde había dieciséis asignaciones.
  #
  # Daniel lo vio como «1er Año – A · Matemática» arriba de «1er Año – A ·
  # Matemática». Y no era solo feo: el segundo renglón crea la evaluación en el
  # año que viene, sin que nada lo diga.
  test "el desplegable no repite la sección del año siguiente" do
    con_el_colegio(@a.colegio) do
      que_viene = AcademicPeriod.create!(name: "2026-2027", start_date: Date.new(2026, 9, 15),
                                         end_date: Date.new(2027, 7, 31))
      copia = Section.create!(grade: @a.grado, academic_period: que_viene,
                              name: @a.seccion.name, capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: copia,
                             subject: @a.escenario.materia)
    end

    sign_in @a.profesor
    get new_evaluation_activity_path

    assert_response :success
    opciones = css_select("#evaluation_activity_asignacion option").map { |o| o.text.strip }
                 .reject(&:empty?)
    assert_equal opciones.uniq, opciones,
                 "cada sección tiene que aparecer UNA vez: la del año que viene no es otra opción"
  end
end
