require "test_helper"

# Los turnos, sus horas y la carga horaria oficial (spec `horarios`, tanda 1).
class TurnosTest < ActiveSupport::TestCase
  # El horario del cuaderno que mandó Daniel el 13 de octubre de 2026.
  FOTO = { entrada: "7:10", minutos_por_hora: 40, horas_al_dia: 8, receso_minutos: 30, receso_tras: 4 }.freeze

  setup do
    @esc = escenario_academico
  end

  def turno(nombre = "Media · mañana", anio: @esc.periodo, **cambios)
    con_el_colegio(@esc.colegio) do
      turno = BellSchedule.new(name: nombre, academic_period: anio)
      turno.time_slots.build(HorasDelTurno.new(**FOTO.merge(cambios)).filas.map(&:to_h))
      turno.save!
      turno
    end
  end

  # ── El timbre ──────────────────────────────────────────────────────────────

  test "cuatro números arman el timbre de la foto: de 7:10 a 1:00, con el receso a las 9:50" do
    filas = HorasDelTurno.new(**FOTO).filas

    assert_equal [ "7:10 – 7:50", "7:50 – 8:30", "8:30 – 9:10", "9:10 – 9:50", "9:50 – 10:20",
                   "10:20 – 11:00", "11:00 – 11:40", "11:40 – 12:20", "12:20 – 1:00" ],
                 filas.map { |fila| HoraDelDia.rango(fila.starts_min, fila.ends_min) }
    assert_equal %w[clase clase clase clase receso clase clase clase clase], filas.map(&:kind)
  end

  test "sin receso, las horas van seguidas" do
    filas = HorasDelTurno.new(**FOTO.merge(receso_tras: 0, horas_al_dia: 3)).filas

    assert_equal [ "7:10 – 7:50", "7:50 – 8:30", "8:30 – 9:10" ],
                 filas.map { |fila| HoraDelDia.rango(fila.starts_min, fila.ends_min) }
  end

  test "lo que no tiene sentido no arma nada, y dice qué escribir" do
    timbre = HorasDelTurno.new(entrada: "25:00", minutos_por_hora: 5, horas_al_dia: 0, receso_tras: 3)

    assert_empty timbre.filas
    mensajes = timbre.errors.full_messages
    assert_includes mensajes, "La hora de entrada no se entiende: escríbala como 7:10."
    assert_includes mensajes, "Un turno tiene entre 1 y 14 horas al día."
    assert_includes mensajes, "Cada hora dura entre 20 y 120 minutos."
  end

  # Después de la última hora ya no es un receso: es la salida.
  test "el receso va entre dos horas de clase" do
    timbre = HorasDelTurno.new(**FOTO.merge(horas_al_dia: 4, receso_tras: 4))

    refute timbre.valid?
    assert_includes timbre.errors.full_messages,
                    "El receso va entre dos horas de clase: después de la última ya es la salida."
  end

  test "un turno que terminaría después de la medianoche no se arma" do
    timbre = HorasDelTurno.new(**FOTO.merge(entrada: "22:00", minutos_por_hora: 60, horas_al_dia: 4, receso_tras: 2))

    refute timbre.valid?
    assert_includes timbre.errors.full_messages, "Con esas horas el turno terminaría después de la medianoche."
  end

  # ── La hora del día ────────────────────────────────────────────────────────

  test "la hora se guarda en minutos y se lee como la escribe un colegio" do
    assert_equal 430, HoraDelDia.a_minutos("7:10")
    assert_equal 430, HoraDelDia.a_minutos("07:10")
    assert_nil HoraDelDia.a_minutos("7.10")
    assert_nil HoraDelDia.a_minutos("24:00")

    assert_equal "7:10", HoraDelDia.texto(430)
    assert_equal "1:00", HoraDelDia.texto(780)
    assert_equal "12:20", HoraDelDia.texto(740)
    assert_equal "7:10 a. m.", HoraDelDia.con_meridiano(430)
    assert_equal "1:00 p. m.", HoraDelDia.con_meridiano(780)
    assert_equal "13:00", HoraDelDia.del_campo(780)
  end

  # ── Las horas de un turno ──────────────────────────────────────────────────

  test "las horas se nombran contando solo las de clase" do
    t = turno
    nombres = con_el_colegio(@esc.colegio) { t.reload.horas_con_nombre.map(&:last) }

    assert_equal [ "1ra hora", "2da hora", "3ra hora", "4ta hora", "Receso",
                   "5ta hora", "6ta hora", "7ma hora", "8va hora" ], nombres
  end

  test "en una semana caben ocho horas por cinco días" do
    t = turno

    assert_equal 40, con_el_colegio(@esc.colegio) { t.reload.horas_a_la_semana }
  end

  test "dos horas de un turno no se pisan, y el modelo dice con cuál" do
    t = turno

    con_el_colegio(@esc.colegio) do
      primera = t.time_slots.first
      primera.hasta = "08:00"

      refute primera.valid?
      assert_includes primera.errors.full_messages, "Se pisa con la 2da hora (7:50 – 8:30)"
    end
  end

  # ⚠️ La validación no ve lo que otra persona guarda al mismo tiempo. La base sí.
  test "aunque se salte la validación, la base no deja que dos horas se pisen" do
    t = turno

    con_el_colegio(@esc.colegio) do
      pisa = TimeSlot.new(bell_schedule: t, starts_min: 440, ends_min: 480)

      assert_raises(ActiveRecord::ExclusionViolation) do
        TimeSlot.transaction(requires_new: true) { pisa.save!(validate: false) }
      end
    end
  end

  test "dos turnos distintos sí pueden sonar a la misma hora" do
    turno("Media · mañana")
    otro = turno("Primaria", entrada: "7:00", minutos_por_hora: 45)

    assert_equal 9, con_el_colegio(@esc.colegio) { otro.time_slots.count }
  end

  test "un turno con secciones no se borra" do
    t = turno

    con_el_colegio(@esc.colegio) do
      @esc.seccion.update!(bell_schedule: t)

      refute t.destroy
      assert_includes t.errors.full_messages.to_sentence, "secciones"
    end
  end

  # ── La sección y su turno ──────────────────────────────────────────────────

  test "una sección no puede usar el turno de otro año" do
    viejo = ano_escolar_viejo(@esc, nombre: "2024-2025")
    del_otro_anio = turno("Media · mañana", anio: viejo)

    con_el_colegio(@esc.colegio) do
      @esc.seccion.bell_schedule = del_otro_anio

      refute @esc.seccion.valid?
      assert_includes @esc.seccion.errors.full_messages, "Turno es de otro año escolar"
    end
  end

  # ── La carga horaria oficial ───────────────────────────────────────────────

  test "reconoce las áreas por su nombre, como las llama cada colegio" do
    assert_equal 4, CargaHorariaOficial.horas_para("Castellano y Literatura", "1er Año")
    assert_equal 6, CargaHorariaOficial.horas_para("Educación Física y Deporte", "5TO AÑO")
    assert_equal 6, CargaHorariaOficial.horas_para("Grupo de Creación, Recreación y Producción", "3er Año")
    assert_equal 4, CargaHorariaOficial.horas_para("Lenguas Extranjeras", "5to Año")
    assert_equal 6, CargaHorariaOficial.horas_para("Geografía, Historia y Ciudadanía", "2do Año")
  end

  test "donde el plan no dice nada, no inventa" do
    assert_nil CargaHorariaOficial.horas_para("Física", "1er Año")
    assert_nil CargaHorariaOficial.horas_para("Computación", "1er Año")
    assert_nil CargaHorariaOficial.horas_para("Matemática", "4to Grado")
  end

  test "proponer llena solo lo vacío, no pisa lo escrito y dice qué quedó fuera del plan" do
    con_el_colegio(@esc.colegio) do
      castellano = Subject.create!(code: "LEN", name: "Castellano y Literatura")
      computacion = Subject.create!(code: "COM", name: "Computación")
      ingles = Subject.create!(code: "ING", name: "Inglés")
      GradeSubject.create!(grade: @esc.grado, subject: castellano)
      GradeSubject.create!(grade: @esc.grado, subject: computacion)
      # El colegio ya decidió que Inglés lleva cuatro, no las seis del plan.
      GradeSubject.create!(grade: @esc.grado, subject: ingles, weekly_hours: 4)

      resultado = CargaHorariaOficial.proponer!

      assert_equal 2, resultado.propuestas
      assert_equal [ computacion.name ], resultado.fuera_del_plan
      assert_equal 4, GradeSubject.find_by(subject: castellano).weekly_hours
      assert_equal 4, GradeSubject.find_by(subject: @esc.materia).weekly_hours
      assert_equal 4, GradeSubject.find_by(subject: ingles).weekly_hours
    end
  end

  test "la carga horaria va de 1 a 60, o vacía" do
    con_el_colegio(@esc.colegio) do
      renglon = GradeSubject.find_by(subject: @esc.materia)

      renglon.weekly_hours = "4.5"
      refute renglon.valid?

      renglon.weekly_hours = 61
      refute renglon.valid?

      renglon.weekly_hours = nil
      assert renglon.valid?
    end
  end
end
