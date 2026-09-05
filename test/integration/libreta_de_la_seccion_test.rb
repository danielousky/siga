require "test_helper"

# La libreta: todas las notas de una sección en una tabla (MOR-223).
#
# Daniel: *«debería tener una vista en la que aparezcan todas las evaluaciones y
# él pueda ir ajustando durante el lapso… una tabla donde la primera columna es
# la lista de los estudiantes y las siguientes columnas son las evaluaciones»*.
#
# Y la razón: *«ten presente que lo más importante para los profesores son sus
# estudiantes»*.
class LibretaDeLaSeccionTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(nivel: :primaria, alumnos: 3)
    @lapso = @esc.lapso(1)
    @profesor = con_el_colegio(@esc.colegio) do
      usuario = User.create!(first_name: "Carlos", last_name: "García",
                             email: "carlos.libreta@test.edu", password: "123123",
                             document: "V-88000111", document_type: :cedula_v)
      docente = Teacher.create!(user: usuario, school: @esc.colegio)
      TeacherSection.create!(teacher: docente, section: @esc.seccion, subject: @esc.materia)
      usuario
    end
  end

  test "el profesor ve a sus alumnos con una columna por evaluación" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @lapso, peso: 60, descripcion: "Examen")
      taller = actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Taller")
      alumnos = Enrollment.where(section: @esc.seccion).order(:id).map(&:student)
      nota(examen, alumnos[0], 18)
      nota(taller, alumnos[0], 16)
      nota(examen, alumnos[1], 9)
    end

    sign_in @profesor
    get section_path(@esc.seccion)

    assert_response :success
    assert_select ".libreta-columna-nombre", text: "Examen"
    assert_select ".libreta-columna-nombre", text: "Taller"
    assert_select ".libreta tbody tr", 3
  end

  # ⚠️ El avance en TRES estados, que es lo que Daniel pidió ver de un vistazo:
  # *«si ya las tengo calificadas me aparece 20 de 20 y un check en verde; si me
  # falta me aparece 20 de 30 y en amarillo; si no tengo nada, en rojo»*.
  test "cada columna dice cuántas notas le faltan, y en qué estado está" do
    con_el_colegio(@esc.colegio) do
      completa = actividad(@esc, lapso: @lapso, peso: 40, descripcion: "Completa")
      media    = actividad(@esc, lapso: @lapso, peso: 30, descripcion: "A medias")
      actividad(@esc, lapso: @lapso, peso: 30, descripcion: "Vacía")

      alumnos = Enrollment.where(section: @esc.seccion).order(:id).map(&:student)
      alumnos.each { |a| nota(completa, a, 15) }
      nota(media, alumnos.first, 12)
    end

    sign_in @profesor
    get section_path(@esc.seccion)

    assert_select ".libreta-avance--completa", text: "3 de 3"
    assert_select ".libreta-avance--a_medias", text: "1 de 3"
    assert_select ".libreta-avance--vacia",    text: "0 de 3"
  end

  # ⚠️ Una raya, NUNCA un cero. Sin nota no es reprobado: es que todavía no se
  # corrigió, y confundirlos reprueba a media sección a mitad de lapso.
  test "sin nota se escribe una raya, no un cero" do
    con_el_colegio(@esc.colegio) { actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Sin corregir") }

    sign_in @profesor
    get section_path(@esc.seccion)

    assert_select ".libreta-sin-nota", minimum: 3
    assert_select ".libreta-nota", text: "0", count: 0
  end

  # ⚠️ Solo las áreas que ESTA persona califica. Daniel, ratificándolo con
  # Cyndi: *«califica el profe de la materia. Incluso el guía… guía + áreas
  # asignadas»*.
  test "el profesor ve solo las áreas que dicta, aunque sea el guía" do
    otra = con_el_colegio(@esc.colegio) do
      s = Subject.create!(department: @esc.materia.department, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @esc.grado, subject: s)
      # La dicta OTRO profesor, y el nuestro es el guía de la sección.
      usuario = User.create!(first_name: "Otra", last_name: "Docente",
                             email: "otra.libreta@test.edu", password: "123123",
                             document: "V-88000222", document_type: :cedula_v)
      TeacherSection.create!(teacher: Teacher.create!(user: usuario, school: @esc.colegio),
                             section: @esc.seccion, subject: s)
      @esc.seccion.update!(leader_teacher: Teacher.find_by(user: @profesor))
      actividad(@esc, lapso: @lapso, peso: 100, descripcion: "De Matemática")
      s
    end

    sign_in @profesor
    get section_path(@esc.seccion)

    # El guía califica lo que DICTA, no todo lo de su sección.
    assert_select ".pastilla", text: otra.name, count: 0
  end

  # La dirección no califica: supervisa. Ve todas las áreas.
  test "la dirección ve todas las áreas de la sección" do
    director = con_el_colegio(@esc.colegio) do
      s = Subject.create!(department: @esc.materia.department, code: "LEN", name: "Castellano")
      GradeSubject.create!(grade: @esc.grado, subject: s)
      actividad(@esc, lapso: @lapso, peso: 100, descripcion: "De Matemática")

      usuario = User.create!(first_name: "Dir", last_name: "Libreta",
                             email: "dir.libreta@test.edu", password: "123123",
                             document: "V-88000333", document_type: :cedula_v)
      Admin.create!(user: usuario, school: @esc.colegio, role: :director)
      usuario
    end

    sign_in director
    get section_path(@esc.seccion)

    assert_select ".pastilla", text: "Castellano"
    assert_select ".pastilla", text: @esc.materia.name
  end

  # ⚠️ Un alumno RETIRADO no se califica, y contarlo dejaría la evaluación en
  # «29 de 30» para siempre.
  test "un alumno retirado no cuenta en el avance" do
    con_el_colegio(@esc.colegio) do
      examen = actividad(@esc, lapso: @lapso, peso: 100, descripcion: "Examen")
      inscripciones = Enrollment.where(section: @esc.seccion).order(:id).to_a
      inscripciones.last.update!(status: :retirado)
      inscripciones.first(2).each { |i| nota(examen, i.student, 15) }
    end

    sign_in @profesor
    get section_path(@esc.seccion)

    assert_select ".libreta-avance--completa", text: "2 de 2"
    assert_select ".libreta tbody tr", 2
  end
end
