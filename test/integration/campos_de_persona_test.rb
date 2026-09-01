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
  # ⚠️ El representante está en la lista, y no estaba: era el único que armaba
  # sus campos con `text_field_tag` a mano, así que se quedó fuera del parcial y
  # se notó en pantalla —pedía la cédula antes que su tipo, ofrecía los cuatro
  # tipos y no filtraba nada—. Lo vio Daniel.
  ALTAS = { "profesor" => :new_teacher_path, "alumno" => :new_student_path,
            "administrador" => :new_admin_path,
            "representante" => :new_representative_path }.freeze

  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que no se puede escribir
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Se compara contra `Normaliza::LETRAS_DE_NOMBRE`, no contra una lista
  # escrita acá (MOR-191).
  #
  # Antes esta aserción exigía la cadena literal, y por eso se rompió el día que
  # la lista creció para admitir Gonçalves y João: fallaba un test cuyo tema es
  # «el campo tiene filtro», por un cambio que era exactamente lo que se quería.
  # Un test que copia el valor esperado prueba que nadie lo cambió, no que esté
  # bien.
  test "nombres y apellidos solo aceptan letras de nombre" do
    sin_filtro = ALTAS.flat_map do |quien, ruta|
      get send(ruta)
      %w[first_name last_name second_last_name].filter_map do |campo|
        entrada = css_select("input[name*='[#{campo}]']").first
        next "#{quien}/#{campo}: no está" if entrada.nil?

        permite = entrada["data-campo-filtrado-permite-value"]
        next if permite == Normaliza::LETRAS_DE_NOMBRE

        "#{quien}/#{campo}: permite «#{permite}»"
      end
    end

    assert_empty sin_filtro,
      "campos de nombre que no usan Normaliza::LETRAS_DE_NOMBRE:\n  " + sin_filtro.join("\n  ")
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

  # Daniel: «no hace falta colocarlo completo Cédula de Identidad; con colocar la
  # V y la E se entiende». Pegado al número, «Cédula de identidad (V)» no cabe ni
  # hace falta.
  test "el select dice solo la sigla" do
    get new_teacher_path

    assert_equal %w[V E], css_select("select[name*='[document_type]'] option").map { |o| o.text.strip }
  end

  # ⚠️ UN campo, no dos: una cédula venezolana es «V-12345678», una sola cosa.
  test "el tipo y el número son un solo campo, con un solo rótulo" do
    sueltos = ALTAS.filter_map do |quien, ruta|
      get send(ruta)
      next "#{quien}: no están juntos" if css_select(".campo-compuesto select[name*='[document_type]']").empty?
      next if css_select("label[for*='document_type']").empty?

      "#{quien}: el tipo todavía tiene su propio rótulo"
    end

    assert_empty sueltos, "la cédula sigue partida en dos campos:\n  " + sueltos.join("\n  ")
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
