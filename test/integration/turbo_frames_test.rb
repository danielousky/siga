require "test_helper"

# Los listados con buscador viven dentro de un turbo frame, y eso trae una
# trampa que no se ve leyendo el código.
#
# Un enlace dentro de un `<turbo-frame>` navega **dentro del frame**, no en la
# página. Así que "Ver" en un listado de alumnos pide `/students/:id` esperando
# encontrar ahí un frame con el mismo id — y como no existe, Turbo reemplaza la
# tabla por el texto «Content missing».
#
# El botón no da error, no rompe nada y no lleva a ningún lado. Lo encontró
# Daniel haciendo QA, y ningún test lo veía porque **por HTTP todo devuelve
# 200**: el detalle del alumno se renderiza perfecto, solo que nadie llega a él.
#
# `target: "_top"` en el frame hace que los enlaces de adentro naveguen la
# página entera. El buscador sigue actualizando el frame porque declara su
# destino explícito, y eso le gana al `target`.
class TurboFramesTest < ActionDispatch::IntegrationTest
  # Cada listado con buscador, con el enlace que se rompía.
  LISTADOS = {
    "/students"                  => "students-results",
    "/sections"                  => "sections-results",
    "/enrollments"               => "enrollments-results",
    "/dashboards/activity_logs"  => "activity-results"
  }.freeze

  setup do
    @a, = dos_colegios_completos
    sign_in @a.director
  end

  LISTADOS.each do |ruta, frame|
    test "#{ruta} · los enlaces de adentro del frame navegan la página entera" do
      get ruta

      assert_response :success
      assert_select "turbo-frame##{frame}[target=?]", "_top",
                    message: "sin target=_top, cada Ver/Editar de #{ruta} pinta «Content missing»"
    end
  end

  # La otra mitad: el buscador TIENE que seguir actualizando solo el frame. Un
  # `target: "_top"` mal puesto haría que buscar recargue la página entera y se
  # pierda el foco del campo — que es justo lo que el frame vino a evitar.
  test "el buscador sigue apuntando al frame, no a la página" do
    get students_path

    assert_select "form[data-turbo-frame=?]", "students-results",
                  message: "el buscador dejó de actualizar el frame"
  end

  # Y el detalle sigue existiendo: el problema nunca fue que la página fallara,
  # era que nadie llegaba a ella.
  test "el detalle del alumno responde bien — el problema era llegar" do
    get student_path(@a.alumno)

    assert_response :success
    assert_match(/#{Regexp.escape(@a.alumno.user.apellidos)}/, response.body)
  end
end
