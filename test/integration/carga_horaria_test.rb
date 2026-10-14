require "test_helper"

# Académico ▸ Horarios ▸ Carga horaria (spec `horarios`, tanda 1).
class CargaHorariaTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    @esc = @a.escenario
    sign_in @a.director

    con_el_colegio(@esc.colegio) do
      @castellano = Subject.create!(code: "LEN", name: "Castellano y Literatura")
      @fisica = Subject.create!(code: "FIS", name: "Física")
      @segundo = Grade.create!(school: @esc.colegio, level: :secundaria, name: "3er Año")
      GradeSubject.create!(grade: @esc.grado, subject: @castellano)
      GradeSubject.create!(grade: @segundo, subject: @castellano)
      GradeSubject.create!(grade: @segundo, subject: @fisica)
    end
  end

  def renglon(grado, area) = con_el_colegio(@esc.colegio) { GradeSubject.find_by(grade: grado, subject: area) }

  # ⚠️ Escribir FUERA del colegio no falla: el RLS deja el `UPDATE` en cero filas,
  # en silencio, y el test sigue con el dato viejo creyendo que lo cambió.
  def escribir(grado, area, horas)
    con_el_colegio(@esc.colegio) { GradeSubject.find_by(grade: grado, subject: area).update_columns(weekly_hours: horas) }
  end

  test "una fila por área, una columna por grado, y el punto donde no se cursa" do
    get carga_horaria_path

    assert_response :success
    assert_select "table.carga-horaria thead th", text: "1er Año"
    assert_select "table.carga-horaria thead th", text: "3er Año"
    assert_select "input[name='horas[#{renglon(@esc.grado, @castellano).id}]']"
    # Física no se cursa en 1er Año: punto, no casilla.
    assert_select "span.carga-horaria-no-se-cursa[aria-label='Física no se cursa en 1er Año']"
  end

  test "guardar escribe las horas, y un campo vacío es «nadie lo dijo»" do
    escribir(@esc.grado, @castellano, 6)
    castellano = renglon(@esc.grado, @castellano)
    assert_equal 6, castellano.weekly_hours
    fisica = renglon(@segundo, @fisica)

    patch carga_horaria_path, params: { horas: { castellano.id.to_s => "", fisica.id.to_s => "4" } }

    assert_redirected_to carga_horaria_path
    assert_nil con_el_colegio(@esc.colegio) { castellano.reload.weekly_hours }
    assert_equal 4, con_el_colegio(@esc.colegio) { fisica.reload.weekly_hours }
  end

  # O se guarda todo, o nada: una casilla mal escrita no puede dejar las otras
  # cambiadas debajo de un mensaje de error.
  test "con un valor imposible no se guarda NADA, y lo dice" do
    castellano = renglon(@esc.grado, @castellano)
    fisica = renglon(@segundo, @fisica)

    patch carga_horaria_path, params: { horas: { castellano.id.to_s => "4", fisica.id.to_s => "90" } }

    assert_response :unprocessable_entity
    assert_match "No se guardó nada", response.body
    assert_match "Física en 3er Año", response.body
    assert_nil con_el_colegio(@esc.colegio) { castellano.reload.weekly_hours }
    # Lo escrito vuelve en su campo, para corregirlo sin reescribir todo.
    assert_select "input[name='horas[#{fisica.id}]'][value='90']"
  end

  test "proponer las del plan oficial llena lo vacío y lo dice" do
    post proponer_carga_horaria_path

    assert_redirected_to carga_horaria_path
    assert_match "con las horas del plan oficial", flash[:notice]
    assert_equal 4, renglon(@esc.grado, @castellano).weekly_hours
    assert_equal 4, renglon(@segundo, @fisica).weekly_hours
  end

  test "el total se compara con la semana del turno, y avisa si sobra" do
    post bell_schedules_path, params: { bell_schedule: { name: "Media · mañana" },
                                        timbre: { entrada: "07:10", minutos_por_hora: "40", horas_al_dia: "2",
                                                  receso_minutos: "30", receso_tras: "0" } }
    turno = con_el_colegio(@esc.colegio) { BellSchedule.last }
    patch bell_schedule_path(turno), params: { bell_schedule: { section_ids: [ @esc.seccion.id.to_s ] } }
    # Dos horas al día son diez a la semana; 1er Año escribe doce.
    escribir(@esc.grado, @castellano, 8)
    escribir(@esc.grado, @esc.materia, 4)

    get carga_horaria_path

    assert_select "span.estado.estado--atencion", text: "sobran 2"
  end

  test "el profesor no entra" do
    sign_in @a.profesor

    get carga_horaria_path
    assert_response :redirect
  end
end
