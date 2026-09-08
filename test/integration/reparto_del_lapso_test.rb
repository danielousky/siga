require "test_helper"

# El reparto del 100 % se toca desde el plan, y ENTERO (QA del 8 de septiembre).
#
# Daniel: *«ese porcentaje debería estar directamente aquí y moverse
# dinámicamente unos con otros, de modo que vea cuánto % llevo y cuánto % me
# queda… no ver el porcentaje aislado sino como un todo»*.
#
# ## ⚠️ Por qué es UNA acción y no un `update` por evaluación
#
# Guardando de a una, pasar de 40/60 a 60/40 es imposible: la primera en
# guardarse choca contra el reparto viejo de la otra —60 + 60 = 120— y el
# modelo la rechaza. El profesor tendría que bajar una, guardar, subir la otra
# y guardar otra vez, resolviendo a mano un orden que el sistema ya sabe.
#
# Por eso se escriben todas y se valida la SUMA al final, sobre lo que va a
# quedar y no sobre lo que había.
class RepartoDelLapsoTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @contexto = { asignacion: "#{@a.seccion.id}:#{@a.escenario.materia.id}", lapso: @lapso.id }
    @taller, @examen = con_el_colegio(@a.colegio) do
      [ actividad(@a.escenario, lapso: @lapso, peso: 40, descripcion: "Taller"),
        actividad(@a.escenario, lapso: @lapso, peso: 60, descripcion: "Examen") ]
    end
    sign_in @a.profesor
  end

  def repartir(pesos)
    patch reparto_evaluation_activities_path(@contexto), params: { pesos: pesos }
  end

  def pesos_guardados
    con_el_colegio(@a.colegio) do
      [ @taller.reload.weight_percentage.to_i, @examen.reload.weight_percentage.to_i ]
    end
  end

  # ⚠️ El caso que hace falta la acción de colección: el paso intermedio
  # (60 + 60 = 120) es inválido, y el resultado (60 + 40) es válido.
  test "intercambiar dos pesos, que de a uno sería imposible" do
    repartir(@taller.id => 60, @examen.id => 40)

    assert_equal [ 60, 40 ], pesos_guardados
  end

  test "pasarse de 100 no guarda NADA" do
    repartir(@taller.id => 70, @examen.id => 60)

    assert_equal [ 40, 60 ], pesos_guardados, "el reparto entero se rechaza, no a medias"
    assert_match(/no puede pasar de 100/, flash[:alert])
  end

  test "dejar el lapso incompleto se permite, y se dice cuánto falta" do
    repartir(@taller.id => 30, @examen.id => 40)

    assert_equal [ 30, 40 ], pesos_guardados
    assert_match(/Faltan 30 %/, flash[:notice])
  end

  test "cerrar en 100 lo dice" do
    repartir(@taller.id => 25, @examen.id => 75)

    assert_match(/cierra en 100 %/, flash[:notice])
  end

  # ⚠️ El filtro es el `alcance`, no la confianza en el formulario: un id de
  # otra sección se ignora en silencio, no se guarda ni revienta.
  test "una evaluación de otro colegio se ignora" do
    _, b = dos_colegios_completos(nivel: :primaria)
    ajena = con_el_colegio(b.colegio) { actividad(b.escenario, lapso: b.escenario.lapso(2), peso: 50) }

    repartir(@taller.id => 30, ajena.id => 90)

    assert_equal 30, pesos_guardados.first
    assert_equal 50, con_el_colegio(b.colegio) { ajena.reload.weight_percentage.to_i }
  end

  test "un peso que no es un número se ignora, y los demás se guardan" do
    repartir(@taller.id => "abc", @examen.id => 55)

    assert_equal [ 40, 55 ], pesos_guardados
  end

  # La coma decimal: un profesor venezolano escribe «33,33», no «33.33».
  test "la coma decimal se entiende" do
    repartir(@taller.id => "33,33", @examen.id => "66,67")

    assert_equal [ 33.33, 66.67 ],
                 con_el_colegio(@a.colegio) { [ @taller.reload, @examen.reload ].map { |e| e.weight_percentage.to_f } }
  end

  test "la dirección mira el plan pero no reparte" do
    sign_in @a.director

    repartir(@taller.id => 10, @examen.id => 20)

    assert_equal [ 40, 60 ], pesos_guardados
  end

  # ── Lo que se ve en el plan ─────────────────────────────────────────────
  def ver_el_plan
    get planificar_section_path(@a.seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  test "la barra tiene un tramo por evaluación, y el hueco de lo que falta" do
    repartir(@taller.id => 30, @examen.id => 40)
    ver_el_plan

    assert_select ".plan-ponderacion-tramo", count: 2
    assert_select ".plan-ponderacion-hueco[style=?]", "width: 30.0%"
  end

  test "el profesor edita el peso en la fila; la dirección solo lo lee" do
    ver_el_plan
    assert_select ".plan-evaluacion-peso-campo", count: 2
    # ⚠️ Atado por `form:` al formulario de la barra, que está fuera de la
    # lista: un `<form>` envolvente anidaría los `button_to` de borrar.
    assert_select ".plan-evaluacion-peso-campo[form=?]", "reparto-del-lapso"

    sign_in @a.director
    ver_el_plan
    assert_select ".plan-evaluacion-peso-campo", count: 0
    assert_select ".plan-evaluacion-peso-fijo", "40 %"
  end
end
