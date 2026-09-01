require "test_helper"

# Copiar la estructura de un año escolar al siguiente (MOR-166).
#
# Un colegio de diez secciones con ocho materias son OCHENTA asignaciones de
# profesor escritas a mano cada septiembre, cuando el 90 % son las mismas del
# año anterior. Es la clase de trabajo que hace que un colegio no renueve.
#
# ## Lo que estos tests protegen
#
# Lo peligroso de copiar no es que falle: es que copie **de más**. Un director
# que termina con trescientos sesenta alumnos repetidos en el mismo grado, o con
# las notas del año pasado colgando del año nuevo, pierde la confianza en el
# sistema y no la recupera.
class CopiarLaEstructuraTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    @nuevo = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Lo que copia
  # ══════════════════════════════════════════════════════════════════════════

  test "trae las secciones con su cupo, su aula y su profesor guía" do
    con_el_colegio(@a.colegio) do
      @a.seccion.update!(capacity: 27, classroom: "Aula 3",
                         leader_teacher: @a.registro_de_profesor)

      CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      copiada = Section.find_by(academic_period_id: @nuevo.id, grade_id: @a.grado.id)
      assert copiada, "no se creó la sección en el año nuevo"
      assert_equal @a.seccion.name, copiada.name
      assert_equal 27, copiada.capacity
      assert_equal "Aula 3", copiada.classroom
      assert_equal @a.registro_de_profesor.id, copiada.leader_teacher_id
    end
  end

  test "trae quién dicta cada materia" do
    con_el_colegio(@a.colegio) do
      resultado = CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      assert_equal 1, resultado.asignaciones
      copiada = Section.find_by(academic_period_id: @nuevo.id)
      asignacion = TeacherSection.find_by(section_id: copiada.id)
      assert_equal @a.registro_de_profesor.id, asignacion.teacher_id
      assert_equal @a.materia.id, asignacion.subject_id
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # ⚠️ Lo que NO copia — la mitad que importa
  # ══════════════════════════════════════════════════════════════════════════

  test "NO copia los alumnos: promover depende de si aprobaron" do
    con_el_colegio(@a.colegio) do
      antes = Enrollment.count

      CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      assert_equal antes, Enrollment.count,
                   "copiar la estructura arrastró la matrícula: 360 alumnos repetidos de grado"
      assert_equal 0, Enrollment.where(section: Section.where(academic_period_id: @nuevo.id)).count
    end
  end

  test "NO copia notas, asistencia ni boletines" do
    con_el_colegio(@a.colegio) do
      antes = [ MomentGrade.count, ActivityGrade.count, Attendance.count,
                ReportCard.count, EvaluationActivity.count ]

      CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      despues = [ MomentGrade.count, ActivityGrade.count, Attendance.count,
                  ReportCard.count, EvaluationActivity.count ]
      assert_equal antes, despues, "se copió historia del año anterior al año nuevo"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Repetir la operación
  # ══════════════════════════════════════════════════════════════════════════

  test "copiar dos veces no duplica nada" do
    con_el_colegio(@a.colegio) do
      primera = CopiarLaEstructura.de(@a.periodo, al: @nuevo)
      assert_equal 1, primera.secciones.size

      segunda = CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      assert_empty segunda.secciones, "creó la sección otra vez"
      assert_equal 1, segunda.ya_estaban.size
      assert_equal 0, segunda.asignaciones, "duplicó la asignación de profesor"
      assert_equal 1, Section.where(academic_period_id: @nuevo.id).count
    end
  end

  # Un colegio que ya armó dos secciones a mano y quiere el resto: las suyas se
  # respetan y solo se completa lo que falta.
  test "respeta las secciones que el colegio ya armó a mano" do
    con_el_colegio(@a.colegio) do
      mia = Section.create!(grade: @a.grado, academic_period: @nuevo,
                            name: @a.seccion.name, capacity: 99, classroom: "La mía")

      CopiarLaEstructura.de(@a.periodo, al: @nuevo)

      mia.reload
      assert_equal 99, mia.capacity, "pisó el cupo que el colegio había puesto"
      assert_equal "La mía", mia.classroom
      # Pero SÍ le completa las asignaciones que le faltaban.
      assert_equal 1, TeacherSection.where(section_id: mia.id).count
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Los bordes
  # ══════════════════════════════════════════════════════════════════════════

  test "no copia de un año de OTRO colegio" do
    con_el_colegio(@a.colegio) do
      # El aislamiento hace que el año ajeno ni se encuentre; el servicio lo
      # comprueba igual, porque se puede llamar desde una consola o una tarea.
      resultado = Current.sin_aislamiento do
        CopiarLaEstructura.de(@b.periodo, al: @nuevo)
      end

      assert_empty resultado.secciones,
                   "copió la estructura de otro colegio: eso es una fuga entre inquilinos"
    end
  end

  test "no copia un año sobre sí mismo" do
    con_el_colegio(@a.colegio) do
      antes = Section.count
      resultado = CopiarLaEstructura.de(@a.periodo, al: @a.periodo)

      assert_empty resultado.secciones
      assert_equal antes, Section.count
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Por HTTP, que es como lo usa un director
  # ══════════════════════════════════════════════════════════════════════════

  test "la pantalla dice cuánto va a traer ANTES de confirmar" do
    sign_in @a.director

    get copiar_al_academic_period_path(@nuevo)

    assert_response :success
    assert_select ".empty-state h3", text: /Se van a traer/
    # Y dice qué NO se copia: «copiar el año» suena a copiar todo, y lo que un
    # director teme es terminar con la matrícula repetida.
    assert_match(/Los alumnos no/, response.body)
  end

  test "el director copia y el aviso dice con números qué pasó" do
    sign_in @a.director

    post hacer_copia_al_academic_period_path(@nuevo), params: { origen_id: @a.periodo.id }

    # ⚠️ Al paso SIGUIENTE, no al listado de secciones (MOR-169): copiar deja el
    # año nuevo armado y VACÍO, y lo que falta es llenarlo. Mandarlo a las
    # secciones lo dejaba teniendo que buscar dónde continuar.
    assert_redirected_to promover_al_academic_period_path(@nuevo)
    assert_match(/Copiado de #{@a.periodo.name}/, flash[:notice])
    assert_match(/1 sección nueva/, flash[:notice])
    assert_match(/1 asignación de profesor/, flash[:notice])
  end

  test "queda en la auditoría como una copia, no como una edición del año" do
    sign_in @a.director

    assert_difference "ActivityLog.unscoped.count", 1 do
      post hacer_copia_al_academic_period_path(@nuevo), params: { origen_id: @a.periodo.id }
    end

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_equal "estructura_copiada", registro.action
    assert_equal "Estructura del año escolar copiada", registro.label
    assert_match(/copió a 2026-2027 la estructura de #{@a.periodo.name}/, registro.message)
  end

  # El id del origen viene del request: tiene que estar acotado a los años del
  # propio colegio, y lo hace el `default_scope`, no un `if`.
  test "un origen de otro colegio, mandado por HTTP, no copia nada" do
    sign_in @a.director

    post hacer_copia_al_academic_period_path(@nuevo), params: { origen_id: @b.periodo.id }

    assert_equal 0, Current.sin_aislamiento { Section.unscoped.where(academic_period_id: @nuevo.id).count }
  end

  # ⚠️ Un BOTÓN, no un enlace de texto. Daniel: «el botón de clonar debemos
  # resaltarlo más, hacerlo más evidente; de casualidad lo vi». Es la acción que
  # ahorra ochenta asignaciones escritas a mano y estaba pintada como el resto
  # del texto de la tabla.
  test "el atajo aparece como botón, y solo para los años sin secciones" do
    sign_in @a.director

    get academic_periods_path

    # `btn-accion` y no `btn-primary`: es el tono de lo que hace mucho de una vez
    # (MOR-172). Copiar crea diez secciones y ochenta asignaciones; guardar
    # actualiza una fila. Que fueran el mismo azul era el problema.
    assert_select "a.btn.btn-accion[href=?]", copiar_al_academic_period_path(@nuevo)
    assert_select "a[href=?]", copiar_al_academic_period_path(@a.periodo), count: 0,
                  message: "el año que ya tiene secciones no necesita el atajo"
  end

  # Del más RECIENTE al más viejo: el año que se está armando es el que se viene
  # a tocar, y sin orden quedaba al final de la lista.
  test "los años escolares se listan del más nuevo al más viejo" do
    sign_in @a.director

    get academic_periods_path

    nombres = css_select("tbody tr td:first-child").map { |td| td.text.strip }
    assert_equal nombres.sort.reverse, nombres, "el más reciente va primero"
  end

  # El atajo a los años escolares, en la barra. Daniel: «sigue sin convencerme
  # el orden del sidebar... es lo primero que se hace».
  test "desde la barra de arriba se llega a los años escolares" do
    sign_in @a.director

    get dashboards_administrador_url

    assert_select ".contexto-anio-gestionar[href=?]", academic_periods_path
  end

  test "pero un profesor no ve ese atajo" do
    sign_in @a.profesor

    get dashboards_profesor_url

    assert_select ".contexto-anio-gestionar", count: 0
  end
end
