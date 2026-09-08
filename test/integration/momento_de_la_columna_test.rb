require "test_helper"

# El MOMENTO de cada columna de la libreta (etapa ③).
#
# Daniel lo planteó como *«debería activarse conforme a la fecha colocada dentro
# de la planificación de la evaluación y desactivarse las otras»*, y suena
# razonable hasta que se piensa quién queda afuera: **el profesor que carga
# tarde**, que es el caso normal y lo descubre un domingo a las nueve de la
# noche. Quedó en que la fecha ORDENA y da FOCO, nunca cierra — y él estuvo de
# acuerdo.
#
#     ATRASADA   ya pasó y le faltan notas  → lo que hay que hacer HOY
#     HOY        se aplica hoy              → resaltada
#     FUTURA     todavía no llega           → atenuada, PERO escribible
#     CERRADA    ya pasó y está completa    → no molesta a nadie
class MomentoDeLaColumnaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)   # el 1 ya tiene una actividad de peso 100
  end

  def columna_de(actividad)
    libreta = con_el_colegio(@a.colegio) do
      LibretaDeLaSeccion.para(seccion: @a.seccion, materia: @a.escenario.materia, lapso: @lapso)
    end
    libreta[:columnas].find { |c| c.evaluacion.id == actividad.id }
  end

  test "una evaluación de ayer sin notas está ATRASADA" do
    ayer = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "De ayer")
            .tap { |e| e.update!(date_scheduled: Date.current - 1) }
    end

    assert_equal :atrasada, columna_de(ayer).momento
  end

  # ⚠️ Pasada y COMPLETA no está atrasada: no hay nada pendiente en ella.
  # Confundirlas pintaría media libreta de urgente en diciembre, y entonces el
  # aviso deja de significar nada.
  test "una evaluación de ayer con todas sus notas NO está atrasada" do
    completa = con_el_colegio(@a.colegio) do
      e = actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "Corregida")
      e.update!(date_scheduled: Date.current - 3)
      Enrollment.where(section: @a.seccion, status: :regular).each { |i| nota(e, i.student, 15) }
      e
    end

    assert_equal :cerrada, columna_de(completa).momento
  end

  test "la de hoy se marca como hoy" do
    hoy = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 25, descripcion: "De hoy")
            .tap { |e| e.update!(date_scheduled: Date.current) }
    end

    assert_equal :hoy, columna_de(hoy).momento
    assert_nil columna_de(hoy).dias_para
  end

  test "la futura dice cuántos días faltan" do
    futura = con_el_colegio(@a.colegio) do
      actividad(@a.escenario, lapso: @lapso, peso: 25, descripcion: "La que viene")
            .tap { |e| e.update!(date_scheduled: Date.current + 9) }
    end

    assert_equal :futura, columna_de(futura).momento
    assert_equal 9, columna_de(futura).dias_para
  end

  # ⚠️ Lo que NO puede pasar: que la columna futura quede fuera de la tabla o
  # sin su enlace a la planilla. Se atenúa, se escribe igual — una evaluación
  # se puede adelantar.
  test "la columna futura sigue estando y sigue llevando a su planilla" do
    futura = con_el_colegio(@a.colegio) do
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
      actividad(@a.escenario, lapso: @lapso, peso: 25, descripcion: "La que viene")
            .tap { |e| e.update!(date_scheduled: Date.current + 9) }
    end
    sign_in @a.profesor

    get section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_select ".libreta-columna--futura"
    assert_select ".libreta-columna--futura a[href=?]",
                  evaluation_activity_notas_path(futura)
    assert_select ".libreta-columna--futura .libreta-cuando-marca", text: /9 días/
  end

  test "la atrasada se distingue en la pantalla" do
    con_el_colegio(@a.colegio) do
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
      actividad(@a.escenario, lapso: @lapso, peso: 50, descripcion: "De ayer")
            .update!(date_scheduled: Date.current - 1)
    end
    sign_in @a.profesor

    get section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)

    assert_select ".libreta-columna--atrasada .libreta-cuando-marca", text: "ya pasó"
  end

  # ⚠️ El «0 de 22» de una futura pierde el rojo del avance.
  #
  # El rojo significa «no has cargado ninguna», y en una evaluación que todavía
  # no se aplicó eso es lo esperado, no un problema. Una alarma que suena sin
  # motivo enseña a ignorarlas todas.
  test "la futura no pinta su avance en rojo" do
    hoja = Rails.root.join("app/assets/stylesheets/system.css").read

    assert_match(/\.libreta-columna--futura \.libreta-columna-avance \{[^}]*--text-tertiary/m, hoja)
  end
end
