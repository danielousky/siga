require "test_helper"

# La ficha del alumno COMO LA VE SU PROFESOR (etapa ③).
#
# La pestaña «Alumnos» era una tabla muerta: nombres que no llevaban a ningún
# lado. El dato que más le hace falta al docente —el teléfono de la mamá del
# niño que faltó tres días— vivía solo en la ficha de la DIRECCIÓN, así que
# había que pedirlo por la oficina.
#
#     ╭────╮ Aponte García, Valentina       [← Volver a los alumnos]
#     │ AV │ 1er Nivel – U · 2025-2026
#     ╰────╯
#     A QUIÉN LLAMAR · CÓMO VA · ASISTENCIA · DATOS
#
# ⚠️ Y NO es `students/show`, que trae el boletín entero, los documentos
# oficiales y los enlaces para editar a la familia.
class FichaDelAlumnoDelProfeTest < ActionDispatch::IntegrationTest
  setup do
    @a, @b = dos_colegios_completos(nivel: :primaria)
    @inscripcion = @a.escenario.inscripcion
    sign_in @a.profesor
  end

  def ficha(seccion = @a.seccion, inscripcion = @inscripcion)
    get alumno_section_path(seccion, enrollment_id: inscripcion.id)
  end

  # ── Llegar ────────────────────────────────────────────────────────────────

  test "la lista de alumnos enlaza a la ficha de cada uno" do
    get alumnos_section_path(@a.seccion)

    assert_response :success
    assert_select "tbody a[href=?]", alumno_section_path(@a.seccion, enrollment_id: @inscripcion.id)
  end

  test "la ficha abre con lo que el profesor necesita" do
    ficha

    assert_response :success
    assert_select ".ficha-nombre", @inscripcion.student.user.apellidos_y_nombres
    # Los cuatro bloques, en orden: a quién llamar va PRIMERO.
    %w[A\ quién\ llamar Cómo\ va Asistencia Datos].each do |bloque|
      assert_select "h2", text: bloque
    end
  end

  # ── A quién llamar ────────────────────────────────────────────────────────

  test "muestra al representante con su teléfono, para llamarlo de un toque" do
    con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Carmen", last_name: "Pérez",
                             email: "carmen.#{@a.colegio.id}@familia.test",
                             document: "V-#{@a.colegio.id}66", document_type: :cedula_v)
      representante = Representative.create!(user: usuario, school: @a.colegio, phone: "0414-1234567")
      StudentRepresentative.create!(student: @inscripcion.student, representative: representante,
                                    parentesco: :madre, principal: true)
    end

    ficha

    assert_select ".ficha-responsable-nombre", /Carmen/
    assert_select "a[href='tel:0414-1234567']"
    # ⚠️ Y WhatsApp solo porque es un MÓVIL.
    assert_select "a[href*='wa.me']"
  end

  test "un fijo no ofrece WhatsApp" do
    con_el_colegio(@a.colegio) do
      usuario = User.create!(first_name: "Pedro", last_name: "Fijo",
                             email: "pedro.#{@a.colegio.id}@familia.test",
                             document: "V-#{@a.colegio.id}55", document_type: :cedula_v)
      representante = Representative.create!(user: usuario, school: @a.colegio, phone: "0212-1234567")
      StudentRepresentative.create!(student: @inscripcion.student, representative: representante,
                                    parentesco: :padre, principal: true)
    end

    ficha

    # Un enlace de WhatsApp hacia un 0212 abre la app con un chat hacia nadie.
    assert_select "a[href*='wa.me']", count: 0
  end

  # ── Cómo va ───────────────────────────────────────────────────────────────

  # ⚠️ El profesor que NO es guía ve solo lo suyo. El guía ve todo: es quien
  # responde por el niño ante la familia.
  test "sin ser guía, solo se ven las áreas que dicta" do
    otra = con_el_colegio(@a.colegio) do
      departamento = Department.create!(school: @a.colegio, name: "Letras")
      materia = Subject.create!(department: departamento, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @a.seccion.grade, subject: materia)
      materia
    end

    ficha

    assert_select ".ficha-area-nombre", text: @a.escenario.materia.name
    assert_select ".ficha-area-nombre", { text: otra.name, count: 0 },
                  # no la dicta, y no es guía de la sección
                  "un área ajena no es asunto suyo"
  end

  test "el guía ve todas las áreas del grado" do
    con_el_colegio(@a.colegio) do
      departamento = Department.create!(school: @a.colegio, name: "Letras")
      materia = Subject.create!(department: departamento, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @a.seccion.grade, subject: materia)
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
    end

    ficha

    assert_select ".ficha-area-nombre", text: "Castellano"
  end

  # ── Quién entra ───────────────────────────────────────────────────────────

  test "un profesor de otro colegio no llega" do
    sign_in @b.profesor

    ficha

    # 404 y no 403: el aislamiento por colegio hace que esa sección NO EXISTA
    # para quien mira (`MOR-86`). Decir «no autorizado» ya confirmaría que hay
    # una sección con ese número en otro colegio.
    assert_response :not_found
  end

  # ⚠️ Un alumno de OTRA sección no se abre desde esta: el permiso lo da la
  # sección, así que sin esta comprobación bastaría con cambiar el número de la
  # URL para leer la ficha de cualquier niño del colegio.
  test "una inscripción de otra sección no se abre desde acá" do
    ajena = con_el_colegio(@a.colegio) do
      otra = Section.create!(grade: @a.seccion.grade, academic_period: @a.seccion.academic_period,
                             name: "Z", capacity: 30)
      usuario = User.create!(first_name: "Ajeno", last_name: "Alumno",
                             cedula_escolar: "Z#{@a.colegio.id}0001")
      alumno = Student.create!(user: usuario, school: @a.colegio, school_card: "Z-#{@a.colegio.id}")
      Enrollment.create!(student: alumno, section: otra, enrollment_date: Date.new(2025, 9, 20))
    end

    ficha(@a.seccion, ajena)

    assert_redirected_to alumnos_section_path(@a.seccion)
  end
end
