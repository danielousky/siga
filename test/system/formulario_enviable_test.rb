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
  def llenar_el_registro(correo:)
    visit new_user_registration_path
    fill_in "user[first_name]", with: "Rosa"
    fill_in "user[last_name]",  with: "Mendoza"
    fill_in "user[email]",      with: correo
    fill_in "user[password]",   with: "clave-larga-123"
    fill_in "user[password_confirmation]", with: "clave-larga-123"
    fill_in "school[name]",     with: "U.E. La Escuelita"
    # ⚠️ El código DEA ya NO se pide acá (`MOR-208`, segunda mitad): lo asigna
    # el ministerio y nadie lo tiene en la cabeza. Se carga después, en «La
    # identidad del colegio».
    check "nivel_primaria"
  end

  test "el registro se puede enviar llenando solo lo visible" do
    dos_colegios_completos
    llenar_el_registro(correo: "rosa@enviable.test")

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
  #
  # ⚠️ Antes se probaba con un código DEA repetido, y ese camino desapareció
  # cuando el registro dejó de pedirlo. Lo que el test cuida no es el DEA: es
  # que un rechazo del SERVIDOR se vea en la pantalla en vez de no pasar nada.
  # El correo ya tomado sirve igual — y es además el caso que de verdad ocurre.
  test "un correo ya tomado lo dice, en vez de no hacer nada" do
    a, _b = dos_colegios_completos
    tomado = Current.sin_aislamiento { a.director.email }

    llenar_el_registro(correo: tomado)
    find(".form-acciones input[type=submit]").click

    assert_selector ".alert-danger, .campo-con-error, .form-error", wait: 10
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
