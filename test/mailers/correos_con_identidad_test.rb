require "test_helper"

# Los correos de SIGA, con identidad (`docs/specs/correos-con-identidad.md`).
#
# Daniel, 5 de octubre de 2026, con el de «recuperar contraseña» abierto en
# Gmail: *«Esto no parece para nada un correo institucional de SIGA. Parece
# cualquier cosa.»* Siete de los ocho salían sin cabecera ni pie.
#
#     DEL COLEGIO   activar el acceso · boletín disponible · mensaje del colegio
#                   y los de la contraseña, si la persona es de UN solo colegio
#     DE SIGA       bienvenida · el aviso de colegio nuevo
#                   y los de la contraseña, si es de dos colegios o de ninguno
class CorreosConIdentidadTest < ActionMailer::TestCase
  include CorreosDeMuestra

  setup { preparar_los_correos }

  # ── De quién es cada correo ───────────────────────────────────────────────

  test "los tres correos del colegio llevan su nombre, sus datos y el logo de SIGA" do
    del_colegio.each do |cual, correo|
      html = html_de(correo)

      assert_includes html, @colegio.name, "#{cual}: la cabecera no nombra al colegio"
      assert_includes html, "DEA #{@colegio.dea_code}", "#{cual}: faltan los datos del colegio, como en un boletín"
      assert_includes html, "/correo/siga.png", "#{cual}: falta el logo de SIGA al otro extremo"
      assert_includes html, "Av. Principal, Edif. Uno", "#{cual}: el pie no dice cómo ubicar al colegio"
      assert_includes html, "0212-5551234"
      assert_match(/Enviado con\s*<strong[^>]*>\s*SIGA/m, html, "#{cual}: el pie no dice por dónde vino")
      assert_no_match(/Sistema Integrado de Gestión Académica/i, html,
                      "#{cual}: salió con la cabecera de SIGA, y lo escribe el colegio")
    end
  end

  # Es lo primero que se lee en la bandeja. Antes decía la dirección pelada.
  test "el remitente lleva el nombre del colegio, y la dirección de siempre" do
    del_colegio.each do |cual, correo|
      assert_equal "#{@colegio.name} · SIGA", correo[:from].display_names.first, "#{cual}: el remitente no dice de quién es"
      assert_equal [ ApplicationMailer.direccion ], correo.from, "#{cual}: la dirección no puede cambiar"
    end
  end

  test "la bienvenida es de SIGA" do
    correo = BienvenidaMailer.cuenta_creada(User.new(first_name: "YOLEIMA", email: "yoleima@sucolegio.edu"))

    assert_equal "SIGA", correo[:from].display_names.first
    assert_match(/Sistema Integrado de Gestión Académica/, html_de(correo))
    assert_no_match(/Enviado con/, html_de(correo))
  end

  # ⚠️ Un correo SOBRE un colegio no es un correo DEL colegio. El aviso tiene
  # `@colegio` y le llega al equipo de SIGA: si de quién es se dedujera de esa
  # variable, saldría con el escudo de un cliente.
  test "el aviso de colegio nuevo es de SIGA, aunque hable de un colegio" do
    correo = aviso_de_colegio_nuevo
    html   = html_de(correo)

    assert_equal "SIGA", correo[:from].display_names.first
    assert_match(/Sistema Integrado de Gestión Académica/, html)
    assert_includes html, @colegio.name, "el colegio va en el mensaje: es de lo que se avisa"
    assert_no_match(/Escudo de/, html)
    assert_no_match(/Enviado con/, html)
  end

  # ── Los de la contraseña: del colegio, si es uno solo ─────────────────────
  #
  # Decisión de Daniel. Quien pide recuperar su contraseña no tiene sesión, así
  # que el colegio sale de `User#unico_colegio` y no de `Current.school`.

  test "el de recuperar la contraseña sale del colegio de quien es de uno solo" do
    correo = recuperacion_de(@a.director)

    assert_equal "#{@colegio.name} · SIGA", correo[:from].display_names.first
    assert_includes html_de(correo), "DEA #{@colegio.dea_code}"
    assert_includes texto_de(correo), @colegio.name
  end

  test "y de SIGA para quien es de dos colegios" do
    Current.en_el_colegio(@b.colegio) { Teacher.create!(user: @a.director, school: @b.colegio) }
    correo = recuperacion_de(@a.director)

    assert_equal "SIGA", correo[:from].display_names.first
    assert_no_match(/#{Regexp.escape(@colegio.name)}|#{Regexp.escape(@b.colegio.name)}/, html_de(correo),
                    "con dos colegios no hay cómo saber cuál poner: no va ninguno")
  end

  test "y de SIGA para quien no es de ninguno" do
    suelto = User.create!(first_name: "Sol", last_name: "Nadie", document: "14000333",
                          document_type: :cedula_v, email: "sol@nadie.test", password: "123123")

    assert_equal "SIGA", recuperacion_de(suelto)[:from].display_names.first
  end

  test "el de «contraseña cambiada» sigue la misma regla, y está en español" do
    correo = Devise.mailer.password_change(@a.director)

    assert_equal "#{@colegio.name} · SIGA", correo[:from].display_names.first
    assert_equal "Su contraseña de SIGA cambió", correo.subject
    assert_includes html_de(correo), "se cambió hace un momento"
  end

  # ── El escudo ─────────────────────────────────────────────────────────────

  test "sin escudo cargado no hay imagen del colegio: sale su nombre" do
    del_colegio.each do |cual, correo|
      imagenes = html_de(correo).scan(/<img[^>]*>/)

      assert_equal 1, imagenes.size, "#{cual}: solo va el logo de SIGA"
      assert_includes imagenes.first, "/correo/siga.png"
      assert_includes html_de(correo), @colegio.name
    end
  end

  test "con escudo cargado lleva su imagen, con sus medidas y su texto alternativo" do
    ponerle_escudo_al_colegio

    del_colegio.each do |cual, correo|
      escudo = html_de(correo).scan(/<img[^>]*>/).find { |img| img.include?("Escudo de") }

      assert escudo, "#{cual}: el escudo no salió"
      assert_includes escudo, %(alt="Escudo de #{@colegio.name}")
      assert_match %r{src="http://[^"]+/rails/active_storage/representations/proxy/}, escudo
      # El de prueba mide 367 × 400: más alto que ancho, como casi todos.
      assert_match(/width="44"/, escudo, "#{cual}: el escudo va deformado, o sin medidas")
      assert_match(/height="48"/, escudo)
    end
  end

  # ⚠️ Solo se ARMA la dirección de la miniatura. Pedirle `.processed` acá es el
  # `IOError: closed stream` de «Descargar las listas»: una variante nueva se
  # guarda al confirmar la transacción, y en SIGA la transacción es la petición
  # entera. La miniatura la procesa Active Storage cuando alguien la pide.
  test "armar un correo con escudo no procesa ninguna variante" do
    ponerle_escudo_al_colegio

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      del_colegio.each_value { |correo| html_de(correo) }
    end
  end

  # ⚠️ Un correo vive años en una bandeja. Una imagen con la huella de un
  # despliegue en el nombre desaparece con el siguiente.
  test "el logo de SIGA tiene una dirección permanente, y el archivo existe" do
    html = html_de(BienvenidaMailer.cuenta_creada(User.new(first_name: "YOLEIMA", email: "y@sucolegio.edu")))

    assert_match %r{src="http://[^"/]+/correo/siga\.png"}, html, "la dirección lleva huella, o pasó por los assets"
    assert Rails.public_path.join("correo/siga.png").exist?, "el archivo no está en public/correo"
  end

  # ── Lo que tienen todos ───────────────────────────────────────────────────

  test "los ocho correos traen HTML y texto" do
    todos.each do |cual, correo|
      assert_equal %w[text/plain text/html], correo.parts.map { |parte| parte.content_type.split(";").first },
                   "#{cual}: le falta una de las dos versiones"
      assert_operator texto_de(correo).length, :>, 80, "#{cual}: la versión en texto está vacía"
    end
  end

  test "ninguno dice nada en inglés" do
    ingles = /\b(Hello|Hi |We are|has been|password|Unsubscribe|Welcome|notifications)\b/i

    todos.each do |cual, correo|
      visible = ActionController::Base.helpers.strip_tags(html_de(correo).sub(%r{<style.*?</style>}m, ""))

      assert_no_match ingles, visible, "#{cual}: quedó texto en inglés en el HTML"
      assert_no_match ingles, texto_de(correo), "#{cual}: quedó texto en inglés en la versión de texto"
    end
  end

  # El renglón que el cliente muestra al lado del asunto. Sin él, ahí aparece
  # «Hola:» — o sea nada.
  test "todos traen su adelanto para la bandeja" do
    todos.each do |cual, correo|
      # Haml escribe sus atributos con comilla simple; los helpers de Rails, doble.
      adelanto = html_de(correo)[%r{<div style=['"]display:none[^>]*>(.*?)</div>}m, 1].to_s.strip

      assert_operator adelanto.length, :>, 20, "#{cual}: no tiene adelanto"
    end
  end

  test "todos dicen a quién se le envió" do
    todos.each do |cual, correo|
      assert_includes html_de(correo), "Este mensaje se envió a", "#{cual}: el pie no dice a quién"
      assert_includes html_de(correo), correo.to.first
    end
  end

  # ── El enlace de avisos ───────────────────────────────────────────────────
  #
  # ElasticEmail le agrega a todo correo su «MANAGE NOTIFICATIONS». No se apaga
  # por código; si el cuerpo ya trae `{unsubscribe}`, usa ese.

  test "por ElasticEmail, el pie trae el enlace de avisos en español" do
    con_el_servidor("smtp.elasticemail.com") do
      todos.each do |cual, correo|
        assert_match %r{<a [^>]*href="\{unsubscribe\}"[^>]*>Administrar avisos</a>}, html_de(correo),
                     "#{cual}: sin el enlace propio, ElasticEmail pone el suyo en inglés"
        assert_includes texto_de(correo), "Administrar avisos: {unsubscribe}"
      end
    end
  end

  # ⚠️ Con otro proveedor nadie reemplaza la etiqueta: el enlace llevaría a
  # «{unsubscribe}», tal cual.
  test "por otro servidor, no" do
    con_el_servidor("smtp.otro-proveedor.com") do
      todos.each do |cual, correo|
        assert_no_match(/unsubscribe/, html_de(correo), "#{cual}: salió la etiqueta sin quien la reemplace")
        assert_no_match(/unsubscribe/, texto_de(correo))
      end
    end
  end

  # ── Lo que no puede cambiar ───────────────────────────────────────────────

  test "ninguno se rastrea, todos son transaccionales y todos llevan su canal" do
    todos.each do |cual, correo|
      assert_equal "false", correo["trackclicks"].to_s, "#{cual}: se rastrean los clics"
      assert_equal "false", correo["trackopens"].to_s
      assert_equal "True", correo["IsTransactional"].to_s
      assert_match(/\Asiga-[a-z0-9-]+\z/, correo["X-ElasticEmail-Channel"].to_s, "#{cual}: sin canal")
    end
  end

  private

  def del_colegio = correos_del_colegio
  def todos       = todos_los_correos

  def con_el_servidor(servidor, &) = con_la_variable("SMTP_ADDRESS", servidor, &)
end
