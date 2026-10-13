require "test_helper"

# Subir un precio es cambiar UN número (`Subscription::PRECIO_POR_ALUMNO` y
# `Subscription::MINIMO_MENSUAL`).
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
# Por eso acá el precio se cambia por uno que no existe y se exige que cada
# pantalla diga ESE, y ninguno de los de verdad.
class LosPreciosDeUnSoloLugarTest < ActionDispatch::IntegrationTest
  include CobroDeLaSuscripcion

  POR_ALUMNO_DE_MENTIRA = BigDecimal("0.47")
  MINIMO_DE_MENTIRA     = BigDecimal("53")

  # Un monto con su signo, sin importar de qué lado lo lleve: «$39», «39 $».
  MONTO_A_MANO = /\$\s?\d{2,}|\d{2,}\s?\$/

  test "la portada dice el precio de la constante, y no otro" do
    con_precios_de_mentira do
      get root_path

      assert_equal "0,47", css_select("span.portada-plan-monto").first.text.strip
      assert_match(/53,00 \$/, css_select("p.portada-plan-cupo").first.text)
      assert_ningun_precio_de_verdad
    end
  end

  test "la descripción y la ficha para buscadores, también" do
    con_precios_de_mentira do
      get root_path

      assert_includes css_select("meta[name=description]").first["content"], "0,47 $ por alumno"

      oferta = JSON.parse(css_select("script[type='application/ld+json']").first.text)["offers"].first
      assert_equal "0.47", oferta["price"]
      assert_equal "0.47", oferta.dig("priceSpecification", "price")
      assert_includes oferta["description"], "53.00"
    end
  end

  # El colegio de prueba tiene dos alumnos: le toca el mínimo, 53 $ más IVA.
  test "el panel de SIGA, en la tabla y en la nota" do
    dos_colegios_completos
    sign_in equipo_de_siga

    con_precios_de_mentira do
      get siga_root_path

      assert_response :success
      assert_select "table.siga-tabla td", text: "61,48 $", minimum: 1
      assert_select "p.siga-nota", text: /0,47 \$ por alumno al mes, más IVA, con un mínimo de 53,00 \$/
      assert_ningun_precio_de_verdad
    end
  end

  # El muro de lo gratis dice el precio de ESE colegio: el de la constante,
  # porque todavía no entró y no tiene uno congelado.
  test "el muro de lo gratis, también" do
    a, _b = dos_colegios_completos(suscripcion: :gratis)
    sign_in a.director

    con_precios_de_mentira do
      post constancias_path, params: { section_id: a.seccion.id, enrollment_id: a.inscripcion.id }

      assert_includes flash[:alert], "61,48 $ al mes"
      assert_includes flash[:alert], "53,00 $"
    end
  end

  # Lo que el colegio lee cuando va a pagar: «Suscripción» y el formulario del
  # reporte. Son las dos pantallas donde un precio viejo cuesta dinero de
  # verdad — el colegio transfiere lo que ahí dice.
  test "«Suscripción» y el reporte del pago, también" do
    a, _b = dos_colegios_completos(suscripcion: :gratis)
    cargar_los_ajustes_de_siga
    sign_in a.director

    con_precios_de_mentira do
      get suscripcion_path

      assert_select ".suscripcion-cuenta td", text: "53,00 $"
      assert_select ".suscripcion-cuenta-total td", text: "61,48 $"
      assert_select "p.nota-ayuda", text: /0,47 \$ por alumno al mes, con un mínimo de 53,00 \$/
      assert_ningun_precio_de_verdad

      get new_suscripcion_pago_path

      assert_select ".reporte-de-pago-cuenta", text: /61,48 \$ al mes/
      assert_ningun_precio_de_verdad
    end
  end

  # La Cartera dice lo que le toca a cada colegio: es el número que se le dice
  # por teléfono, y con el que se compara lo que pagó.
  test "y la Cartera de SIGA" do
    dos_colegios_completos(suscripcion: :gratis)
    sign_in equipo_de_siga

    con_precios_de_mentira do
      get siga_cartera_index_path

      assert_response :success
      assert_select "table.siga-tabla td.num", text: "61,48 $", minimum: 1
      assert_ningun_precio_de_verdad
    end
  end

  # ⚠️ Lo que los de arriba no pueden ver: una pantalla que no visitan. Un monto
  # que es un DATO va interpolado; uno con sus dígitos en la plantilla es una
  # copia, y las copias son las que se quedan atrás.
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
                 "Si es el precio, sale de `Subscription::PRECIO_POR_ALUMNO`:\n  #{a_mano.join("\n  ")}"
  end

  # ⚠️ Desde el 12 de octubre de 2026 no hay planes con nombre (decisión 15 del
  # spec `del-registro-al-cobro`): «Plan Inicial» era a la vez el gratis y el de
  # 39 $. Un texto que lo nombre le promete al colegio un plan que no existe.
  #
  # ⚠️ Se busca «plan Inicial» y no «Inicial» a secas: Inicial es también un
  # NIVEL —Educación Inicial— y prohibir la palabra se llevaría el preescolar.
  test "ninguna pantalla ni correo nombra los planes viejos" do
    planes_viejos = /\bplan(es)?\s+(inicial|estándar|grande|básico|premium)\b/i

    con_nombre = (Rails.root.glob("app/views/**/*.{haml,erb}") + [ Rails.root.join("config/locales/es.yml") ])
                 .flat_map do |archivo|
      archivo.each_line.with_index(1).filter_map do |linea, numero|
        next if linea.lstrip.start_with?("-#", "<%#", "#")

        "#{archivo.relative_path_from(Rails.root)}:#{numero}  #{linea.strip}" if linea.match?(planes_viejos)
      end
    end

    assert_empty con_nombre, "Ese plan ya no existe:\n  #{con_nombre.join("\n  ")}"
  end

  private

  def con_precios_de_mentira(&)
    @de_verdad = [ ApplicationController.helpers.cifra(Subscription::PRECIO_POR_ALUMNO),
                   ApplicationController.helpers.cifra(Subscription::MINIMO_MENSUAL) ]

    stub_const(Subscription, :PRECIO_POR_ALUMNO, POR_ALUMNO_DE_MENTIRA) do
      stub_const(Subscription, :MINIMO_MENSUAL, MINIMO_DE_MENTIRA, &)
    end
  end

  # En lo que se LEE: sin etiquetas, y sin los bloques que no son texto.
  def assert_ningun_precio_de_verdad
    pagina = Nokogiri::HTML(response.body)
    pagina.css("script, style").each(&:remove)
    texto = pagina.text.squish

    @de_verdad.each do |precio|
      assert_no_match(/\$\s?#{Regexp.escape(precio)}\b|\b#{Regexp.escape(precio)}\s?\$/, texto,
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
