require "test_helper"

# La nomenclatura del MPPE (MOR-212).
#
# Daniel, de la jornada del 3 de septiembre: *«corrección de nomenclatura:
# Preescolar = Educación Inicial; Primaria = Educación Primaria; Bachillerato =
# Educación Media General; Técnico Medio = Educación Técnica Media»*.
#
# No es purismo: un director llena planillas del ministerio con estas palabras,
# y un sistema que le dice «Bachillerato» donde el MPPE dice «Educación Media»
# lo obliga a traducir en cada pantalla.
class NomenclaturaDelMppeTest < ActiveSupport::TestCase
  test "cada nivel se llama como lo llama el MPPE" do
    assert_equal "Educación Inicial", GradoOficial.etiqueta(:preescolar)
    assert_equal "Educación Primaria", GradoOficial.etiqueta(:primaria)
    assert_equal "Educación Media", GradoOficial.etiqueta(:secundaria)
    assert_equal "Educación Técnica Media", GradoOficial.etiqueta(:media_tecnica)
  end

  # ⚠️ La forma corta va donde el nombre largo no cabe: la barra, el menú, los
  # chips. Es una sola palabra y sigue siendo inequívoca.
  test "la forma corta es una palabra y no se confunde con nada" do
    cortas = GradoOficial::ETIQUETAS_CORTAS.values
    assert_equal cortas.uniq, cortas, "dos niveles no pueden abreviarse igual"
    assert_equal %w[Inicial Primaria Media], cortas.first(3)
  end

  # ⚠️ El ENUM no cambia, y esa es la decisión que hace barato el renombre.
  #
  # `grades.level` sigue diciendo `secundaria` y `preescolar`: son enteros
  # escritos en la base de todos los colegios, y renombrarlos sería una
  # migración de datos para arreglar un problema de TEXTO.
  test "el enum de la base sigue igual" do
    assert_includes Grade.levels.keys, "secundaria"
    assert_includes Grade.levels.keys, "preescolar"
  end

  # ⚠️ Nadie escribe «Bachillerato» a mano en una vista: se pide a
  # `GradoOficial.etiqueta`. Con el texto escrito, el día que el MPPE cambie una
  # palabra hay que salir a buscarla por todo el proyecto — que es justamente
  # de donde venimos.
  test "ninguna vista escribe el nombre de un nivel a mano" do
    # ⚠️ Los COMENTARIOS de Haml no cuentan, y hay que saltarlos línea por
    # línea: no se ven en pantalla, y varios explican justamente por qué el
    # nombre viejo estaba mal. Un `(?<![-#])` sobre el archivo entero no
    # alcanza — el `-#` está al principio del renglón, no pegado a la palabra.
    culpables = Dir[Rails.root.join("app/views/**/*.haml")].select do |archivo|
      File.readlines(archivo)
          .reject { |linea| linea.lstrip.start_with?("-#", "/") }
          .any? { |linea| linea.match?(/\b(Bachillerato|Preescolar)\b/) }
    end.map { |a| a.delete_prefix("#{Rails.root}/") }

    assert_empty culpables,
                 "estas vistas escriben el nombre viejo de un nivel en vez de pedirlo " \
                 "a `GradoOficial.etiqueta`: #{culpables.join(', ')}"
  end

  # ── «Materias» → «Áreas de aprendizaje» ───────────────────────────────────

  test "el área de aprendizaje se llama como la llama el MPPE" do
    assert_equal "Áreas de aprendizaje", Vocabulario::AREAS
    assert_equal "Área", Vocabulario::AREA_CORTA
  end

  # ⚠️ El plural va ESCRITO. `"área".pluralize` devuelve «área» —el inflector de
  # Rails es inglés— y el proyecto ya tiene `ApplicationHelper#contar` por eso.
  test "el plural de área no se deduce" do
    assert_equal "1 área de aprendizaje", Vocabulario.areas(1)
    assert_equal "3 áreas de aprendizaje", Vocabulario.areas(3)
    assert_equal "3 áreas", Vocabulario.areas(3, corto: true)
  end

  # ⚠️ Nadie escribe «materia» donde alguien lee.
  #
  # Daniel lo fijó el 3 de septiembre y el 5 de octubre encontró «MATERIA» en
  # la cabecera del boletín impreso: *«recuerda que son "Área de Aprendizaje"
  # en lugar de "Materia"»*. Las pantallas principales se habían corregido; el
  # resto del producto, no — más de cien frases en vistas, mensajes de controladores,
  # el arranque, el importador y el nombre del modelo en `es.yml`. Un renombre
  # que se hace una vez y no se cuida, se deshace solo con la próxima pantalla.
  #
  # Mira el TEXTO, no los identificadores: `@materias`, `fila["materia"]`,
  # `.ficha-materia` y `/materias` siguen siendo lo que eran — nadie los lee.
  test "ninguna pantalla ni mensaje dice «materia»" do
    hallados = frases_que_dicen_materia

    culpables = hallados.reject { |archivo, frase| se_queda?(archivo, frase) }
    assert_empty culpables.map { |archivo, frase| "#{archivo}: «#{frase}»" },
                 "estas frases dicen «materia» donde `Vocabulario` dice «área de aprendizaje»"

    # Y una excepción que ya no hace falta se borra: una lista de permisos que
    # nadie revisa termina tapando lo que vino a vigilar.
    de_mas = SE_QUEDA_POR_FRASE.flat_map { |archivo, frases| frases.map { |frase| [ archivo, frase ] } }
                               .reject { |par| hallados.include?(par) }
    assert_empty de_mas, "estas excepciones ya no existen en el código: bórrelas de la lista"
  end

  # ⚠️ La URL se queda en `/materias`, y no es un olvido: `/areas-de-aprendizaje`
  # son veintiún caracteres para lo mismo, y `MOR-162` dice que la URL se lee
  # bien, no que repita el término oficial.
  test "la URL sigue siendo corta" do
    assert_equal "/materias", Rails.application.routes.url_helpers.subjects_path
  end

  # ⚠️ Y el MODELO tampoco: `Subject` es de donde Rails deduce la tabla y las
  # asociaciones. Renombrarlo sería una migración para arreglar un problema de
  # texto.
  test "el modelo sigue siendo Subject" do
    assert_equal "subjects", Subject.table_name
  end

  private

  PALABRA = /\bmaterias?\b/i

  # ⚠️ Las plantillas de Excel NO cambian (decisión de Daniel, 5 de octubre):
  # «MATERIA» y «CÓDIGO DE LA MATERIA» son las columnas que el colegio escribe
  # en SU planilla, y sus notas de ayuda viajan dentro del archivo.
  SE_QUEDA_POR_ARCHIVO = %w[
    app/services/columnas_de_pensum.rb
    app/services/columnas_de_historial.rb
    app/services/plantilla_de_pensum.rb
    app/services/plantilla_de_historial.rb
  ].freeze

  # Y estas frases, una por una, con su porqué.
  SE_QUEDA_POR_FRASE = {
    # Citan la columna de la planilla: con «Sin área», el colegio buscaría en
    # su Excel una columna que no existe.
    "app/views/importaciones/_revisar_pensum.html.haml" => [ "CÓDIGO DE LA MATERIA" ],
    "app/services/pensum_interpretado.rb"               => [ "Sin materia" ],
    "app/services/historial_interpretado.rb"            => [ "Sin materia" ],
    # La frase hecha del sitio público: «otra materia» es «otra cosa que
    # estudiar», no un área del pensum.
    "app/views/inicio/index.html.haml"                  => [ "sentirse como otra materia." ]
  }.freeze

  def se_queda?(archivo, frase)
    SE_QUEDA_POR_ARCHIVO.include?(archivo) || SE_QUEDA_POR_FRASE.fetch(archivo, []).include?(frase)
  end

  # Cada `[archivo, frase]` que dice la palabra en algo que alguien lee.
  def frases_que_dicen_materia
    raiz = "#{Rails.root}/"

    vistas = Dir[Rails.root.join("app/views/**/*.haml")].flat_map { |a| en_haml(a) }
    codigo = Dir[Rails.root.join("app/{controllers,helpers,mailers,models,services,jobs}/**/*.rb")].flat_map { |a| en_ruby(a) }

    (vistas + codigo + en_yaml(Rails.root.join("config/locales/es.yml").to_s))
      .map { |archivo, frase| [ archivo.delete_prefix(raiz), frase ] }
  end

  def en_haml(archivo)
    File.readlines(archivo).flat_map do |linea|
      limpia = linea.strip
      next [] if limpia.start_with?("-#", "/")

      frases = literales_de(linea)
      # El texto suelto: lo que queda sin la etiqueta, cuando la línea no es Ruby.
      etiqueta = /\A[%.#][\w.#-]*(\{[^}]*\}|\([^)]*\))?/
      es_ruby  = limpia.start_with?("-", "=", "!=", "&=") || limpia.match?(/#{etiqueta.source}[=~]/)
      suelto   = limpia.sub(etiqueta, "").strip
      frases << suelto if frases.empty? && !es_ruby && sin_interpolar(suelto).match?(PALABRA)

      frases.map { |frase| [ archivo, frase ] }
    end
  end

  def en_ruby(archivo)
    File.readlines(archivo).flat_map do |linea|
      next [] if linea.strip.start_with?("#")

      literales_de(linea.sub(/\s+#\s.*\z/, "")).map { |frase| [ archivo, frase ] }
    end
  end

  def en_yaml(archivo)
    File.readlines(archivo).filter_map do |linea|
      next if linea.strip.start_with?("#")

      valor = linea.split(":", 2).last.to_s.strip
      [ archivo, valor ] if valor.match?(PALABRA)
    end
  end

  # Los textos entre comillas de una línea que dicen la palabra.
  #
  # ⚠️ Un literal que es SOLO la palabra y hace de clave —`fila["materia"]`,
  # `"materias" => …`, `dig("comparacion", "materias")`— es un dato, no un
  # texto. Pero `contar(n, "materia", "materias")` sí se lee: por eso la clave
  # se reconoce por lo que la rodea, no por su forma.
  def literales_de(linea)
    linea.to_enum(:scan, /"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'/).filter_map do
      hallado = Regexp.last_match
      frase   = sin_interpolar(hallado[1] || hallado[2])
      next unless frase.match?(PALABRA)
      next if frase.strip.match?(/\Amaterias?\z/i) && clave?(linea, hallado.begin(0), hallado.end(0))

      (hallado[1] || hallado[2]).strip
    end
  end

  def sin_interpolar(texto) = texto.gsub(/\#\{[^}]*\}/, " ")

  def clave?(linea, desde, hasta)
    antes   = linea[0...desde]
    despues = linea[hasta..].to_s

    (antes.end_with?("[") && despues.start_with?("]")) || despues.match?(/\A\s*=>/) ||
      antes.match?(/\b(dig|fetch|key\?|pluck|slice|except|delete|index_by|group_by|sort_by|map)\([^)]*\z/)
  end
end
