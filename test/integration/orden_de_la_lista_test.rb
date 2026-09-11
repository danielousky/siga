require "test_helper"

# El orden de la LISTA DE CLASE, que es uno solo para todo el sistema.
#
# ## ⚠️ Estaba escrito cinco veces y en dos órdenes distintos
#
#     pestaña «Alumnos»    ORDER BY users.last_name    ← SQL, PRIMER apellido
#     informes                                         ← Ruby, LOS DOS
#     la libreta · Inicial · el Excel                      ídem
#
# El primero no tenía desempate, y los apellidos repetidos abundan —«3er Grado
# A» de los seeds tiene cinco pares—. Con el número de fila a la vista, eso es
# una contradicción que se lee: «la número 12» no era la misma niña en la
# pantalla y en el papel que se baja de esa pantalla.
class OrdenDeLaListaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    sign_in @a.director
  end

  # Cuatro apellidos que ordenan mal de las dos maneras equivocadas: por punto
  # de código («Á» va después de «Z») y por primer apellido a secas (los dos
  # «Peña» necesitan desempate).
  def inscribir(*nombres)
    con_el_colegio(@a.colegio) do
      nombres.each_with_index.map do |(apellido, segundo, nombre), i|
        usuario = User.create!(first_name: nombre, last_name: apellido, second_last_name: segundo,
                               cedula_escolar: "O#{@a.colegio.id}#{i.to_s.rjust(4, '0')}")
        alumno = Student.create!(user: usuario, school: @a.colegio, school_card: "O-#{@a.colegio.id}-#{i}")
        Enrollment.create!(student: alumno, section: @a.seccion, enrollment_date: Date.new(2025, 9, 20))
      end
    end
  end

  # ⚠️ Dentro de `con_el_colegio`: fuera del contexto, el RLS devuelve CERO
  # filas y el test pasaría comparando dos listas vacías.
  def apellidos_en_orden
    con_el_colegio(@a.colegio) do
      Enrollment.en_orden_de_lista(@a.seccion.enrollments)
                .map { |i| i.student.user.apellidos_y_nombres }
    end
  end

  # ── El acento ─────────────────────────────────────────────────────────────

  # ⚠️ `sort_by` compara por punto de código y «Á» (U+00C1) es MAYOR que «Z»:
  # Álvarez salía de ÚLTIMO, después de Zambrano. Y Álvarez, Ángel y Ávila son
  # apellidos venezolanos corrientes.
  test "Álvarez va primero, no después de Zambrano" do
    inscribir [ "ZAMBRANO", nil, "ANA" ], [ "ÁLVAREZ", nil, "LUIS" ], [ "MEDINA", nil, "JUAN" ]

    orden = apellidos_en_orden

    assert_operator orden.index("Álvarez, Luis"), :<, orden.index("Medina, Juan")
    assert_operator orden.index("Medina, Juan"), :<, orden.index("Zambrano, Ana")
  end

  # ── El desempate ──────────────────────────────────────────────────────────

  # ⚠️ Dos apellidos iguales necesitan desempate, o el orden cambia entre una
  # consulta y la siguiente: `ORDER BY` sin criterio no lo garantiza, y
  # `sort_by` en Ruby tampoco es estable.
  test "el mismo apellido desempata por el segundo y por el nombre" do
    inscribir [ "PÉREZ", "MEDINA", "ANA" ], [ "PÉREZ", "ALVARADO", "BEATRIZ" ]

    orden = apellidos_en_orden

    assert_operator orden.index("Pérez Alvarado, Beatriz"), :<, orden.index("Pérez Medina, Ana")
  end

  test "el orden no cambia entre una consulta y otra" do
    inscribir [ "PEÑA", nil, "ANA" ], [ "PENA", nil, "ANA" ], [ "PEÑA", nil, "ANA" ]

    # ⚠️ La cuenta primero: comparar dos listas VACÍAS pasa igual, y entonces
    # este test no probaría nada. Los tres de arriba más los dos del escenario.
    assert_equal 5, apellidos_en_orden.size
    assert_equal apellidos_en_orden, apellidos_en_orden
  end

  # ── Y las cinco listas dicen lo mismo ─────────────────────────────────────

  # ⚠️ Lo que importa no es el orden en abstracto: es que la pantalla y el
  # archivo que se baja DE esa pantalla numeren igual al mismo niño.
  test "la pestaña Alumnos y el Excel numeran igual" do
    inscribir [ "ZAMBRANO", nil, "ANA" ], [ "ÁLVAREZ", nil, "LUIS" ],
              [ "PÉREZ", "MEDINA", "ANA" ], [ "PÉREZ", "ALVARADO", "BEATRIZ" ]

    get alumnos_section_path(@a.seccion)
    en_pantalla = css_select("tbody .persona-linea-nombre").map(&:text)
    # Los cuatro de arriba más los dos del escenario. Sin esto, dos listas
    # vacías se darían por iguales y el test no probaría nada.
    assert_equal 6, en_pantalla.size

    get alumnos_section_path(@a.seccion, format: :xlsx)
    archivo = Tempfile.new([ "lista", ".xlsx" ], binmode: true)
    archivo.write(response.body)
    archivo.flush
    hoja = Roo::Excelx.new(archivo.path)
    # La tabla empieza en la fila 6; la 7 es el primer alumno.
    en_excel = (7...(7 + en_pantalla.size)).map { |f| "#{hoja.cell(f, 2)}, #{hoja.cell(f, 3)}" }

    assert_equal en_pantalla, en_excel
  end
end
