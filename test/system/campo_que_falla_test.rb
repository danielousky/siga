require "application_system_test_case"

# El campo que falló se distingue de los demás (MOR-196).
#
# Daniel, dos veces el mismo día: «me faltó el Código DEA y no me arrojó error,
# sino que me volvió a cargar la página» y «intenté crear una materia vacía y no
# me arrojó ningún error».
#
# ⚠️ Va como test de SISTEMA porque el problema es de PERCEPCIÓN: el HTML del
# error siempre estuvo ahí —422, resumen rojo, mensaje correcto— y aun así no se
# veía. Lo que hay que comprobar es que el campo culpable se vea distinto en un
# navegador de verdad.
class CampoQueFallaTest < ApplicationSystemTestCase
  setup do
    @a, _b = dos_colegios_completos
    entrar_como(@a.director)
  end

  def enviar_vacio(ruta)
    visit ruta
    find(".form-acciones input[type=submit]").click
    assert_selector ".alert-danger", wait: 5
  end

  test "en un formulario con modelo, el campo inválido queda marcado" do
    enviar_vacio(new_subject_path)

    # El campo que falló tiene que verse distinto de los demás.
    assert_selector "input.campo-con-error", minimum: 1
  end

  # ⚠️ Rails envolvía en `.field_with_errors`, un `div` extra dentro del
  # `.form-group` que además desacomoda la fila. Ya no se usa.
  test "no queda la envoltura de Rails, que desacomodaba la fila" do
    enviar_vacio(new_subject_path)

    assert_no_selector ".field_with_errors"
  end

  # La etiqueta NO se marca: pintar de rojo el nombre del campo además del campo
  # es decir dos veces lo mismo.
  test "la etiqueta se queda como estaba" do
    enviar_vacio(new_subject_path)

    assert_no_selector "label.campo-con-error"
  end
end
