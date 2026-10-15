require "test_helper"

# El contrato, «Aliados» y «Qué hace hoy» dicen lo que SIGA es HOY.
#
# Hasta el 13 de octubre de 2026 vivían solo en la carpeta madre, en Pages y en
# PDF, y ninguno pasaba por un test: el contrato pedía elegir un «Plan Básico,
# Estándar o Premium» con «cuota de activación», «Aliados» calculaba sobre las
# bandas de 30, 60 y 90 $ y «Qué hace hoy» daba por «en construcción» funciones
# terminadas. Daniel: *«debemos tener una única verdad de todo»*.
#
# ⚠️ Se prueba como la portada (`los_precios_de_un_solo_lugar_test`): con
# precios que no existen. Comparar contra la constante no alcanza, porque un
# número escrito a mano que hoy coincide pasa en verde.
class DocumentosComercialesTest < ActiveSupport::TestCase
  POR_ALUMNO_DE_MENTIRA = BigDecimal("0.47")
  MINIMO_DE_MENTIRA     = BigDecimal("53")

  DocumentosComerciales::DOCUMENTOS.each_key do |nombre|
    test "#{nombre}: dice el precio de la constante, y no otro" do
      texto = con_precios_de_mentira { texto_de(nombre) }

      assert_includes texto, "0,47", "#{nombre} no dice el precio por alumno de la constante"
      assert_includes texto, "53,00", "#{nombre} no dice el mínimo de la constante"
      assert_no_match(/0,35|39,00/, texto, "#{nombre} tiene un precio escrito a mano")
    end

    test "#{nombre}: le habla de usted al lector y dice «área de aprendizaje»" do
      lineas = texto_de(nombre).lines

      assert_empty lineas.grep(Tuteo::PATRON), "#{nombre} tutea"
      assert_empty lineas.grep(/\bmaterias?\b/i), "#{nombre} dice «materia»: el MPPE dice «área de aprendizaje»"
    end
  end

  # ⚠️ Los guiones de los videos NO dicen precios (14 de octubre de 2026). Un
  # video vive meses —los de septiembre siguieron circulando con las bandas de
  # 30, 60 y 90 $— y el precio es un número de `Subscription` que un video no
  # puede leer. Y caben en los 30 segundos que pidió Daniel: unas 75 palabras
  # leídas sin apuro.
  test "los guiones de los videos: sin precios, de usted, con «área» y en 30 segundos" do
    guiones = Rails.root.join("docs/comercial/videos.md").read.scan(/```guion\n(.*?)```/m).flatten

    assert_equal 2, guiones.size, "esperaba los guiones de los dos videos: Principal y Roles"
    guiones.each do |guion|
      assert_no_match(/\$|\d+,\d\d|dólar|bolívar|precio|cuesta/i, guion, "un guion dice un precio:\n#{guion}")
      assert_no_match(Tuteo::PATRON, guion, "un guion tutea:\n#{guion}")
      assert_no_match(/\bmaterias?\b/i, guion, "un guion dice «materia»:\n#{guion}")
      assert_operator guion.split.size, :<=, 75, "un guion no cabe en 30 segundos:\n#{guion}"
    end
  end

  # Las bandas viejas, en cualquiera de sus dos formas.
  #
  # ⚠️ Sin el 39: fue la banda «Inicial» hasta el 12 de octubre de 2026, y
  # desde el 14 es el mínimo de verdad, que los documentos tienen que decir.
  test "ningún documento habla de planes por tamaño" do
    DocumentosComerciales::DOCUMENTOS.each_key do |nombre|
      texto = texto_de(nombre)

      assert_no_match(/\bplan(es)? (Inicial|Estándar|Grande|Básico|Premium)\b|PLAN BÁSICO|plan seleccionado/i, texto, nombre)
      assert_no_match(/(\$\s?(30|60|90|79|119)\b)|(\b(30|60|90|79|119)(,00)?\s?\$)/, texto, nombre)
    end
  end

  # Decisiones de Daniel del 13 de octubre de 2026.
  test "el contrato es mes a mes, sin cuota de activación, con la escalera de la app" do
    texto = texto_de("contrato")

    assert_match(/mes a mes/, texto)
    assert_match(/Sin cuota de activación/, texto)
    assert_no_match(/un \(01\) año escolar|\[MONTO\]|periodos de prueba|\[DÍAS\]/, texto)
    assert_match(/#{Subscription::DIAS_DE_AVISO} días antes del vencimiento/, texto)
    assert_match(/#{Subscription.column_defaults['dias_de_gracia']}\s+días de gracia/, texto)
  end

  # El registro no tiene un campo para el código de un aliado, y el documento
  # lo prometía.
  test "«Aliados» no promete lo que el registro no tiene" do
    texto = texto_de("aliados")

    assert_no_match(/código de aliado|tu código|su código/i, texto)
    assert_match(/demo\.sigaeducando\.com/, texto)
  end

  private

  def texto_de(nombre)
    pagina = Nokogiri::HTML(DocumentosComerciales.html(nombre))
    pagina.css("style, script").each(&:remove)
    pagina.text.gsub(/[ \t]+/, " ")
  end

  def con_precios_de_mentira(&)
    stub_const(Subscription, :PRECIO_POR_ALUMNO, POR_ALUMNO_DE_MENTIRA) do
      stub_const(Subscription, :MINIMO_MENSUAL, MINIMO_DE_MENTIRA, &)
    end
  end
end
