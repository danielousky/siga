require "application_system_test_case"

# Un formulario recién abierto tiene que PODER enviarse (MOR-202 · MOR-208).
#
# Daniel, con un código DEA repetido: *«no lo invalidó, sencillamente me devolvió
# a back sin mensaje»*. El servidor sí lo invalidaba; lo que no pasaba es que el
# envío saliera — un `required` sobre un desplegable que llena JavaScript bloquea
# el formulario EN SILENCIO: el navegador no navega y no muestra nada.
#
# ⚠️ Va como test de SISTEMA porque solo un navegador sabe si un formulario se
# puede enviar. Leyendo el HTML, `required` se ve correcto.
class FormularioEnviableTest < ApplicationSystemTestCase
  def llenar_el_registro(correo:, dea:)
    visit new_user_registration_path
    fill_in "user[first_name]", with: "Rosa"
    fill_in "user[last_name]",  with: "Mendoza"
    fill_in "user[email]",      with: correo
    fill_in "user[password]",   with: "clave-larga-123"
    fill_in "user[password_confirmation]", with: "clave-larga-123"
    fill_in "school[name]",     with: "U.E. La Escuelita"
    fill_in "school[dea_code]", with: dea
    check "nivel_primaria"
  end

  test "el registro se puede enviar llenando solo lo visible" do
    dos_colegios_completos
    llenar_el_registro(correo: "rosa@enviable.test", dea: "PD99887766")

    assert page.evaluate_script("document.querySelector('.registro-form').checkValidity()"),
           "el navegador bloquea el envío: " \
           "#{page.evaluate_script("(document.querySelector('.registro-form :invalid') || {}).name")}"

    find(".form-acciones input[type=submit]").click

    # ⚠️ La espera es LARGA a propósito. Registrarse no es guardar una fila:
    # crea el colegio, su año escolar, sus lapsos, los grados del nivel marcado
    # y la cuenta del director. Con cinco segundos, este test fallaba de a
    # ratos cuando la suite entera corría en paralelo y la máquina iba cargada
    # — y el síntoma («sigue en /registrarse») se lee como un formulario roto.
    assert_current_path arranque_listo_path, wait: 20
    assert_text "quedó en orden"
  end

  # ⚠️ El error del servidor tiene que LLEGAR: es el que no se puede saber antes
  # de enviar.
  test "un DEA repetido lo dice, en vez de no hacer nada" do
    a, _b = dos_colegios_completos
    repetido = Current.sin_aislamiento { a.colegio.dea_code }

    llenar_el_registro(correo: "ana@repetido.test", dea: repetido)
    find(".form-acciones input[type=submit]").click

    assert_selector ".alert-danger", text: /DEA/i, wait: 5
  end

  # Daniel: «validamos de una vez allí si el correo está correcto y no existe».
  test "avisa al salir del campo que el correo ya tiene cuenta" do
    a, _b = dos_colegios_completos

    visit new_user_registration_path
    fill_in "user[email]", with: a.profesor.email
    find("#user_first_name").click

    assert_text "ya tiene una cuenta en SIGA", wait: 5
  end
end
