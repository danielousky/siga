require "test_helper"

# «Documentos oficiales», el botón del encabezado de una sección.
#
# Daniel, en la muestra el 13 de octubre de 2026: un enlace directo a los
# documentos de la sección. Lleva a «Documentos» con la sección ya elegida, y
# la sección sigue elegida al pasar de los boletines a las constancias.
class DocumentosDeLaSeccionTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos
  end

  test "la dirección lo tiene en todas las pestañas de la sección" do
    sign_in @a.director

    [ section_path(@a.seccion), alumnos_section_path(@a.seccion), areas_section_path(@a.seccion) ].each do |ruta|
      get ruta

      assert_select "a[href='#{report_cards_path(section_id: @a.seccion.id)}']",
                    { text: /Documentos oficiales/ }, "falta en #{ruta}"
    end
  end

  test "el profesor no: los documentos los emite la dirección o la secretaría" do
    sign_in @a.profesor

    get alumnos_section_path(@a.seccion, area: @a.materia.id)

    assert_select "a[href^='#{report_cards_path}']", count: 0
  end

  test "«Documentos» abre con esa sección, y la conserva entre sus pestañas" do
    otra = con_el_colegio(@a.colegio) { Section.create!(grade: @a.grado, academic_period: @a.periodo, name: "B") }
    sign_in @a.director

    get report_cards_path(section_id: otra.id)

    assert_select "select[name='section_id'] option[selected][value='#{otra.id}']"
    assert_select "a.pestana[href='#{constancias_path(section_id: otra.id)}']"
    assert_select "a.pestana[href='#{certificados_path(section_id: otra.id)}']"
  end

  # ⚠️ Una sección de OTRO año escolar llega elegida igual. El filtro de la
  # sesión la deja fuera de la lista, y caer en la primera sin decir nada es el
  # filtro que aparece puesto y no filtra.
  test "una sección de otro año escolar llega elegida igual" do
    viejo = ano_escolar_viejo(@a.escenario, nombre: "2023-2024")
    vieja = con_el_colegio(@a.colegio) { Section.find_by!(academic_period: viejo) }
    sign_in @a.director

    [ report_cards_path(section_id: vieja.id), certificados_path(section_id: vieja.id) ].each do |ruta|
      get ruta

      assert_select "select[name='section_id'] option[selected][value='#{vieja.id}']",
                    { text: /2023-2024/ }, ruta
    end
  end
end
