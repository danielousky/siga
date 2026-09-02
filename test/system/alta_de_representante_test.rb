require "application_system_test_case"

# El alta de un representante pide lo suyo, no lo del alumno (MOR-199).
class AltaDeRepresentanteTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
    visit new_representative_path
  end

  # Daniel: «el representante no tiene cédula escolar» y «tampoco importa el año
  # de nacimiento». Los dos son datos del ALUMNO.
  test "no pide cédula escolar ni fecha de nacimiento" do
    assert_no_selector "input[name='user[cedula_escolar]']"
    assert_no_selector "input[name='user[birth_date]']"
  end

  # Daniel: «en el lugar de masculino o femenino debería decir parentesco».
  test "en vez del sexo, pregunta el parentesco" do
    assert_no_selector "input[name='user[sex]']", visible: :all
    assert_selector "input[name='parentesco_general']", visible: :all, minimum: 4
    assert_text "Parentesco"
  end

  # ⚠️ El alumno SÍ los necesita: la certificación 31059 y el documento de
  # primaria imprimen la fecha de nacimiento, y la cédula escolar es su
  # identificador mientras no tenga cédula.
  test "el alumno los sigue pidiendo" do
    visit new_student_path

    assert_selector "input[name='student[user_attributes][cedula_escolar]']"
    assert_selector "input[name='student[user_attributes][birth_date]']"
  end
end
