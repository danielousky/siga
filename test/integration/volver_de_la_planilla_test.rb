require "test_helper"

# El «Volver» de la planilla de notas devuelve a la libreta de su sección.
#
# Daniel: *«el volver de evaluaciones debe llevarlo a /secciones/ID?area=240»*.
# Es la misma idea de toda la etapa ③: el profesor entró desde la columna de su
# libreta, y devolverlo a la ficha suelta de la evaluación lo saca de la
# sección donde estaba trabajando.
class VolverDeLaPlanillaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @actividad = @a.actividad
    sign_in @a.profesor
  end

  test "vuelve a la libreta de su sección, con área y lapso" do
    get evaluation_activity_notas_path(@actividad)

    assert_select "a[href=?]", section_path(@a.seccion,
                                            area: @a.escenario.materia.id,
                                            lapso: @actividad.evaluation_moment_id)
  end

  # ⚠️ Con el LAPSO, y no solo el área: sin él la libreta abre en el que está en
  # curso, que en marzo no es el que el profesor acaba de calificar.
  test "el lapso viaja en el enlace" do
    get evaluation_activity_notas_path(@actividad)

    # ⚠️ Dentro de `main`, no en toda la página: el ÁRBOL DEL MENÚ también
    # enlaza a `/secciones/:id` —con área y sin lapso— y un `find` sobre todos
    # los enlaces se queda con el primero, que es el del sidebar.
    volver = css_select("main a").map { |a| a["href"] }
                                .find { |h| h&.include?("/secciones/#{@a.seccion.id}") }

    assert_includes volver, "lapso=#{@actividad.evaluation_moment_id}"
  end
end
