require "test_helper"

# Subir un precio es cambiar UN número (`Subscription::PLANES`).
#
# ## Por qué hace falta un test para esto
#
# Porque ya falló tres veces, y las tres en silencio:
#
#     la descripción para buscadores   «Desde 25 $ al mes», meses después de subir a 30
#     el panel de SIGA, su tabla       una segunda tabla de planes, con 25 · 50 · 90
#     el panel de SIGA, su nota        «$25 · $50 · $90» el día que subieron a 39 · 79 · 119
#
# Un precio escrito a mano no rompe nada: la pantalla abre, el número se lee
# bien, y es el viejo.
#
# ⚠️ `portada_publica_test` y `seo_test` ya comparan contra la constante, y no
# alcanza: un número escrito a mano que HOY coincide los pasa en verde, y se
# queda atrás en la próxima subida — que es justo cuando nadie lo mira.
#
# Por eso acá los precios se cambian por tres que no existen y se exige que
# cada pantalla diga ESOS, y ninguno de los de verdad.
class LosPreciosDeUnSoloLugarTest < ActionDispatch::IntegrationTest
  DE_MENTIRA = { basico: 41, estandar: 83, premium: 127 }.freeze

  # Un monto con su signo, sin importar de qué lado lo lleve: «$39», «39 $».
  MONTO_A_MANO = /\$\s?\d{2,}|\d{2,}\s?\$/

  test "la portada dice los precios de la tabla, y no otros" do
    con_precios_de_mentira do
      get root_path

      assert_equal %w[41 83 127], css_select("span.portada-plan-monto").first(3).map { |monto| monto.text.strip }
      assert_ningun_precio_de_verdad
    end
  end

  test "la descripción y la ficha para buscadores, también" do
    con_precios_de_mentira do
      get root_path

      assert_includes css_select("meta[name=description]").first["content"], "Desde 41 $ al mes"

      ofertas = JSON.parse(css_select("script[type='application/ld+json']").first.text)["offers"]
      assert_equal %w[41 83 127], ofertas.map { |oferta| oferta["price"] }
      assert_equal %w[41 83 127], ofertas.map { |oferta| oferta.dig("priceSpecification", "price") }
    end
  end

  test "el panel de SIGA, en la tabla y en la nota" do
    dos_colegios_completos
    sign_in equipo_de_siga

    con_precios_de_mentira do
      get siga_root_path

      assert_response :success
      assert_select "table.siga-tabla td", text: %r{\$41/mes}, minimum: 1
      assert_select "p.siga-nota",
                    text: /hasta 150 alumnos \$41 · hasta 400 alumnos \$83 · hasta 800 alumnos \$127\./
      assert_ningun_precio_de_verdad
    end
  end

  # ⚠️ Lo que los tres de arriba no pueden ver: una pantalla que no visitan.
  # Un monto que es un DATO va interpolado; uno con sus dígitos en la plantilla
  # es una copia, y las copias son las que se quedan atrás.
  #
  # Los comentarios se saltan: «acá decía $25» es historia, no pantalla.
  test "ninguna pantalla escribe un monto en dólares a mano" do
    a_mano = Rails.root.glob("app/views/**/*.{haml,erb}").flat_map do |plantilla|
      plantilla.each_line.with_index(1).filter_map do |linea, numero|
        next if linea.lstrip.start_with?("-#")

        sin_datos = linea.gsub(/#\{[^}]*\}/, "").gsub(/<%.*?%>/, "")

        "#{plantilla.relative_path_from(Rails.root)}:#{numero}  #{linea.strip}" if sin_datos.match?(MONTO_A_MANO)
      end
    end

    assert_empty a_mano,
                 "Un monto escrito a mano se queda atrás en la próxima subida de precio. " \
                 "Si es de los planes, sale de `Subscription::PLANES`:\n  #{a_mano.join("\n  ")}"
  end

  private

  def con_precios_de_mentira(&)
    @de_verdad = Subscription::PLANES.values.map { |plan| plan[:precio] }
    de_mentira = Subscription::PLANES.to_h { |nombre, plan| [ nombre, plan.merge(precio: DE_MENTIRA.fetch(nombre)) ] }

    stub_const(Subscription, :PLANES, de_mentira.freeze, &)
  end

  # En lo que se LEE: sin etiquetas, y sin los bloques que no son texto.
  def assert_ningun_precio_de_verdad
    pagina = Nokogiri::HTML(response.body)
    pagina.css("script, style").each(&:remove)
    texto = pagina.text.squish

    @de_verdad.each do |precio|
      assert_no_match(/\$\s?#{precio}\b|\b#{precio}\s?\$/, texto,
                      "la pantalla sigue diciendo #{precio} $: lo tiene escrito a mano")
    end
  end

  def equipo_de_siga
    Current.sin_aislamiento do
      User.create!(first_name: "Equipo", last_name: "Siga", email: "fundador@siga.test", password: "123123",
                   document: "V-10101010", document_type: :cedula_v).tap do |persona|
        SigaStaff.create!(user: persona, role: :fundador)
      end
    end
  end
end
