require "test_helper"

# Las clases del horario y las dos reglas que lo hacen imposible de chocar
# (spec `horarios`, tanda 2): una sección, una clase a la vez; un profesor, un
# sitio a la vez. En el modelo, con el texto de `ChoquesDeHorario`, y en la
# base, aunque se salte la validación.
class ClasesDelHorarioTest < ActiveSupport::TestCase
  FOTO = { entrada: "7:10", minutos_por_hora: 40, horas_al_dia: 8, receso_minutos: 30, receso_tras: 4 }.freeze

  setup do
    @esc = escenario_academico
    con_el_colegio(@esc.colegio) do
      @turno = BellSchedule.new(name: "Turno de la mañana", academic_period: @esc.periodo)
      @turno.time_slots.build(HorasDelTurno.new(**FOTO).filas.map(&:to_h))
      @turno.save!
      @horas = @turno.horas_de_clase

      @a = @esc.seccion
      @a.update!(bell_schedule: @turno)
      @b = Section.create!(grade: @esc.grado, academic_period: @esc.periodo, name: "B", capacity: 30, bell_schedule: @turno)

      @mat = @esc.materia
      @cas = materia("CAS", "Castellano y Literatura")
      @dib = materia("DIB", "Dibujo")

      @garcia = profesor("Carlos", "García")
      @lopez  = profesor("María", "López")
      asignar(@a, @mat, @garcia)
      asignar(@b, @mat, @garcia)
      asignar(@b, @cas, @lopez)
    end
  end

  def materia(codigo, nombre)
    Subject.create!(department: @esc.materia.department, code: codigo, name: nombre).tap do |m|
      GradeSubject.create!(grade: @esc.grado, subject: m)
    end
  end

  def profesor(nombre, apellido)
    usuario = User.create!(first_name: nombre, last_name: apellido, password: "123123",
                           email: "#{nombre.downcase}.#{@esc.colegio.id}@horario.test")
    Teacher.create!(user: usuario, school: @esc.colegio)
  end

  def asignar(seccion, materia, profesor) = TeacherSection.create!(section: seccion, subject: materia, teacher: profesor)

  # `hora` cuenta desde 1, como el colegio: la 1ra hora, la 2da…
  def clase(seccion, materia, dia:, hora:)
    Lesson.new(section: seccion, subject: materia, day: dia, time_slot: @horas[hora - 1])
  end

  def ubicar(...)
    con_el_colegio(@esc.colegio) { clase(...).tap(&:save!) }
  end

  def nombre(seccion) = "#{@esc.grado.name} #{seccion.name}"

  # Un `EXCLUDE` violado aborta la transacción: sin su SAVEPOINT, el error
  # aparecería en lo siguiente que el test le pida a la base.
  #
  # ⚠️ `valid?` primero, aunque falle: `save!(validate: false)` se salta también
  # los `before_validation`, y sin ellos la clase no tiene colegio ni minutos.
  # Lo rechazaría el RLS antes que el `EXCLUDE`, y el test probaría otra cosa.
  def guardar_sin_validar(clase)
    con_el_colegio(@esc.colegio) do
      clase.valid?
      Lesson.transaction(requires_new: true) { clase.save!(validate: false) }
    end
  end

  # ── Las dos reglas ─────────────────────────────────────────────────────────

  test "una sección no tiene dos clases a la misma hora, y el modelo dice cuál tiene" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    con_el_colegio(@esc.colegio) do
      otra = clase(@a, @dib, dia: 1, hora: 1)
      refute otra.valid?
      assert_includes otra.errors.full_messages,
                      "Lunes a las 7:10 no se puede: #{nombre(@a)} ya tiene Matemática a esa hora."
    end
  end

  test "un profesor no está en dos secciones a la misma hora, y el modelo dice dónde está" do
    ubicar(@a, @mat, dia: 3, hora: 3)

    con_el_colegio(@esc.colegio) do
      otra = clase(@b, @mat, dia: 3, hora: 3)
      refute otra.valid?
      assert_includes otra.errors.full_messages,
                      "Miércoles a las 8:30 no se puede: García está en #{nombre(@a)} dando Matemática."
    end
  end

  test "la base rechaza las dos aunque se salte la validación" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    assert_raises(ActiveRecord::ExclusionViolation) { guardar_sin_validar(clase(@a, @dib, dia: 1, hora: 1)) }
    assert_raises(ActiveRecord::ExclusionViolation) { guardar_sin_validar(clase(@b, @mat, dia: 1, hora: 1)) }
    con_el_colegio(@esc.colegio) { assert_equal 1, Lesson.count }
  end

  test "dos horas contiguas no chocan: el bloque de 80 minutos son dos clases seguidas" do
    ubicar(@a, @mat, dia: 2, hora: 1)
    ubicar(@a, @mat, dia: 2, hora: 2)

    con_el_colegio(@esc.colegio) { assert_equal [ 430, 470 ], Lesson.order(:starts_min).pluck(:starts_min) }
  end

  # La 3ra hora de un turno y la 2da de otro pueden pisarse: comparar el número
  # de hora dejaría pasar el choque. Es donde tropiezan aSc y Untis.
  test "el choque se mide por reloj, también entre turnos distintos" do
    ubicar(@a, @mat, dia: 4, hora: 3) # 8:30 – 9:10

    con_el_colegio(@esc.colegio) do
      tarde = BellSchedule.create!(name: "Otro turno", academic_period: @esc.periodo)
      hora = tarde.time_slots.create!(desde: "8:45", hasta: "9:30")
      @b.update!(bell_schedule: tarde)

      otra = Lesson.new(section: @b, subject: @mat, day: 4, time_slot: hora)
      refute otra.valid? # y de paso le llena el colegio y los minutos
      assert_match "García está en #{nombre(@a)}", otra.errors.full_messages.to_sentence
      assert_raises(ActiveRecord::ExclusionViolation) do
        Lesson.transaction(requires_new: true) { otra.save!(validate: false) }
      end
    end
  end

  test "un área sin profesor no choca con nadie" do
    ubicar(@a, @dib, dia: 5, hora: 1)
    ubicar(@b, @dib, dia: 5, hora: 1)

    con_el_colegio(@esc.colegio) { assert_equal [ nil, nil ], Lesson.where(subject: @dib).pluck(:teacher_id) }
  end

  test "el receso no es para clases" do
    con_el_colegio(@esc.colegio) do
      receso = @turno.time_slots.receso.first
      otra = Lesson.new(section: @a, subject: @mat, day: 1, time_slot: receso)
      refute otra.valid?
      assert_includes otra.errors.full_messages, "La hora es el receso"
    end
  end

  # ── Lo que la base copia sola ──────────────────────────────────────────────

  test "corregir una hora mueve los minutos de sus clases" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    con_el_colegio(@esc.colegio) do
      @horas.first.update!(desde: "7:05", hasta: "7:50")
      assert_equal [ 425, 470 ], Lesson.pick(:starts_min, :ends_min)
    end
  end

  test "una hora con clases no se borra" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    con_el_colegio(@esc.colegio) do
      refute @horas.first.destroy
      assert_equal 1, Lesson.count
    end
  end

  test "borrar la sección se lleva sus clases" do
    ubicar(@b, @cas, dia: 2, hora: 5)

    con_el_colegio(@esc.colegio) do
      @b.destroy!
      assert_equal 0, Lesson.count
    end
  end

  # ⚠️ `delete_all` no corre callbacks: lo hace `prueba.rake`. La llave
  # compuesta, en cambio, no se la salta nadie.
  test "borrar la asignación deja sus clases «sin profesor», también con delete_all" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    con_el_colegio(@esc.colegio) do
      TeacherSection.where(section: @a, subject: @mat).delete_all
      assert_nil Lesson.pick(:teacher_id)
    end
  end

  # Sus clases cuelgan de las horas de ESTE turno (decisión 16).
  test "una sección con clases no cambia de turno; vacía, sí" do
    ubicar(@a, @mat, dia: 1, hora: 1)

    con_el_colegio(@esc.colegio) do
      otro = BellSchedule.create!(name: "Otro turno", academic_period: @esc.periodo)
      refute @a.update(bell_schedule: otro)
      assert_includes @a.errors.full_messages.to_sentence, "no se cambia con clases en el horario"

      Lesson.where(section: @a).delete_all
      assert @a.reload.update(bell_schedule: otro)
    end
  end

  # ── Cuando cambia el profesor (decisión 8) ─────────────────────────────────

  test "el profesor nuevo toma las clases donde está libre; donde choca, vuelven a «por ubicar»" do
    ubicar(@a, @mat, dia: 1, hora: 1)
    ubicar(@a, @mat, dia: 2, hora: 1)
    ubicar(@b, @cas, dia: 1, hora: 1) # López ya dicta el lunes a las 7:10

    con_el_colegio(@esc.colegio) do
      TeacherSection.find_by(section: @a, subject: @mat).destroy!
      nueva = asignar(@a, @mat, @lopez)

      assert nueva.persisted?, "la asignación se guarda siempre"
      assert_equal [ [ 2, @lopez.id ] ], Lesson.where(section: @a, subject: @mat).pluck(:day, :teacher_id)
      assert_equal [ "lunes 7:10 — López está en #{nombre(@b)} dando Castellano y Literatura" ],
                   nueva.clases_desubicadas
    end
  end
end
