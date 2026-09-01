require "test_helper"

# Todos los listados llevan la MISMA cabecera (MOR-192).
#
# Daniel: *«el sección filtro ocupa demasiado espacio, vamos a cambiar para
# TODAS las vistas ese elemento, vamos a fusionarlo con el título… Elimina
# "Filtros" y "Buscar", es evidente pienso»*.
#
# Lo que cuida este test no es que se vea lindo: es que las ocho pantallas usen
# el mismo componente. Antes había filtro en tres listados, ninguno en otros
# cuatro, y cada uno armaba su lista de campos a mano — nadie podía predecir
# cuál lo tenía.
class CabeceraDeListaTest < ActionDispatch::IntegrationTest
  # Cada listado con el nombre que tiene que decir el tooltip del [+].
  #
  # ⚠️ La ruta se pide por HELPER, nunca escrita a mano: un `get "/alumnos"` se
  # rompe con el próximo `path:` y deja de probar lo que decía probar.
  LISTADOS = {
    students_path:        "Registrar alumno",
    representatives_path: "Registrar representante",
    teachers_path:        "Registrar profesor",
    subjects_path:        "Registrar materia",
    departments_path:     "Registrar departamento",
    sections_path:        "Registrar sección",
    enrollments_path:     "Registrar inscripción"
  }.freeze

  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  def listados = LISTADOS.transform_keys { |helper| send(helper) }

  test "todos los listados llevan la cabecera fusionada" do
    sin_cabecera = listados.keys.reject do |ruta|
      get ruta
      css_select(".cabecera-de-lista").any?
    end

    assert_empty sin_cabecera, "listados que no usan shared/_cabecera_de_lista"
  end

  # ⚠️ El [+] es un control que es SOLO un icono, así que el tooltip **es** su
  # nombre: sin él no hay manera de saber a dónde lleva. Y el `aria-label` no es
  # decorativo — un lector de pantalla anuncia «enlace» y nada más.
  test "el boton de alta dice qué registra, y lo dice dos veces" do
    fallan = listados.filter_map do |ruta, nombre|
      get ruta
      boton = css_select(".cabecera-de-lista .btn-solo-icono").first
      next "#{ruta}: no tiene [+]" if boton.nil?
      next if boton["data-tooltip"] == nombre && boton["aria-label"] == nombre

      "#{ruta}: tooltip #{boton['data-tooltip'].inspect}, aria-label #{boton['aria-label'].inspect}"
    end

    assert_empty fallan, "el [+] tiene que nombrarse igual en el tooltip y en el aria-label"
  end

  # ⚠️ `title` no: no se puede estilar, tarda un segundo en salir y **en el
  # teléfono no existe** (MOR-173).
  test "el tooltip es data-tooltip y nunca title" do
    get students_path

    assert css_select(".cabecera-de-lista [data-tooltip]").any?
    assert_empty css_select(".cabecera-de-lista [title]")
  end

  test "ya no se anuncian «Filtros» ni se etiqueta «Buscar»" do
    listados.each_key do |ruta|
      get ruta

      assert_no_match(/>\s*Filtros\s*</, response.body, "#{ruta} sigue anunciando «Filtros»")
      assert_empty css_select(".cabecera-de-lista label[for$='_q']"),
                   "#{ruta}: el campo de búsqueda no necesita etiqueta, tiene su placeholder"
    end
  end

  # El placeholder es lo ÚNICO que queda explicando qué se puede buscar, así que
  # tiene que estar en todos.
  test "cada buscador dice qué se puede escribir en él" do
    mudos = listados.keys.reject do |ruta|
      get ruta
      css_select(".cabecera-de-lista input[type=text]").first&.[]("placeholder").present?
    end

    assert_empty mudos, "buscadores sin placeholder: no se sabe qué aceptan"
  end

  # ⚠️ El registro de actividad usa la MISMA cabecera aunque tenga cuatro
  # filtros: es la pantalla donde envuelve a dos líneas, no una excepción.
  test "el registro de actividad también usa la cabecera" do
    get dashboards_activity_logs_path

    assert css_select(".cabecera-de-lista").any?
    assert_equal 2, css_select(".cabecera-de-lista input[type=date]").size,
                 "el rango de fechas tiene que seguir estando"
  end

  test "los parciales viejos del filtro ya no existen" do
    %w[_buscador_de_lista _search_filter].each do |viejo|
      assert_not File.exist?(Rails.root.join("app/views/shared/#{viejo}.html.haml")),
                 "#{viejo} quedó sin consumidores: borrarlo es parte del cambio"
    end
  end

  # ⚠️ Sin relleno arriba, la primera tarjeta nace contra el borde de la barra.
  # Daniel: «el padding del content está pegado con navbar».
  test "el contenido no arranca pegado a la barra" do
    hoja = Rails.root.join("app/assets/stylesheets/system.css").read
    regla = hoja[/\.container-academic \{[^}]+\}/m]

    assert_no_match(/padding:\s*0\s/, regla, "el relleno de arriba volvió a cero")
  end
end
