require "test_helper"

# La planilla de reparación: la segunda oportunidad del Art. 112 (MOR-168).
#
# ## El hueco que esto tapa
#
# `remedial_exam_score` se LEÍA en el boletín, en la certificación 31059, en el
# panel del alumno y en el cálculo de la definitiva — y solo se ESCRIBÍA desde
# el importador de historial. O sea: el Art. 112 estaba implementado de la mitad
# para adelante, y un colegio que usa SIGA en el año en curso no tenía dónde
# cargar una reparación.
#
# Lo encontró Daniel buscándola: «por ningún lado vi dónde el profesor coloca la
# reparación». No la vio porque no existía.
class ReparacionesTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos

    # Un aplazado de verdad: la actividad de `colegio_completo` vale 100 % del
    # lapso, así que la nota de la actividad ES la del lapso y la del año.
    @aplazado = con_el_colegio(@a.colegio) do
      alumno = @a.escenario.seccion.enrollments.map(&:student).find { |s| s.id != @a.alumno.id } || @a.alumno
      ActivityGrade.find_or_initialize_by(evaluation_activity: @a.actividad, student_id: alumno.id)
                   .tap { |n| n.update!(score: 7) }
      alumno
    end

    @libro = con_el_colegio(@a.colegio) do
      FinalGradeBook.find_by(enrollment_id: Enrollment.find_by(student_id: @aplazado.id).id,
                             subject_id: @a.materia.id)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Que exista, y que el profesor llegue
  # ══════════════════════════════════════════════════════════════════════════

  test "el profesor ve dónde le quedaron aplazados" do
    sign_in @a.profesor

    get reparaciones_path

    assert_response :success
    assert_select "td", text: "#{@a.grado.name} #{@a.seccion.name}"
    assert_select "td", text: @a.materia.name
  end

  test "y entra a la planilla de esa sección y materia" do
    sign_in @a.profesor

    get reparacion_path(@a.seccion, @a.materia)

    assert_response :success
    assert_match(/#{Regexp.escape(@aplazado.user.apellidos_y_nombres)}/, response.body)
  end

  # ⚠️ SOLO los aplazados. Listar la sección entera pondría un campo editable al
  # lado de una nota que ya está bien, que es como se le baja una nota a alguien
  # por accidente.
  test "en la planilla solo aparecen los aplazados" do
    sign_in @a.profesor

    get reparacion_path(@a.seccion, @a.materia)

    assert_select "li.carga-fila", 1,
                  "debería aparecer solo el alumno que cerró el año por debajo de 10"
    aprobado = con_el_colegio(@a.colegio) { @a.alumno.user.apellidos_y_nombres }
    assert_no_match(/#{Regexp.escape(aprobado)}/, response.body,
                    "un alumno aprobado no repara nada y no debe estar en la planilla")
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El Artículo 112
  # ══════════════════════════════════════════════════════════════════════════

  test "la reparación aprobada pasa a ser la definitiva" do
    sign_in @a.profesor
    assert_equal 7, recargar(@libro).final_score.to_i

    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "14" }

    assert_response :success
    assert_equal 14, response.parsed_body["definitiva"]
    assert response.parsed_body["aprobado"]

    @libro = recargar(@libro)
    assert_equal 14, @libro.remedial_exam_score.to_i
    assert_equal 14, @libro.final_score.to_i, "la nota de la segunda oportunidad es la definitiva"
  end

  # ⚠️ `max`, no «la última gana». Una reparación PEOR que el anual no puede
  # bajar una nota ya obtenida.
  test "una reparación más baja que el anual no baja la nota" do
    sign_in @a.profesor
    con_el_colegio(@a.colegio) { @libro.update!(annual_average: 9, final_score: 9) }

    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "4" }
    assert_equal 9, recargar(@libro).final_score.to_i
    assert_equal 4, recargar(@libro).remedial_exam_score.to_i, "la nota presentada se guarda igual"
  end

  # Vacío BORRA la reparación: «sin reparación» no es una reparación mala.
  test "vaciar el campo quita la reparación y devuelve la definitiva al anual" do
    sign_in @a.profesor
    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "14" }

    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "" }

    @libro = recargar(@libro)
    assert_nil @libro.remedial_exam_score
    assert_equal 7, @libro.final_score.to_i
  end

  # ⚠️ Un libro IMPORTADO no pasa por `GradeCalculator` —`return libro if
  # importada?`— así que si la regla del 112 viviera solo ahí, su definitiva no
  # se habría actualizado nunca. Es el caso normal de un colegio que trae su
  # historial y después repara.
  test "también funciona sobre una nota importada" do
    sign_in @a.profesor
    con_el_colegio(@a.colegio) do
      @libro.update!(origen: :importada, annual_average: 8, final_score: 8)
    end

    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "15" }

    @libro = recargar(@libro)
    assert_equal 15, @libro.final_score.to_i,
                 "una nota importada también tiene derecho a su segunda oportunidad"
    assert @libro.importada?, "y sigue siendo importada: nadie la recalculó"
  end

  test "no acepta una nota fuera de la escala del 1 al 20" do
    sign_in @a.profesor

    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "25" }

    assert_response :unprocessable_entity
    assert_nil recargar(@libro).remedial_exam_score
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Quién puede
  # ══════════════════════════════════════════════════════════════════════════

  test "un profesor no puede reparar una materia que no dicta" do
    otra = con_el_colegio(@a.colegio) do
      Subject.create!(department: @a.departamento, code: "OTR", name: "Otra materia")
    end

    sign_in @a.profesor
    get reparacion_path(@a.seccion, otra)

    assert_redirected_to reparaciones_path
  end

  test "un alumno no entra" do
    sign_in @a.estudiante

    get reparaciones_path

    assert_response :redirect
  end

  # La sección de otro colegio no se encuentra: da 404, no 403. Lo hace el
  # `default_scope`, no un `if`.
  test "no se puede reparar en la sección de otro colegio" do
    sign_in @a.director

    get reparacion_path(@b.seccion, @b.materia)

    assert_response :not_found
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Queda en la auditoría
  # ══════════════════════════════════════════════════════════════════════════
  #
  # La pregunta que hay que poder contestar es «¿quién le cambió la nota a mi
  # hijo?», y la hace una madre por UNA nota, meses después.

  test "cada reparación queda registrada, con lo que decía antes" do
    sign_in @a.profesor

    assert_difference "ActivityLog.unscoped.count", 1 do
      patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "14" }
    end

    registro = Current.sin_aislamiento { ActivityLog.unscoped.order(:id).last }
    assert_equal "reparacion_registrada", registro.action
    assert_equal "Reparación cargada", registro.label
    assert_match(/le puso 14 de reparación/, registro.message)
  end

  # Guardar el mismo valor no es un cambio: la planilla reenvía al salir del
  # campo, y un historial lleno de cambios que no ocurrieron ESCONDE los que sí.
  test "reenviar la misma nota no ensucia el historial" do
    sign_in @a.profesor
    patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "14" }

    assert_no_difference "ActivityLog.unscoped.count" do
      patch nota_de_reparacion_path(@a.seccion, @a.materia, @aplazado), params: { score: "14" }
    end
  end

  private

  # ⚠️ `reload` a secas falla: fuera del contexto de colegio el RLS devuelve cero
  # filas, así que la fila «desaparece». No es un dato perdido — es el
  # aislamiento haciendo lo que se le pidió.
  def recargar(libro)
    con_el_colegio(@a.colegio) { FinalGradeBook.find(libro.id) }
  end
end
