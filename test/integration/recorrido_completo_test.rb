require "test_helper"

# Todas las pantallas, todos los roles, con un colegio COMPLETO detrás.
#
# ## Qué agrega sobre `bin/smoke`
#
# `bin/smoke` es un cliente HTTP contra la base de desarrollo: comprueba que las
# URLs en español existen de verdad y responden. No corre en CI contra datos
# controlados y no puede afirmar nada sobre el contenido.
#
# Esto sí. Y es lo que faltaba: el QA de Daniel del 31/8 y el 1/9 encontró tres
# pantallas rotas —«Nuevo momento», los lapsos vacíos sin salida, la materia que
# exigía departamento— y ninguna daba error. **Todas respondían 200.**
#
# ## La regla
#
# Una pantalla que responde 200 y no dice nada es un callejón. Cada una tiene que
# traer o CONTENIDO —una tabla, una ficha, un formulario— o una EXPLICACIÓN de
# por qué está vacía. El silencio es el fallo.
class RecorridoCompletoTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos
  end

  # Las pantallas de cada rol. Se escriben con el HELPER y no a mano: un `get
  # "/alumnos"` se rompe con el próximo cambio de nombre y deja de probar lo que
  # decía probar. `bin/smoke` es la excepción, porque ahí la URL ES la prueba.
  def pantallas_de_admin
    { "panel"            => dashboards_administrador_path,
      "alumnos"          => students_path,
      "ficha de alumno"  => student_path(@a.alumno),
      "profesores"       => teachers_path,
      "ficha de profesor" => teacher_path(@a.registro_de_profesor),
      "representantes"   => representatives_path,
      "administradores"  => admins_path,
      "grados"           => grades_path,
      "ficha de grado"   => grade_path(@a.grado),
      "secciones"        => sections_path,
      "ficha de sección" => section_path(@a.seccion),
      "materias"         => subjects_path,
      "ficha de materia" => subject_path(@a.materia),
      "departamentos"    => departments_path,
      "inscripciones"    => enrollments_path,
      "años escolares"   => academic_periods_path,
      "copiar estructura" => copiar_al_academic_period_path(@a.periodo),
      "lapsos"           => evaluation_moments_path,
      "evaluaciones"     => evaluation_activities_path,
      "boletines"        => report_cards_path,
      "constancias"      => constancias_path,
      "asistencia"       => asistencias_path,
      "reporte de asistencia" => reporte_asistencia_path,
      "quién no cargó"   => carga_de_notas_path,
      "auditoría"        => dashboards_activity_logs_path,
      "el colegio"       => colegio_path,
      "niveles"          => niveles_del_colegio_path,
      "importaciones"    => importaciones_path,
      "mi cuenta"        => cuenta_path }
  end

  def altas_de_admin
    { "alta de alumno"        => new_student_path,
      "alta de profesor"      => new_teacher_path,
      "alta de representante" => new_representative_path,
      "alta de administrador" => new_admin_path,
      "alta de grado"         => new_grade_path,
      "alta de sección"       => new_section_path,
      "alta de materia"       => new_subject_path,
      "alta de departamento"  => new_department_path,
      "alta de inscripción"   => new_enrollment_path,
      "alta de año escolar"   => new_academic_period_path,
      "alta de lapso"         => new_evaluation_moment_path,
      "alta de importación"   => new_importacion_path }
  end

  # ══════════════════════════════════════════════════════════════════════════

  test "el director recorre todas sus pantallas sin encontrar una muda" do
    sign_in @a.director

    assert_empty pantallas_mudas(pantallas_de_admin),
                 "pantallas que responden pero no dicen nada"
  end

  test "y todos los formularios de alta se pueden llenar o explican por qué no" do
    sign_in @a.director

    assert_empty pantallas_mudas(altas_de_admin),
                 "formularios de alta que no traen ni campos ni explicación"
  end

  test "el profesor recorre las suyas" do
    sign_in @a.profesor

    assert_empty pantallas_mudas(
      "panel"          => dashboards_profesor_path,
      "evaluaciones"   => evaluation_activities_path,
      "nueva evaluación" => new_evaluation_activity_path,
      "asistencia"     => asistencias_path,
      "mi cuenta"      => cuenta_path
    )
  end

  test "el alumno recorre las suyas" do
    sign_in @a.estudiante

    assert_empty pantallas_mudas(
      "panel"     => dashboards_estudiante_path,
      "mis notas" => dashboards_notas_path,
      "mi cuenta" => cuenta_path
    )
  end

  # ⚠️ El recorrido con el año escolar en «Todos los años» (MOR-165). Es el modo
  # que menos se usa y el que más consultas cambia — varios listados dejan de
  # filtrar y algunas pantallas se quedan sin un año sobre el que trabajar.
  # ⚠️ Este es el que de verdad importa. Ver `listados_sin_estado_vacio`.
  #
  # Se corre sobre un colegio VACÍO a propósito: es el único estado en el que
  # TODAS las listas están vacías a la vez, o sea el único que revisa las
  # dieciocho de una pasada. Y es el día 1 de cada cliente nuevo.
  test "ningún listado vacío deja una tabla con encabezados y nada debajo" do
    vacio = Current.sin_aislamiento do
      School.create!(name: "Colegio Sin Nada", dea_code: "TESTSINNADA", location: "Caracas")
    end
    directora = User.create!(first_name: "Directora", last_name: "SinNada",
                             email: "dir.sinnada@test.test", password: "123123",
                             document: "V-55443322", document_type: :cedula_v)
    con_el_colegio(vacio) { Admin.create!(user: directora, school: vacio, role: :director) }

    sign_in directora
    callejones = listados_sin_estado_vacio(pantallas_de_admin)

    assert_empty callejones,
                 "listados que responden 200 y dejan a la persona sin saber si el " \
                 "sistema está roto o de verdad no hay nada:\n  " + callejones.join("\n  ")
  end

  # El OTRO vacío, que es distinto y no se puede decir igual.
  #
  # «Todavía no hay ninguno» y «tu búsqueda no encontró nada» son dos hechos
  # opuestos, y con la misma pantalla vacía quien filtró por un apellido cree que
  # perdió el padrón entero. Peor: la acción correcta es opuesta —cargar datos
  # en un caso, borrar el filtro en el otro—.
  test "una búsqueda sin resultados lo dice, y no finge que la lista está vacía" do
    sign_in @a.director

    listas = { "alumnos" => students_path, "profesores" => teachers_path,
               "representantes" => representatives_path, "materias" => subjects_path,
               "secciones" => sections_path, "inscripciones" => enrollments_path }

    mudas = listas.filter_map do |que, ruta|
      get ruta, params: { q: "zzz-no-existe-nada-con-esto" }
      next "#{que} → #{response.status}" unless response.successful?
      next if css_select("tbody tr").empty? && css_select(".empty-state h3, .lista-vacia h3").any?

      if css_select("tbody tr").any?
        "#{que}: la búsqueda imposible devolvió filas"
      else
        "#{que}: no encontró nada y no lo dice"
      end
    end

    assert_empty mudas, "búsquedas sin resultados que no se explican:\n  " + mudas.join("\n  ")
  end

  test "el director recorre todo con «todos los años» elegido" do
    sign_in @a.director
    post cambiar_anio_escolar_path, params: { id: LlevaElAnioEscolar::TODOS }

    assert_empty pantallas_mudas(pantallas_de_admin.merge(altas_de_admin))
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El panel de SIGA — la otra app dentro de la app
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Daniel ya lo marcó una vez: «desde allí no puedo hacer nada, el enlace a
  # colegios/new no hace nada». Vive en su propio namespace (MOR-133) y por eso
  # es fácil que se quede atrás de los cambios del resto.

  test "el equipo de SIGA recorre su panel" do
    fundador = User.create!(first_name: "Fundador", last_name: "SIGA",
                            email: "fundador.recorrido@siga.test", password: "123123",
                            document: "V-11223344", document_type: :cedula_v)
    SigaStaff.create!(user: fundador, role: :fundador)
    sign_in fundador

    assert_empty pantallas_mudas(
      "panel de plataforma" => siga_root_path,
      "colegios"            => siga_colegios_path,
      "ficha de colegio"    => siga_colegio_path(@a.colegio),
      "alta de colegio"     => new_siga_colegio_path,
      "cartera"             => siga_cartera_index_path,
      "solicitudes"         => siga_solicitudes_path
    )
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo público: lo primero que ve alguien que llega por un enlace
  # ══════════════════════════════════════════════════════════════════════════

  test "las páginas públicas abren sin sesión" do
    assert_empty pantallas_mudas(
      "portada"          => root_path,
      "entrar"           => new_user_session_path,
      "registrar colegio" => registrarse_path,
      "recuperar clave"  => new_user_password_path,
      "verificar boletín" => verificar_path
    )
  end

  private

  # Una pantalla «habla» si trae contenido de verdad, un formulario que llenar, o
  # un cartel que explique el vacío.
  #
  # ⚠️ Los campos se cuentan SOLO dentro de formularios que guardan
  # (`method=post`). El buscador de cada listado es un `form` con un `input
  # name="q"` y está en todas las pantallas de lista: contarlo hacía que
  # cualquier lista vacía «hablara», y el test dejaba de poder fallar.
  def pantallas_mudas(rutas)
    rutas.filter_map do |que, ruta|
      get ruta

      # Un redirect no es un fallo: `/asistencia` con una sola sección lleva
      # derecho a su planilla, que es lo correcto. Lo que se exige es que el
      # destino hable. Dos saltos como máximo — más que eso es un bucle.
      2.times { response.redirect? ? follow_redirect! : break }

      next "#{que} (#{ruta}) → #{response.status}" unless response.successful?

      "#{que} (#{ruta}): responde 200 y no dice nada" unless habla?
    end
  end

  # ⚠️ Se mide TEXTO, no nombres de clase.
  #
  # El primer intento listaba clases —`.metric-value`, `.ficha-nombre`— y fallaba
  # con cada pantalla que usa las suyas: el panel del alumno tiene
  # `.ficha-materia`, la asistencia tiene `.asistencia-lista`. Un test que hay
  # que actualizar cada vez que alguien nombra una clase nueva se termina
  # aflojando hasta que no prueba nada.
  #
  # El texto del `main`, sin el layout, es la definición honesta de «dice algo».
  MINIMO_DE_TEXTO = 80

  # Los tres cascarones donde puede caer el contenido: el `main` de la sesión
  # del colegio, el del panel de SIGA, y el `div` de las páginas públicas y de
  # quien todavía no tiene rol. Sin el tercero, la portada y el registro
  # aparecían como pantallas mudas.
  CONTENIDO = "main.container-academic, main.siga-contenido, .container-academic".freeze

  def habla?
    contenido = css_select(CONTENIDO).first
    return false if contenido.nil?

    # Fuera la franja del recorrido y los botones de la cabecera: están en
    # pantallas que por lo demás están vacías.
    texto = contenido.text.gsub(/\s+/, " ").strip

    texto.length >= MINIMO_DE_TEXTO ||
      css_select("tbody tr").any? ||
      campos_que_guardan.any?
  end

  def campos_que_guardan
    css_select("form[method=post]").flat_map do |form|
      form.css("input, textarea, select").reject { |c| %w[hidden submit].include?(c["type"]) }
    end
  end

  # ⚠️ La regla específica que este test existe para cuidar.
  #
  # Un listado con CERO filas tiene que traer su estado vacío. Sin él queda una
  # tabla con encabezados y nada debajo: responde 200, no falla, y deja a la
  # persona sin saber si el sistema está roto o si de verdad no hay nada.
  #
  # Es exactamente lo que Daniel encontró en `/lapsos` el 31 de agosto, y la
  # convención que MOR-154 estableció con `shared/lista_vacia`.
  def listados_sin_estado_vacio(rutas)
    rutas.filter_map do |que, ruta|
      get ruta
      2.times { response.redirect? ? follow_redirect! : break }
      next unless response.successful?

      tablas_vacias = css_select("table.table-academic").select { |t| t.css("tbody tr").empty? }
      next if tablas_vacias.empty?
      next if css_select(".empty-state, .lista-vacia").any?

      "#{que} (#{ruta}): tabla con encabezados y ninguna fila, sin estado vacío"
    end
  end
end
