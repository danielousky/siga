require "test_helper"

# El nivel de la sesión: el segundo pivote, junto al año escolar.
#
# Daniel: *«creo que la gestión de todo, además de dividirse en Año Escolar, el
# otro gran elemento divisor son los tipos que maneja la institución. Puede ser
# confuso crear una sección y que me aparezcan preescolar, primaria y
# bachillerato juntos… seteas un Año Escolar y luego un tipo: vamos a trabajar
# Primaria»*.
#
# ## Qué se prueba de verdad
#
# No que el desplegable se pinte. Las cuatro cosas que se rompen en silencio:
#
#   1. que elegir un nivel CAMBIE lo que devuelven las consultas;
#   2. que el filtro **no toque la matrícula que factura** — un colegio de 360
#      cobrado como uno de 140 sale de la impresora sin que nadie lo mire;
#   3. que un formulario de edición no BORRE el grado de lo que está editando;
#   4. que las pantallas donde el nivel no significa nada lo digan, en vez de
#      mostrar el filtro puesto y una lista sin filtrar.
class NivelDeLaSesionTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    # ⚠️ La mitad del test: sin DOS niveles poblados, filtrar por uno no se
    # distingue de no filtrar. `dos_colegios_completos` trae «1er Año»
    # (bachillerato); acá se le agrega la primaria completa.
    @primaria, @seccion_de_primaria, @alumno_de_primaria = con_el_colegio(@a.colegio) do
      grado = Grade.create!(school: @a.colegio, name: "6to Grado")
      seccion = Section.create!(grade: grado, academic_period: @a.escenario.periodo,
                                name: "U", capacity: 30)
      persona = User.create!(first_name: "Nina", last_name: "Primaria",
                             cedula_escolar: "PRIM#{@a.colegio.id}")
      alumno = Student.create!(user: persona, school: @a.colegio, school_card: "P-#{@a.colegio.id}")
      Enrollment.create!(student: alumno, section: seccion, enrollment_date: Date.new(2025, 9, 20))
      [ grado, seccion, alumno ]
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El selector aparece cuando hay algo que elegir, y no antes
  # ══════════════════════════════════════════════════════════════════════════

  test "un colegio con un solo nivel no ve el selector" do
    sign_in @b.director   # solo bachillerato
    get sections_path

    assert_select ".contexto-nivel-boton", count: 0,
                  message: "un desplegable de una opción es un control que no decide nada"
  end

  test "un colegio con dos niveles sí lo ve" do
    entrar_en_a
    get sections_path

    # ⚠️ TRES botones, no uno: «Todos» + los dos niveles que el colegio dicta.
    # Con un `<select>` era un control con tres opciones adentro; ahora las
    # opciones son el control, que es lo que hace que se vea cuál está puesta
    # sin abrir nada.
    assert_select ".contexto-nivel-boton", 3
    assert_select ".contexto-nivel-boton", text: "Todos"
    assert_select ".contexto-nivel-boton", text: "Primaria"
    assert_select ".contexto-nivel-boton", text: "Bachillerato"
  end

  # ⚠️ El profesor no elige nivel, igual que no elige año escolar. No es
  # permisología: es que para él el nivel no es una preferencia.
  test "el profesor no ve el selector" do
    sign_in @a.profesor
    get root_path

    assert_select ".contexto-nivel-boton", 0
  end

  test "el profesor no puede cambiarlo por POST" do
    sign_in @a.profesor
    post cambiar_nivel_path, params: { nivel: :primaria }

    assert_response :redirect
    assert_nil session[LlevaElNivel::CLAVE],
               "un profesor que cambia el nivel carga notas en el nivel equivocado sin enterarse"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Por defecto: TODOS
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Y no el primer nivel del colegio. Es la misma trampa que
  # `AcademicPeriod.en_operacion` resolvió para el año: un director de 360
  # alumnos que abre el panel y lee 142 no concluye «estoy en primaria»,
  # concluye que se perdieron los datos.
  test "al entrar se ven todos los niveles" do
    entrar_en_a
    get sections_path

    assert_select ".contexto-nivel-boton.elegida", text: "Todos"
    assert_select "table.table-academic td", text: @a.seccion.name
    assert_select "table.table-academic td", text: @seccion_de_primaria.name
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Elegir un nivel recorta lo que se ve
  # ══════════════════════════════════════════════════════════════════════════

  test "con primaria elegida solo se ven sus secciones" do
    entrar_en_a
    elegir :primaria

    get sections_path
    assert_select "table.table-academic td", text: @seccion_de_primaria.name
    assert_select "table.table-academic td", text: @a.seccion.name, count: 0
  end

  test "con primaria elegida solo se ven sus grados, y sin la columna Nivel" do
    entrar_en_a
    elegir :primaria

    get grades_path
    assert_select "table.table-academic td", text: @primaria.name
    assert_select "table.table-academic td", text: @a.grado.name, count: 0
    assert_select "th", text: "Nivel", count: 0,
                  message: "con el nivel puesto arriba, repetirlo en cada fila lo dice catorce veces"
  end

  test "con todos elegido la columna Nivel vuelve, porque ahí sí distingue" do
    entrar_en_a
    get grades_path

    assert_select "th", text: "Nivel", count: 1
  end

  test "con primaria elegida solo se ven sus alumnos" do
    entrar_en_a
    elegir :primaria

    get students_path
    assert_select "td", text: /Nina/
    assert_select "td", text: /Alumno1/, count: 0
  end

  test "el conteo dice de qué nivel está contando" do
    entrar_en_a
    elegir :primaria

    get students_path
    assert_select ".listado-escala-nivel", text: "de Primaria"
  end

  # ⚠️ Bachillerato abarca DOS valores del enum. Un colegio técnico dicta 1er a
  # 5to Año como cualquiera y agrega un 6to que gradúa Técnico Medio; si
  # «Bachillerato» filtrara solo por `secundaria`, elegirlo escondería ese 6to
  # Año — la trampa que `Grade#media?` existe para evitar.
  test "bachillerato incluye el sexto año de la media técnica" do
    sexto = con_el_colegio(@a.colegio) { Grade.create!(school: @a.colegio, name: "6to Año") }
    assert_equal "media_tecnica", sexto.level

    entrar_en_a
    elegir :secundaria

    get grades_path
    assert_select "table.table-academic td", text: "6to Año",
                  message: "elegir Bachillerato escondía el sexto año del técnico"
    assert_select "table.table-academic td", text: @a.grado.name
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que el filtro NO puede tocar
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ La peor consecuencia posible de este cambio, y silenciosa: la factura
  # sale más barata y nadie la mira.
  test "la matrícula que factura es la del colegio, elija lo que elija" do
    entera = Subscription.matricula_de(@a.colegio.id)

    entrar_en_a
    elegir :primaria

    assert_equal entera, Subscription.matricula_de(@a.colegio.id),
                 "el nivel de la sesión no puede cambiar lo que se cobra"
  end

  # ⚠️ Un importador que filtrara dejaría a medias la planilla de un colegio con
  # tres niveles, y el reporte diría que se importó bien.
  test "el importador no filtra por nivel" do
    entrar_en_a
    elegir :primaria

    get new_importacion_path(tipo: :matricula)
    assert_response :success
    assert_select ".contexto-pastilla-nota[data-tooltip*=?]", "varios niveles"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Editar no puede perder lo que ya está guardado
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ El nivel de la sesión es una preferencia de quien mira. Un desplegable
  # sin el grado del propio registro lo dejaría en «Seleccione…» y guardar lo
  # borraría — que es donde un filtro deja de ser preferencia y pasa a ser daño.
  test "editar una sección de otro nivel conserva su grado en el desplegable" do
    entrar_en_a
    elegir :primaria

    get edit_section_path(@a.seccion)   # una sección de BACHILLERATO
    assert_response :success
    assert_select "select#section_grade_id option[selected]", text: @a.grado.name
  end

  test "editar una inscripción de otro nivel conserva su sección" do
    entrar_en_a
    elegir :primaria

    get edit_enrollment_path(@a.escenario.inscripcion)
    assert_response :success
    assert_select "select#enrollment_section_id option[selected]",
                  text: "#{@a.grado.name} – #{@a.seccion.name}"
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Donde el nivel no aplica, la pantalla lo dice
  # ══════════════════════════════════════════════════════════════════════════

  # ⚠️ Un filtro que aparece puesto y no filtra es peor que no tenerlo: quien ve
  # «PRIMARIA» arriba y ocho departamentos concluye que primaria tiene ocho.
  SIN_NIVEL = {
    departments_path: "Los departamentos son de todo el colegio",
    academic_periods_path: "El año escolar es de todo el colegio",
    evaluation_moments_path: "Los lapsos son de todo el colegio",
    admins_path: "El equipo de dirección es de todo el colegio",
    subjects_path: "Una materia puede darse en varios niveles"
  }.freeze

  test "las pantallas donde el nivel no aplica lo dicen" do
    entrar_en_a
    elegir :primaria

    SIN_NIVEL.each do |ruta, motivo|
      get send(ruta)
      # ⚠️ El texto visible es fijo —«Acá no aplica»— y la razón vive en el
      # tooltip: 39 caracteres en la barra se recortaban a «los departamen».
      assert_select ".contexto-pastilla-nota", text: "acá no aplica",
                    message: "#{ruta} tiene el filtro puesto y no filtra, sin decirlo"
      assert_select ".contexto-pastilla-nota[data-tooltip=?]", motivo,
                    message: "#{ruta} no explica POR QUÉ no aplica"
    end
  end

  # Y con «Todos» no dice nada: no hay nada que contradiga a la pantalla.
  test "con todos elegido no aparece el aviso de que no aplica" do
    entrar_en_a
    get departments_path

    assert_select ".contexto-pastilla-nota", 0
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La sesión, y el colegio de al lado
  # ══════════════════════════════════════════════════════════════════════════

  test "el nivel elegido sobrevive al cambio de pantalla" do
    entrar_en_a
    elegir :primaria

    get grades_path
    assert_select ".contexto-nivel-boton.elegida", text: "Primaria"
  end

  # ⚠️ Un nivel guardado que este colegio no dicta cae a «todos», y no filtra
  # por nada. La comprobación la hace el dato —los grados que hay— y no un `if`.
  test "un nivel que el colegio no dicta cae a todos" do
    entrar_en_a
    elegir :preescolar   # el colegio A no tiene preescolar

    get sections_path
    assert_select "table.table-academic td", text: @a.seccion.name
    assert_select "table.table-academic td", text: @seccion_de_primaria.name
  end

  private

  def entrar_en_a = sign_in(@a.director)

  def elegir(nivel)
    post cambiar_nivel_path, params: { nivel: nivel }
    follow_redirect!
  end
end
