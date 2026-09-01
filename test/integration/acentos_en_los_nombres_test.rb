require "test_helper"

# Se tiene que poder escribir «José», y después encontrarlo (MOR-191).
#
# Daniel, cargando un profesor: *«en el caso de los nombres de entidades
# (profes, alumnos, admins, materias, dptos) debe permitir poder agregar
# acentos, lo intenté y me sale sin acento»*.
#
# Eran dos fallas encadenadas, y la segunda es la fea: el acento descompuesto
# se GUARDA bien y se VE bien, pero el buscador no lo encuentra. En Venezuela
# eso son López, Pérez, Guzmán, Rodríguez, Martínez, Hernández, Díaz y Gómez.
class AcentosEnLosNombresTest < ActionDispatch::IntegrationTest
  setup { @colegio = escenario_academico.colegio }

  # ── la canonización ──────────────────────────────────────────────────────

  test "el acento descompuesto se guarda igual que el precompuesto" do
    assert_equal Normaliza.mayuscula("lópez"),
                 Normaliza.mayuscula("lópez".unicode_normalize(:nfd)),
                 "las dos formas de escribir Ó tienen que terminar iguales"
  end

  test "el titulo tambien canoniza" do
    assert_equal "López", Normaliza.titulo("LÓPEZ".unicode_normalize(:nfd))
  end

  # ⚠️ La aserción que importa. Que se guarde con acento no alcanza: la
  # pregunta es si después aparece al buscarlo.
  test "un apellido guardado descompuesto SI lo encuentra el buscador" do
    con_el_colegio(@colegio) do
      persona = User.create!(first_name: "josé".unicode_normalize(:nfd),
                             last_name: "lópez".unicode_normalize(:nfd),
                             document: "31415926", document_type: :cedula_v)

      assert_equal "LÓPEZ".unicode_normalize(:nfc), persona.reload.last_name,
                   "se guarda canonizado"

      encontrados = User.where(*BusquedaSinAcentos.condicion(%w[first_name last_name], "lopez"))
      assert_includes encontrados, persona,
                      "sin canonizar, translate() no aplana la tilde suelta y el apellido queda mudo"
    end
  end

  # ── la lista de letras ───────────────────────────────────────────────────

  # ⚠️ El invariante: si se puede escribir, se tiene que poder encontrar. Con
  # dos listas escritas a mano se desparejan, y una persona existe sin aparecer.
  test "toda letra que se puede escribir la sabe aplanar el buscador" do
    permitidas = Normaliza::LETRAS_DE_NOMBRE.delete("A-Za-z '-")

    permitidas.each_char do |letra|
      assert_includes BusquedaSinAcentos::ACENTOS + BusquedaSinAcentos::ACENTOS.upcase, letra,
                      "#{letra} se puede teclear pero el buscador no la aplana"
    end
  end

  test "los apellidos que de verdad hay en Venezuela pasan el filtro" do
    sobra = /[^#{Normaliza::LETRAS_DE_NOMBRE}]/

    %w[JOSÉ NÚÑEZ GONÇALVES JOÃO MARÍA-JOSÉ].each do |nombre|
      assert_no_match sobra, nombre, "#{nombre} no se puede escribir en el formulario"
    end
    assert_no_match sobra, "D'ANGELO"
  end

  test "y lo que no es una letra sigue sin pasar" do
    sobra = /[^#{Normaliza::LETRAS_DE_NOMBRE}]/

    [ "JOSE3", "JOSE{*}", "JOSE@CASA" ].each do |basura|
      assert_match sobra, basura, "#{basura} tendría que rechazarse"
    end
  end

  # ── la vista ─────────────────────────────────────────────────────────────

  test "el formulario no escribe su propia lista de letras" do
    partial = Rails.root.join("app/views/shared/_datos_de_la_persona.html.haml").read

    assert_includes partial, "Normaliza::LETRAS_DE_NOMBRE"
    assert_no_match(/permite_value: "A-Za-z[ÁÉÍÓÚ]/, partial,
                    "la lista quedó copiada a mano y se va a desparejar")
  end

  # ⚠️ Sin esto, la tecla muerta vuelve a romper: el `´` a medio componer se
  # borra y asignar `value` cancela la composición.
  test "el controlador no toca el campo mientras se compone un acento" do
    js = Rails.root.join("app/javascript/controllers/campo_filtrado_controller.js").read

    assert_includes js, "compositionstart"
    assert_includes js, "compositionend"
    assert_includes js, 'normalize("NFC")'
  end
end
