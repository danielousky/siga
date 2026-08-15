require "test_helper"

# Lo que un alumno ve de sus notas, y sobre todo lo que NO tiene que ver:
# ni un cero donde falta corregir, ni las notas de otro.
#
# Ver MOR-97.
class Dashboards::NotasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @esc = escenario_academico(pesos: [30, 30, 40], alumnos: 2)

    con_el_colegio(@esc.colegio) do
      @examen = actividad(@esc, lapso: @esc.lapso(1), peso: 60, descripcion: "Examen")
      @taller = actividad(@esc, lapso: @esc.lapso(1), peso: 40, descripcion: "Taller")

      # El primer alumno tiene el examen corregido y el taller no.
      nota(@examen, @esc.alumno(1), 18)
      # El segundo tiene las dos.
      nota(@examen, @esc.alumno(2), 12)
      nota(@taller, @esc.alumno(2), 8)
    end
  end

  test "el alumno ve sus evaluaciones con nota y ponderación" do
    sign_in @esc.alumno(1).user

    get dashboards_notas_url

    assert_response :success
    assert_match "Examen", response.body
    assert_match "60 %", response.body
    assert_match "Matemática", response.body
  end

  # ══════════════════════════════════════════════════════════════════════════
  # Sin nota NO es cero — lo que evita una llamada al colegio
  # ══════════════════════════════════════════════════════════════════════════

  test "una evaluación sin corregir dice Pendiente, nunca un número" do
    sign_in @esc.alumno(1).user

    get dashboards_notas_url

    assert_match "Pendiente", response.body
    assert_match "nota-pendiente", response.body
  end

  test "el promedio de un lapso a medio corregir se marca como parcial" do
    sign_in @esc.alumno(1).user

    get dashboards_notas_url

    # Solo tiene el examen (60 %) corregido: el 18 es sobre ese 60 %.
    assert_match "parcial", response.body
    assert_match "60 % corregido", response.body
  end

  test "con el lapso completo el promedio no se marca como parcial" do
    sign_in @esc.alumno(2).user

    get dashboards_notas_url

    assert_no_match(/parcial/, response.body)
    assert_no_match(/Pendiente/, response.body)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # El aislamiento
  # ══════════════════════════════════════════════════════════════════════════

  test "cada alumno ve SU nota, no la del compañero de al lado" do
    sign_in @esc.alumno(1).user
    get dashboards_notas_url
    primero = response.body

    sign_out @esc.alumno(1).user
    sign_in @esc.alumno(2).user
    get dashboards_notas_url

    # 18 vs 12 en el mismo examen de la misma sección.
    assert_match ">18<", primero
    assert_no_match(/>18</, response.body)
    assert_match ">12<", response.body
  end

  test "pedir el lapso de otro año no muestra nada ajeno" do
    ajeno = escenario_academico(nombre: "Otro Colegio")
    sign_in @esc.alumno(1).user

    get dashboards_notas_url(lapso: ajeno.lapso(1).id)

    # El lapso se busca entre los del período del propio alumno: uno ajeno
    # simplemente no aparece y cae al lapso en curso.
    assert_response :success
    assert_match "Examen", response.body
  end

  test "un profesor no entra a la vista del estudiante" do
    docente = con_el_colegio(@esc.colegio) do
      usuario = User.create!(name: "Prof", last_name: "Uno",
                             email: "prof.#{@esc.seccion.id}@test.edu", password: "123123")
      Teacher.create!(user: usuario, school: @esc.colegio)
      usuario
    end

    sign_in docente
    get dashboards_notas_url

    assert_redirected_to dashboards_profesor_path
  end

  # ══════════════════════════════════════════════════════════════════════════
  # La vista anual
  # ══════════════════════════════════════════════════════════════════════════

  test "la vista anual muestra la definitiva y distingue aprobada de aplazada" do
    sign_in @esc.alumno(2).user

    get dashboards_notas_url(lapso: "anual")

    assert_response :success
    assert_match "Calificaciones definitivas", response.body
    # 12×60 + 8×40 = 1040/100 = 10,4 → 10. Aprobada por un punto.
    assert_match "nota-valor--aprobada", response.body
  end
end
