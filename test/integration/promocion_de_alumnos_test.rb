require "test_helper"

# Promover a los alumnos al año siguiente (MOR-169).
#
# Es la otra mitad de septiembre: `CopiarLaEstructura` arma el año nuevo y esto
# lo llena. Daniel: «debería ser una función muy ligada a la clonación, es casi
# automática».
#
# ## Lo que estos tests protegen
#
# Lo peligroso de promover no es fallar: es **acertar a medias**. Un alumno en el
# grado equivocado se descubre en octubre, cuando ya tiene notas cargadas ahí, y
# no se deshace con un botón. Por eso todo se propone y nada se escribe sin que
# alguien confirme.
class PromocionDeAlumnosTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    # El colegio dicta el bachillerato entero, para poder probar el egreso.
    con_el_colegio(@a.colegio) do
      SembrarGrados.para(@a.colegio, niveles: [ :secundaria ])
    end

    @nuevo = con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Cómo decide
  # ══════════════════════════════════════════════════════════════════════════

  test "quien aprobó todo pasa al grado siguiente" do
    copiar_y_sembrar_secciones

    filas = con_el_colegio(@a.colegio) do
      PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo)
    end

    fila = filas.find { |f| f.alumno.id == @a.alumno.id }
    assert_equal :promueve, fila.situacion
    assert_equal "2do Año", fila.grado_destino.name, "de 1er Año se pasa a 2do Año"
    assert_equal @a.seccion.name, fila.destino.name, "va a la sección de la misma letra"
  end

  # ⚠️ El tope lo pone el COLEGIO (Daniel: «2 y configurable»). Con dos
  # aplazadas y tope 2, pasa; con tope 1, repite. La misma nota, dos resultados.
  test "el tope de arrastre lo decide el colegio" do
    copiar_y_sembrar_secciones
    aplazar_en(@a.alumno, cuantas: 2)

    con_el_colegio(@a.colegio) do
      @a.colegio.update!(tope_de_arrastre: 2)
      fila = PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo).find { |f| f.alumno.id == @a.alumno.id }
      assert_equal :promueve, fila.situacion, "con tope 2 y dos aplazadas, pasa arrastrando"
      assert_equal 2, fila.aplazadas.size

      @a.colegio.update!(tope_de_arrastre: 1)
      fila = PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo).find { |f| f.alumno.id == @a.alumno.id }
      assert_equal :repite, fila.situacion, "con tope 1 y dos aplazadas, repite"
      assert_equal @a.grado.name, fila.grado_destino.name, "repetir es quedarse en el MISMO grado"
    end
  end

  # ⚠️ Egresar no se configura: sale de que el grado siguiente no está entre los
  # del colegio. Un colegio de solo primaria egresa en 6to Grado sin que nadie
  # toque nada.
  test "quien está en el último grado que dicta el colegio, egresa" do
    ultimo = con_el_colegio(@a.colegio) do
      Grade.en_orden.last.tap do |grado|
        seccion = Section.create!(grade: grado, academic_period: @a.periodo, name: "A", capacity: 30)
        inscripcion = Enrollment.create!(student: @a.alumno, section: seccion,
                                         enrollment_date: Date.new(2025, 9, 20), status: :regular)
        # ⚠️ CON nota aprobada: sin notas la situación es `sin_datos`, y eso es
        # correcto —no se sabe si aprobó—. Lo que se prueba acá es el egreso.
        FinalGradeBook.create!(enrollment: inscripcion, subject: @a.materia,
                               annual_average: 18, final_score: 18)
      end
    end

    filas = con_el_colegio(@a.colegio) { PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo) }
    fila = filas.find { |f| f.seccion_actual.grade_id == ultimo.id }

    assert_equal :egresa, fila.situacion
    assert_nil fila.destino, "un egresado no se inscribe en ningún lado"
  end

  # ⚠️ El caso NORMAL de un cliente nuevo, y el que define el diseño: las notas
  # del año anterior están en el sistema viejo o en papel.
  test "sin notas cargadas nadie se mueve, y lo dice" do
    copiar_y_sembrar_secciones
    con_el_colegio(@a.colegio) { FinalGradeBook.del_anio_de_la_sesion.delete_all }

    con_el_colegio(@a.colegio) do
      Current.academic_period = @a.periodo
      assert_not PromocionDeAlumnos.hay_notas?(@a.periodo)

      filas = PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo)
      assert filas.all? { |f| f.situacion == :sin_datos }
      assert filas.none?(&:se_inscribe?), "sin decisión del director no se inscribe a nadie"
    end
  end

  test "pero el director puede pasarlos a todos igual" do
    copiar_y_sembrar_secciones
    con_el_colegio(@a.colegio) do
      Current.academic_period = @a.periodo
      FinalGradeBook.del_anio_de_la_sesion.delete_all
    end

    filas = con_el_colegio(@a.colegio) do
      PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo, promover_sin_datos: true)
    end

    assert filas.all?(&:se_inscribe?), "con la decisión tomada, todos pasan al siguiente grado"
  end

  # Un alumno retirado se fue del colegio. Volver a inscribirlo lo resucita en
  # una lista donde no debería estar.
  test "un alumno retirado no se promueve" do
    copiar_y_sembrar_secciones
    con_el_colegio(@a.colegio) { @a.inscripcion.update!(status: :retirado) }

    filas = con_el_colegio(@a.colegio) { PromocionDeAlumnos.propuesta_de(@a.periodo, al: @nuevo) }

    assert filas.none? { |f| f.alumno.id == @a.alumno.id }
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Cuando se aplica
  # ══════════════════════════════════════════════════════════════════════════

  test "inscribe de verdad en el año nuevo" do
    copiar_y_sembrar_secciones

    con_el_colegio(@a.colegio) do
      resultado = PromocionDeAlumnos.aplicar(@a.periodo, al: @nuevo)

      assert resultado.inscritos.positive?
      nuevas = Enrollment.where(section: Section.where(academic_period_id: @nuevo.id))
      assert_equal resultado.inscritos, nuevas.count
      assert nuevas.all?(&:regular?)
    end
  end

  test "promover dos veces no duplica inscripciones" do
    copiar_y_sembrar_secciones

    con_el_colegio(@a.colegio) do
      primera = PromocionDeAlumnos.aplicar(@a.periodo, al: @nuevo)
      cuantas = Enrollment.where(section: Section.where(academic_period_id: @nuevo.id)).count

      segunda = PromocionDeAlumnos.aplicar(@a.periodo, al: @nuevo)

      assert primera.inscritos.positive?
      assert_equal 0, segunda.inscritos, "la segunda corrida no inscribió a nadie más"
      assert_equal cuantas, Enrollment.where(section: Section.where(academic_period_id: @nuevo.id)).count,
                   "no quedó ninguna inscripción duplicada"
    end
  end

  # ⚠️ Lo que NO hace: la promoción inscribe, no copia historia.
  test "NO arrastra notas, asistencia ni boletines al año nuevo" do
    copiar_y_sembrar_secciones

    con_el_colegio(@a.colegio) do
      antes = [ MomentGrade.count, FinalGradeBook.count, Attendance.count, ReportCard.count ]
      PromocionDeAlumnos.aplicar(@a.periodo, al: @nuevo)

      assert_equal antes, [ MomentGrade.count, FinalGradeBook.count, Attendance.count, ReportCard.count ],
                   "promover arrastró historia del año anterior"
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Por HTTP, que es como lo usa un director
  # ══════════════════════════════════════════════════════════════════════════

  test "sin secciones en el año nuevo, la pantalla manda a copiar la estructura" do
    sign_in @a.director

    get promover_al_academic_period_path(@nuevo)

    assert_response :success
    assert_select ".empty-state h3", text: /todavía no tiene secciones/
    assert_select "a[href=?]", copiar_al_academic_period_path(@nuevo)
  end

  test "con la estructura copiada, muestra la cuenta antes de confirmar" do
    copiar_y_sembrar_secciones
    sign_in @a.director

    get promover_al_academic_period_path(@nuevo, origen_id: @a.periodo.id)

    assert_response :success
    assert_select ".promocion-resumen"
    assert_select "input[type=submit][value*=?]", "Promover"
  end

  test "el director promueve y el aviso dice con números qué pasó" do
    copiar_y_sembrar_secciones
    sign_in @a.director

    post hacer_promocion_al_academic_period_path(@nuevo), params: { origen_id: @a.periodo.id }

    assert_redirected_to enrollments_path
    assert_match(/Promovidos de #{@a.periodo.name} a #{@nuevo.name}/, flash[:notice])
    assert_match(/alumnos? inscritos?/, flash[:notice])
  end

  test "queda en la auditoría como UN hecho, no como trescientas inscripciones" do
    copiar_y_sembrar_secciones
    sign_in @a.director

    assert_difference "ActivityLog.unscoped.count", 1 do
      post hacer_promocion_al_academic_period_path(@nuevo), params: { origen_id: @a.periodo.id }
    end

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_equal "alumnos_promovidos", registro.action
    assert_equal "Alumnos promovidos de año", registro.label
    assert_match(/promovió de #{@a.periodo.name} a #{@nuevo.name}/, registro.message)
  end

  # El id del origen viene del request: acotado a los años del propio colegio
  # por el `default_scope`, no por un `if`.
  test "un origen de otro colegio no promueve a nadie" do
    copiar_y_sembrar_secciones
    sign_in @a.director

    post hacer_promocion_al_academic_period_path(@nuevo), params: { origen_id: @b.periodo.id }

    assert_equal 0, Current.sin_aislamiento {
      Enrollment.unscoped.where(section_id: Section.unscoped.where(academic_period_id: @nuevo.id).select(:id)).count
    }
  end

  test "un profesor no puede promover" do
    sign_in @a.profesor

    get promover_al_academic_period_path(@nuevo)

    assert_response :redirect
  end

  private

  # El año nuevo con su estructura: es la precondición real de promover.
  def copiar_y_sembrar_secciones
    con_el_colegio(@a.colegio) do
      CopiarLaEstructura.de(@a.periodo, al: @nuevo)
      # Y la sección del grado SIGUIENTE, que la copia no crea: en el año nuevo
      # los de 1er Año pasan a 2do, y ese grado no tenía sección el año pasado.
      siguiente = Grade.en_orden.find { |g| g.orden == @a.grado.orden + 1 }
      Section.create!(grade: siguiente, academic_period: @nuevo, name: @a.seccion.name, capacity: 30)
    end
  end

  # Aplaza al alumno en `cuantas` materias, creando los libros que hagan falta.
  def aplazar_en(alumno, cuantas:)
    con_el_colegio(@a.colegio) do
      inscripcion = Enrollment.find_by(student_id: alumno.id, section_id: @a.seccion.id)
      cuantas.times do |i|
        materia = Subject.create!(department: @a.departamento, code: "AP#{i}", name: "Aplazada #{i}")
        FinalGradeBook.create!(enrollment: inscripcion, subject: materia,
                               annual_average: 8, final_score: 8)
      end
    end
  end
end
