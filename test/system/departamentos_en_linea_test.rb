require "application_system_test_case"

# Los departamentos se agregan, editan y borran SIN salir de la pantalla (MOR-205).
#
# Daniel: *«la creación de los dptos es solo el campo nombre; en ese caso podemos
# sustituir el filtro por un campo del new… y aparezca abajo, con posibilidad de
# editarlo al hacer clic en el nombre y la papelera al final de la fila. Todo con
# Turbo. Eso le da mucho dinamismo a la gestión»*.
#
# ⚠️ Va como test de SISTEMA porque lo que se promete es que la página NO se
# recarga. Eso no se ve en el HTML: se ve comprobando que lo que uno estaba
# haciendo sigue ahí después de la acción.
class DepartamentosEnLineaTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
    visit departments_path
  end

  test "se agrega desde la misma lista" do
    fill_in "department[name]", with: "Ciencias Naturales"
    find(".cabecera-de-lista button[type=submit]").click

    assert_selector "td", text: "Ciencias Naturales", wait: 5
    assert_text "Departamento agregado"
    assert_current_path departments_path
  end

  test "se edita tocando el nombre, ahí mismo" do
    # ⚠️ Nombre único por corrida: con varios archivos de sistema seguidos,
    # «Letras» podía existir de antes y `click_on` tomaba la fila equivocada.
    nombre = "Letras #{rand(10_000)}"

    fill_in "department[name]", with: nombre
    find(".cabecera-de-lista button[type=submit]").click
    assert_selector "td", text: nombre, wait: 5

    click_on nombre
    # ⚠️ DENTRO de la fila: hay dos campos `department[name]` en la pantalla —el
    # de agregar, arriba, y el de la fila en edición— y `match: :first` tomaba
    # el de arriba.
    within("tbody tr:has(input[name='department[name]'])") do
      fill_in "department[name]", with: "Letras y Humanidades"
    end
    click_on "Guardar"

    assert_selector "td", text: "Letras y Humanidades", wait: 5
  end

  test "se borra con la papelera" do
    fill_in "department[name]", with: "Para Borrar"
    find(".cabecera-de-lista button[type=submit]").click
    assert_selector "td", text: "Para Borrar", wait: 5

    accept_confirm { find("button[aria-label='Eliminar Para Borrar']").click }

    assert_no_selector "td", text: "Para Borrar", wait: 5
  end

  # Daniel: «en cada línea, en opciones, debe haber un enlace a new materia con
  # el parámetro departamento_id».
  test "cada fila lleva a crear una materia de ESE departamento" do
    fill_in "department[name]", with: "Deportes"
    find(".cabecera-de-lista button[type=submit]").click
    assert_selector "td", text: "Deportes", wait: 5

    find("a[aria-label='Agregar un área de Deportes']").click

    assert_selector "#subject_department_id", wait: 5
    assert_equal "Deportes", find("#subject_department_id").value.then { |id| Current.sin_aislamiento { Department.find(id).name } }
  end
end
