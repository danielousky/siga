require "test_helper"

# Los ajustes sueltos de la plataforma: una fila por dato, con su nombre y su
# valor (spec `docs/specs/del-registro-al-cobro.md`, decisión 35).
#
#     whatsapp             0414-1234567                    los botones y el efectivo
#     url_de_la_muestra    https://demo.sigaeducando.com   «Vea un colegio funcionando»
class SetupTest < ActiveSupport::TestCase
  include CobroDeLaSuscripcion

  # ── Solo los nombres que el código conoce ─────────────────────────────────

  # Una fila que nadie lee es un ajuste que alguien cree haber cambiado.
  test "un nombre que el código no conoce no se puede crear" do
    fila = Setup.new(nombre: "color_del_logo", valor: "azul")

    assert fila.invalid?
    assert fila.errors[:nombre].any?
  end

  # Dos filas «whatsapp» son dos números, y nadie sabe cuál está en la portada.
  test "la base no admite el mismo nombre dos veces" do
    poner_el_whatsapp("0414-1234567")

    assert_raises(ActiveRecord::RecordNotUnique) do
      Setup.transaction(requires_new: true) do
        Setup.new(nombre: "whatsapp", valor: "0416-0000000").save!(validate: false)
      end
    end
  end

  # ── El WhatsApp ───────────────────────────────────────────────────────────

  test "el WhatsApp se guarda con su guion, se escriba como se escriba" do
    [ "04141234567", "0414 123 45 67", "+58 414 1234567", "584141234567" ].each do |escrito|
      fila = Setup.new(nombre: "whatsapp", valor: escrito)

      assert fila.valid?, escrito
      assert_equal "0414-1234567", fila.valor, escrito
    end
  end

  test "un fijo no sirve de WhatsApp" do
    fila = Setup.new(nombre: "whatsapp", valor: "0212-5551234")

    assert fila.invalid?
    assert_match(/tiene que ser un celular/, fila.errors.full_messages.to_sentence)
  end

  # ⚠️ «58» + «0414…» es un número que no existe, y WhatsApp abre igual con un
  # chat hacia nadie: al número se le quita el cero antes del país.
  test "el enlace de WhatsApp lleva el país y no lleva el cero" do
    poner_el_whatsapp("0414-1234567")

    assert_equal "https://wa.me/584141234567?text=Hola", Setup.whatsapp_url("Hola")
  end

  # ── De dónde sale el WhatsApp mientras nadie lo guardó ────────────────────

  # ⚠️ La variable `SIGA_WHATSAPP` sirve de valor INICIAL: si está puesta en
  # producción, el botón no desaparece el día en que el número pasa a la base.
  test "sin fila, el WhatsApp es el de la variable de entorno" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_equal "0424-1234567", Setup.whatsapp
      assert_not Setup.exists?, "leer un ajuste no puede escribir en la base"
    end
  end

  test "y con fila manda la base" do
    poner_el_whatsapp("0416-1112233")

    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_equal "0416-1112233", Setup.whatsapp
    end
  end

  # Quien apagó el WhatsApp a propósito no lo ve volver por la variable.
  test "tampoco vuelve la variable si el número se dejó en blanco a propósito" do
    poner_el_whatsapp(nil)

    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      assert_nil Setup.whatsapp
      assert_not Setup.whatsapp?
    end
  end

  test "una variable que no es un celular venezolano no se usa" do
    con_la_variable("SIGA_WHATSAPP", "12125551234") do
      assert_nil Setup.whatsapp
    end
  end

  # ── La dirección de la muestra ────────────────────────────────────────────

  test "la dirección de la muestra se guarda sin espacios ni la barra del final" do
    fila = Setup.new(nombre: "url_de_la_muestra", valor: "  https://demo.sigaeducando.com/ ")

    assert fila.valid?
    assert_equal "https://demo.sigaeducando.com", fila.valor
  end

  # ⚠️ Un enlace sin esquema es RELATIVO: «demo.sigaeducando.com» a secas
  # llevaría a sigaeducando.com/demo.sigaeducando.com. Y la dirección termina
  # en un enlace de la portada pública: un `javascript:` no puede entrar.
  test "solo se acepta una dirección que un navegador abre" do
    [ "demo.sigaeducando.com", "javascript:alert(1)", "ftp://demo.sigaeducando.com", "https://" ].each do |escrita|
      assert Setup.new(nombre: "url_de_la_muestra", valor: escrita).invalid?, escrita
    end
  end

  # Era la variable `SIGA_MUESTRA_URL`; ahora es esta fila.
  test "la muestra vive donde dice la fila" do
    Setup.create!(nombre: "url_de_la_muestra", valor: "https://demo.sigaeducando.com")

    assert_equal "https://demo.sigaeducando.com", Muestra.direccion
  end

  test "vacía vale, y quiere decir que no hay muestra que ofrecer" do
    Setup.create!(nombre: "url_de_la_muestra", valor: "")

    assert_nil Muestra.direccion
  end

  # ── Guardar desde el formulario ───────────────────────────────────────────

  test "preparar lo que se va a guardar no guarda nada" do
    filas = Setup.para_guardar({ "whatsapp" => "04141234567" }, por: nil)

    assert_equal %w[whatsapp], filas.map(&:nombre)
    assert_equal 0, Setup.count
  end

  # ⚠️ Una fila de WhatsApp vacía no es lo mismo que ninguna: apaga la
  # variable. Un formulario que no trae el campo no puede crearla.
  test "solo se preparan los campos que el formulario trae" do
    filas = Setup.para_guardar({ "url_de_la_muestra" => "https://demo.sigaeducando.com" }, por: nil)

    assert_equal %w[url_de_la_muestra], filas.map(&:nombre)
  end

  # Escrito de otra manera, el mismo número no es un cambio, y no tiene autor.
  test "quien lo cambió es quien cambió el valor, no quien guardó el formulario" do
    ana   = equipo_de_siga(:fundador)
    pedro = equipo_de_siga(:fundador)

    Setup.para_guardar({ "whatsapp" => "0414-1234567" }, por: ana).each(&:save!)
    Setup.para_guardar({ "whatsapp" => "0414 123 4567" }, por: pedro).each(&:save!)

    assert_equal ana, Setup.fila("whatsapp").actualizado_por
  end

  test "el formulario trae una fila por campo, y sin fila de WhatsApp muestra el de la variable" do
    con_la_variable("SIGA_WHATSAPP", "584241234567") do
      filas = Setup.para_el_formulario.index_by(&:nombre)

      assert_equal Setup::CAMPOS.keys.sort, filas.keys.sort
      assert_equal "0424-1234567", filas["whatsapp"].valor
      assert_not Setup.exists?, "mostrar el formulario no puede escribir en la base"
    end
  end
end
