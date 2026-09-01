require "test_helper"

# Los campos de una persona, iguales en los cuatro formularios (MOR-177).
#
# Daniel, mirando el alta de profesores: *«hay que revisar todos los form y
# todos los campos. Los nombres y apellidos son solo alfabéticos con acentos y
# la Ñ, en mayúsculas y sin espacios al principio y fin... Tipo de documento va
# antes de la cédula y V ó E... un select de dos letras y después el resto de la
# CI, reducción de errores de tipeo»*.
#
# ## Lo que esto protege
#
# Los campos estaban escritos SEIS veces y cada copia se fue separando. Ahora
# viven en `shared/_datos_de_la_persona`, y este test es lo que impide que
# alguien vuelva a escribirlos a mano en una pantalla nueva: si un formulario
# deja de usar el parcial, sus campos dejan de estar filtrados y nadie se entera
# hasta que llegue una cédula con letras.
class CamposDePersonaTest < ActionDispatch::IntegrationTest
  ALTAS = { "profesor" => :new_teacher_path, "alumno" => :new_student_path,
            "administrador" => :new_admin_path }.freeze

  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que no se puede escribir
  # ══════════════════════════════════════════════════════════════════════════

  test "nombres y apellidos solo aceptan letras, acentos y la Ñ" do
    sin_filtro = ALTAS.flat_map do |quien, ruta|
      get send(ruta)
      %w[first_name last_name second_last_name].filter_map do |campo|
        entrada = css_select("input[name*='[#{campo}]']").first
        next "#{quien}/#{campo}: no está" if entrada.nil?

        permite = entrada["data-campo-filtrado-permite-value"]
        next if permite&.include?("ÁÉÍÓÚ") && permite.include?("Ñ") && permite.end_with?(" ")

        "#{quien}/#{campo}: permite «#{permite}»"
      end
    end

    assert_empty sin_filtro,
      "campos de nombre sin el filtro de letras+acentos+Ñ+espacio:\n  " + sin_filtro.join("\n  ")
  end

  # ⚠️ El espacio SÍ se permite —«JOSÉ LUIS», «DE LA CRUZ»— y se recorta al
  # salir. Filtrarlo al escribir haría imposible el segundo nombre.
  test "el nombre se recorta al salir del campo, no al escribir" do
    get new_teacher_path

    entrada = css_select("input[name*='[first_name]']").first
    assert_includes entrada["data-action"], "blur->campo-filtrado#recortar"
    assert_includes entrada["data-action"], "input->campo-filtrado#filtrar"
  end

  test "la cédula solo acepta dígitos" do
    sin_filtro = ALTAS.filter_map do |quien, ruta|
      get send(ruta)
      entrada = css_select("input[name*='[document]']").first
      next "#{quien}: no está" if entrada.nil?
      next if entrada["data-campo-filtrado-permite-value"] == "0-9"

      "#{quien}: permite «#{entrada['data-campo-filtrado-permite-value']}»"
    end

    assert_empty sin_filtro, "la cédula acepta algo más que dígitos:\n  " + sin_filtro.join("\n  ")
  end

  # ⚠️ La cédula ESCOLAR no se filtra como la de identidad: su formato lo fija
  # el MPPE y los guiones son parte del dato.
  test "la cédula escolar sí admite guiones" do
    get new_student_path

    entrada = css_select("input[name*='[cedula_escolar]']").first
    assert entrada, "el alumno tiene que poder cargar su cédula escolar"
    assert_includes entrada["data-campo-filtrado-permite-value"], "-"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El orden y la forma de los controles
  # ══════════════════════════════════════════════════════════════════════════

  # Daniel: «tipo de documento va antes de la cédula». Es el orden en que se dice
  # y se escribe una cédula venezolana, y además el tipo decide cómo se
  # normaliza el número.
  test "el tipo de documento va antes que el número" do
    invertidos = ALTAS.filter_map do |quien, ruta|
      get send(ruta)
      cuerpo = response.body
      tipo = cuerpo.index("[document_type]")
      numero = cuerpo.index(/name="[^"]*\[document\]"/)
      next if tipo.nil? || numero.nil? || tipo < numero

      quien
    end

    assert_empty invertidos, "piden la cédula antes que su tipo: #{invertidos.join(', ')}"
  end

  # Daniel: «podemos ocultar pasaporte o carné diplomático, el día que aparezcan
  # se los agregamos».
  test "solo se ofrecen V y E" do
    get new_teacher_path

    opciones = css_select("select[name*='[document_type]'] option").map { |o| o["value"] }.compact_blank
    assert_equal %w[cedula_v cedula_e], opciones
  end

  # ⚠️ Pero el enum NO se tocó: quien ya tiene pasaporte cargado tiene que poder
  # editar su ficha sin que el select le cambie el tipo en silencio.
  test "y el suyo se agrega si ya tenía otro" do
    con_el_colegio(@a.colegio) { @a.registro_de_profesor.user.update!(document_type: :pasaporte) }

    get edit_teacher_path(@a.registro_de_profesor)

    opciones = css_select("select[name*='[document_type]'] option").map { |o| o["value"] }.compact_blank
    assert_includes opciones, "pasaporte", "editar su ficha le habría cambiado el tipo de documento"
  end

  # Daniel: «sexo puede ser un radio con label tipo botones».
  test "el sexo son botones, no un desplegable" do
    get new_teacher_path

    assert_select "select[name*='[sex]']", count: 0
    assert_select ".opcion-boton input[type=radio][name*='[sex]']", 2
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Las credenciales
  # ══════════════════════════════════════════════════════════════════════════

  test "las dos contraseñas llevan el ojo para ver lo escrito" do
    get new_teacher_path

    assert_select ".password-toggle-group", 2,
                  "la contraseña y su confirmación tienen que poder verse"
  end

  # `type=email` acepta «maria@gmail», que no es una dirección: el correo sale,
  # rebota, y el colegio se entera cuando la mamá llama.
  test "el correo exige un punto en el dominio" do
    get new_teacher_path

    assert_select "input[type=email][pattern]"
  end

  test "y el servidor lo rechaza igual, no solo el navegador" do
    persona = User.new(first_name: "Ana", last_name: "Pérez", email: "maria@gmail", password: "123123")

    assert_not persona.valid?
    assert_includes persona.errors.full_messages.join, "Correo"
  end
end
