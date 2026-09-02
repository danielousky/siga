require "application_system_test_case"

# Un formulario recién abierto tiene que PODER enviarse (MOR-202).
#
# Daniel, con un código DEA repetido: *«no lo invalidó, sencillamente me
# devolvió a back sin mensaje»*.
#
# El servidor sí lo invalidaba —«Código DEA ya está en uso»— pero el envío no
# salía: el desplegable de municipio llevaba `required` y lo LLENA JavaScript al
# elegir el estado. Un `required` sobre un control que empieza vacío bloquea el
# formulario **en silencio**: el navegador no navega, no muestra nada y la
# persona ve que no pasa nada.
#
# ⚠️ Va como test de SISTEMA porque solo un navegador de verdad sabe si un
# formulario se puede enviar. Leyendo el HTML, `required` se ve correcto.
class FormularioEnviableTest < ApplicationSystemTestCase
  test "el alta del colegio se puede enviar llenando solo lo visible" do
    dos_colegios_completos

    visit new_user_registration_path
    fill_in "user_first_name", with: "Rosa"
    fill_in "user_last_name",  with: "Mendoza"
    fill_in "user_email",      with: "rosa@enviable.test"
    fill_in "user_password",   with: "clave-larga-123"
    fill_in "user_password_confirmation", with: "clave-larga-123"
    find(".registro-form input[type=submit]").click
    assert_current_path nuevo_mi_colegio_path, wait: 5

    # Lo mínimo que la pantalla pide a la vista: nombre, DEA y estado. El
    # municipio lo llena JavaScript y puede quedarse sin elegir.
    fill_in "school[name]", with: "U.E. La Escuelita"
    fill_in "school[dea_code]", with: "PD99887766"
    select "Distrito Capital", from: "school[entidad_federal]"

    assert page.evaluate_script("document.querySelector('.registro-form').checkValidity()"),
           "el navegador bloquea el envío: " \
           "#{page.evaluate_script("(document.querySelector('.registro-form :invalid') || {}).name")}"

    find("input[type=submit]", match: :first).click

    assert_current_path dashboards_administrador_path, wait: 5
  end

  # ⚠️ Y el error del servidor tiene que LLEGAR: es el que no se puede saber
  # antes de enviar.
  test "un DEA repetido lo dice, en vez de no hacer nada" do
    a, _b = dos_colegios_completos
    repetido = Current.sin_aislamiento { School.first.dea_code }

    visit new_user_registration_path
    fill_in "user_first_name", with: "Ana"
    fill_in "user_last_name",  with: "Rojas"
    fill_in "user_email",      with: "ana@repetido.test"
    fill_in "user_password",   with: "clave-larga-123"
    fill_in "user_password_confirmation", with: "clave-larga-123"
    find(".registro-form input[type=submit]").click
    assert_current_path nuevo_mi_colegio_path, wait: 5

    fill_in "school[name]", with: "U.E. Otra"
    fill_in "school[dea_code]", with: repetido
    select "Distrito Capital", from: "school[entidad_federal]"
    find("input[type=submit]", match: :first).click

    assert_selector ".alert-danger", text: /DEA/i, wait: 5
    assert_selector "input.campo-con-error", minimum: 1
  end
end
