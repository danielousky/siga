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
    sections_path:        "Registrar sección",
    enrollments_path:     "Registrar inscripción"
  }.freeze

  # ⚠️ Departamentos usa la MISMA cabecera con otra variante (MOR-205): en vez
  # de buscador y [+], lleva el campo de alta en línea. Con diez filas a la
  # vista, un buscador es un control que nadie toca.

  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  def listados = LISTADOS.transform_keys { |helper| send(helper) }

  test "departamentos usa la cabecera con alta en línea, sin buscador" do
    get departments_path

    assert css_select(".cabecera-de-lista").any?
    assert css_select(".cabecera-de-lista input[name='department[name]']").any?,
           "el campo de alta tiene que estar en la cabecera"
    assert_empty css_select(".cabecera-de-lista input[name='q']"),
                 "una lista de diez filas no necesita buscador"
  end

  test "todos los listados llevan la cabecera fusionada" do
    sin_cabecera = (listados.keys + [ departments_path ]).reject do |ruta|
      get ruta
      css_select(".cabecera-de-lista").any?
    end

    assert_empty sin_cabecera, "listados que no usan shared/_cabecera_de_lista"
  end

  # ⚠️ El botón se lee («Agregar») pero el tooltip dice QUÉ se agrega. Los dos
  # hacen falta: sin el tooltip, ocho pantallas tienen un botón idéntico que
  # lleva a ocho sitios distintos.
  test "el boton de alta dice qué registra, y lo dice dos veces" do
    fallan = listados.filter_map do |ruta, nombre|
      get ruta
      boton = css_select(".cabecera-de-lista .btn-agregar").first
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

  test "ya no se anuncia «Filtros» en ninguna pantalla" do
    listados.each_key do |ruta|
      get ruta

      assert_no_match(/>\s*Filtros\s*</, response.body, "#{ruta} sigue anunciando «Filtros»")
    end
  end

  # ⚠️ «Buscar» está, pero PEGADO adelante y no encima (MOR-193): dentro del
  # grupo no cuesta altura, que era todo el problema de la etiqueta anterior.
  #
  # Es un `label` de verdad —se toca para enfocar, y es el nombre accesible del
  # campo—, así que el input ya no necesita `aria-label`.
  test "«Buscar» va pegado adelante, dentro del grupo" do
    fallan = listados.keys.filter_map do |ruta|
      get ruta
      rotulo = css_select(".campo-con-boton .campo-con-boton-inicio").first
      next "#{ruta}: no tiene el rótulo" if rotulo.nil?
      next "#{ruta}: dice #{rotulo.text.strip.inspect}" unless rotulo.text.strip == "Buscar"
      next "#{ruta}: el rótulo no apunta al campo" if rotulo["for"].blank?

      nil
    end

    assert_empty fallan
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

  # ⚠️ Daniel: «el mensaje de los estudiantes me parece mejor que va encima de
  # la sección de título». Debajo quedaba entre la cabecera y la tabla,
  # interrumpiendo a quien ya venía a mirar el listado.
  test "el aviso de alumnos sin representante va ENCIMA del título" do
    get students_path

    cuerpo = response.body
    assert cuerpo.index("alert-warning") < cuerpo.index("cabecera-de-lista"),
           "el aviso quedó debajo de la cabecera"
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
