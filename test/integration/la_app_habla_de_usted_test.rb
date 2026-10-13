require "test_helper"

# SIGA le habla de USTED a quien la usa: a la madre que mira las notas de su
# hijo, a la secretaria, al profesor, al director.
#
# Daniel, el 13 de octubre de 2026: *«revisa exhaustivamente todos los textos y
# cambia a usted todos los que puedan tutear al usuario. TODOS»*. Eran unos
# cien, repartidos en pantallas, mensajes, JavaScript y los de Devise: «Elige un
# alumno», «No tienes permiso», «Tienes que iniciar sesión», y el título de la
# portada, «El colegio que imaginas». Se escribían de a uno, cada quien como le
# salía, y ninguna regla los miraba.
#
# ⚠️ Mira solo lo que se LEE: el texto de las vistas, las cadenas con espacios
# de Ruby y JavaScript —un mensaje es una frase; `"te"` a secas es la clave de
# una columna— y los valores de las traducciones. Los comentarios no cuentan:
# varios citan a propósito cómo se decía antes.
#
# ⚠️ Busca formas que NO se confunden con la tercera persona. «Toca al hijo»
# puede ser «la madre toca» y «Entra con su correo», «el profesor entra»: esas
# no las puede juzgar una expresión regular, y por eso no están en la lista.
class LaAppHablaDeUstedTest < ActiveSupport::TestCase
  TUTEO = /
    \b(?:tú|tu|tus|te|ti|contigo|tuyo|tuya|tuyos|tuyas)\b
    | \b(?:tienes|puedes|quieres|debes|estás|eres|vas|haces|sabes|necesitas|hayas|podrás|tendrás|verás|
           recibirás|puedas|tengas|estés|seas|dictas|escribes|crees|imaginas|digas|elegiste|escribiste|
           olvidaste|marcaste|entraste|iniciaste|copiaste|dictaste|has\ (?:iniciado|sido|llegado|actualizado))\b
    | \b(?:pídele|escríbenos|comunícate|regístrate|asegúrate|fíjate|notificarte|avisarte|contactarte|
           ayudarte|verte|dime|dinos)\b
    | (?:^\s*|[.:¿¡"'>«]\s*|%[\w.\#-]+\s+)(?:Elige|Revisa|Agrega|Contacta|Recuerda|Escoge|Selecciona|Ingresa|Introduce|Verifica)\b
  /xi

  test "ninguna pantalla tutea" do
    assert_sin_tuteo(Dir[Rails.root.join("app/views/**/*.{haml,erb}")]) { |archivo| texto_de_la_vista(archivo) }
  end

  test "ningún mensaje de Ruby tutea" do
    rutas = Dir[Rails.root.join("app/{controllers,models,services,helpers,mailers,jobs}/**/*.rb")]
    assert_sin_tuteo(rutas) { |archivo| frases_entre_comillas(archivo, comentario: /\A\s*#/) }
  end

  test "ningún mensaje de JavaScript tutea" do
    assert_sin_tuteo(Dir[Rails.root.join("app/javascript/**/*.js")]) do |archivo|
      frases_entre_comillas(archivo, comentario: %r{\A\s*(//|/?\*)})
    end
  end

  # «Tienes que iniciar sesión o registrarte»: Devise llega traducido de
  # tú, y era lo PRIMERO que leía quien abría un enlace sin sesión.
  test "ninguna traducción tutea" do
    rutas = Dir[Rails.root.join("config/locales/*.es.yml")] + [ Rails.root.join("config/locales/es.yml").to_s ]
    assert_sin_tuteo(rutas) do |archivo|
      File.readlines(archivo).reject { |linea| linea.lstrip.start_with?("#") }
          .filter_map { |linea| linea.split(":", 2).last if linea.include?(":") }
    end
  end

  # El manual es lo que se le entrega a un colegio.
  test "el manual no tutea" do
    assert_sin_tuteo(Dir[Rails.root.join("docs/manual/m[0-9].html")]) do |archivo|
      File.read(archivo).gsub(/<style.*?<\/style>/m, "").gsub(/<!--.*?-->/m, "").gsub(/<[^>]+>/, " ").lines
    end
  end

  private

  def assert_sin_tuteo(archivos)
    culpables = archivos.flat_map do |archivo|
      yield(archivo).grep(TUTEO).map { |texto| "#{archivo.to_s.delete_prefix("#{Rails.root}/")}: #{texto.strip[0, 120]}" }
    end

    assert_empty culpables, "estos textos le hablan de tú al usuario, y SIGA le habla de usted:\n  " +
                            culpables.join("\n  ")
  end

  # Las líneas que se ven: sin los comentarios de Haml (`-#` y su bloque
  # sangrado debajo) ni los de HTML.
  def texto_de_la_vista(archivo)
    bloque = nil
    File.readlines(archivo).filter_map do |linea|
      sangria = linea[/\A */].size
      if bloque && (linea.strip.empty? || sangria > bloque)
        next
      end

      bloque = nil
      if linea.lstrip.start_with?("-#", "/ ", "<%#")
        bloque = sangria
        next
      end
      linea.gsub(/<!--.*?-->/, "")
    end
  end

  # Las cadenas que son FRASES: entre comillas y con al menos un espacio.
  def frases_entre_comillas(archivo, comentario:)
    File.readlines(archivo).reject { |linea| linea.match?(comentario) }.flat_map do |linea|
      linea.scan(/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`/).flatten.compact
           .select { |cadena| cadena.include?(" ") }
    end
  end
end
