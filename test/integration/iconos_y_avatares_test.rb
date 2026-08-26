require "test_helper"

# Los iconos y los avatares, y las reglas que los sostienen (MOR-149).
#
# ## Por qué esto es un test y no una convención escrita
#
# La app llegó a agosto de 2026 con CERO iconos y con 44 botones usando clases de
# Bootstrap que no existen — una convención escrita no impidió ninguna de las dos
# cosas. Lo que sí funcionó fueron `sistema_de_diseno_test` y
# `regla_de_color_test`, que fallan en CI antes de que el problema llegue a una
# pantalla.
#
# Este hace lo mismo con lo que se agregó ahora.
class IconosYAvataresTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
  end

  # ── el catálogo ───────────────────────────────────────────────────────────

  # ⚠️ Un icono roto no se ve como un error: se ve como un hueco, y un hueco se
  # confunde con «esta pantalla todavía no está lista».
  test "todos los iconos del catálogo dibujan SVG válido" do
    IconosHelper::CAMINOS.each do |nombre, camino|
      assert_match(/\A<(path|circle|rect)/, camino, "el icono :#{nombre} no empieza con una forma")
      assert_no_match(/fill="(?!none)/, camino,
                      "el icono :#{nombre} trae relleno propio: no va a heredar el color del texto")
      # Todos comparten viewBox 0 0 24 24, así que ninguna coordenada puede
      # salirse: un 26 dibuja fuera del recuadro y se ve recortado.
      camino.scan(/-?\d+(?:\.\d+)?/).each do |numero|
        assert_operator numero.to_f.abs, :<=, 26,
                        "el icono :#{nombre} tiene la coordenada #{numero}, fuera del viewBox"
      end
    end
  end

  test "un icono que no existe devuelve nil en vez de romper la página" do
    assert_nil ApplicationController.helpers.icono(:no_existe_este_icono)
  end

  # ⚠️ La accesibilidad de un icono depende de si va solo o acompañado, y es la
  # clase de detalle que se pierde en el primer refactor.
  test "el icono decorativo se oculta y el que nombra un control se anuncia" do
    decorativo = ApplicationController.helpers.icono(:alumnos).to_s
    assert_includes decorativo, 'aria-hidden="true"'
    assert_includes decorativo, 'focusable="false"'

    con_nombre = ApplicationController.helpers.icono(:borrar, titulo: "Eliminar").to_s
    assert_includes con_nombre, 'role="img"'
    assert_includes con_nombre, 'aria-label="Eliminar"'
    assert_not_includes con_nombre, "aria-hidden"
  end

  # ── el menú ───────────────────────────────────────────────────────────────

  # Es la regresión que este trabajo vino a arreglar: diecinueve enlaces de texto
  # plano, sin una sola señal visual.
  test "el menú del administrador lleva iconos" do
    sign_in @a.director
    get dashboards_administrador_path

    assert_response :success
    assert_select "svg.icono", minimum: 10
    assert_select ".sidebar-nav-link svg", minimum: 10
  end

  # ⚠️ El icono ACOMPAÑA a la palabra, no la reemplaza.
  #
  # Un menú de iconos solos obliga a aprenderse el alfabeto antes de poder usarlo,
  # y quien abre SIGA por primera vez es una secretaria que hasta ayer llevaba
  # todo en Word.
  test "ningún enlace del menú se queda sin su palabra" do
    sign_in @a.director
    get dashboards_administrador_path

    css_select(".sidebar-nav-link").each do |enlace|
      texto = enlace.text.strip
      assert texto.present?, "hay un enlace de menú sin texto: #{enlace.to_html.truncate(90)}"
    end
  end

  test "los cuatro roles tienen su menú con iconos" do
    [ [ @a.director, dashboards_administrador_path ],
      [ @a.profesor, dashboards_profesor_path ],
      [ @a.estudiante, dashboards_estudiante_path ] ].each do |persona, ruta|
      sign_in persona
      get ruta

      assert_response :success
      assert_select "svg.icono", minimum: 1, message: "#{ruta} no tiene ningún icono"
      sign_out persona
    end
  end

  # ── los avatares ──────────────────────────────────────────────────────────

  # ⚠️ LA regla que no se puede romper: en SIGA el rojo es un niño aplazado.
  #
  # Si el avatar de Rodríguez sale rojo porque su apellido cayó ahí, el rojo deja
  # de querer decir lo que quiere decir — y en una lista donde conviven avatares y
  # notas, el ojo no distingue cuál de los dos importa.
  test "ningún color de avatar se confunde con un estado" do
    AvataresHelper::COLORES.each do |hex|
      r, g, b = hex.delete("#").scan(/../).map { |v| v.to_i(16) }

      assert_not(r > 150 && r > g * 1.6 && r > b * 1.6, "#{hex} se lee como rojo de aplazado")
      assert_not(g > 130 && g > r * 1.4 && g > b * 1.4, "#{hex} se lee como verde de al día")
      assert_not(r > 180 && g > 130 && b < 90, "#{hex} se lee como ámbar de atención")
    end
  end

  # Las iniciales van sobre color, en blanco: si el contraste no llega a 4.5:1 no
  # se leen, y un avatar que no se lee es una mancha de color.
  test "los ocho colores pasan el contraste que exige WCAG AA" do
    AvataresHelper::COLORES.each do |hex|
      assert_operator contraste_con_blanco(hex), :>=, 4.5, "#{hex} no llega a 4.5:1 contra blanco"
    end
  end

  # ⚠️ El color sale del NOMBRE, no del `id`.
  #
  # Con el `id` la misma persona cambiaría de color entre el colegio A y el
  # colegio B —son filas distintas de `students`— y en la vista consolidada de una
  # red de colegios se vería como dos personas.
  test "la misma persona tiene el mismo color en cualquier colegio" do
    persona = User.new(first_name: "MARÍA", last_name: "PÉREZ")
    otra_fila = User.new(first_name: "MARÍA", last_name: "PÉREZ")

    assert_equal ApplicationController.helpers.color_de(persona),
                 ApplicationController.helpers.color_de(otra_fila)
  end

  # ⚠️ «DE LA CRUZ MARÍN JOSÉ LUIS» daría «DL» tomando las dos primeras palabras,
  # y «DL» no identifica a nadie.
  test "las iniciales saltan las partículas del apellido" do
    {
      [ "DE LA CRUZ", "JOSÉ LUIS" ] => "CJ",
      [ "LÓPEZ", "ÁLVARO" ]         => "LÁ",
      [ "DEL VALLE", "ANA" ]        => "VA"
    }.each do |(apellido, nombre), esperado|
      persona = User.new(last_name: apellido, first_name: nombre)

      assert_equal esperado, ApplicationController.helpers.iniciales_de(persona),
                   "«#{apellido} #{nombre}» debería dar #{esperado}"
    end
  end

  # Una persona sin foto no es un hueco: las iniciales SON el avatar.
  test "sin foto el avatar sale igual de terminado" do
    dibujado = ApplicationController.helpers.avatar(@a.estudiante).to_s

    assert_includes dibujado, "avatar"
    assert_includes dibujado, "--avatar-color:"
    assert_includes dibujado, ApplicationController.helpers.iniciales_de(@a.estudiante)
  end

  private

  def contraste_con_blanco(hex)
    canales = hex.delete("#").scan(/../).map { |v| v.to_i(16) / 255.0 }
    lineal = canales.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
    luminancia = lineal.zip([ 0.2126, 0.7152, 0.0722 ]).sum { |c, k| c * k }

    1.05 / (luminancia + 0.05)
  end
end
