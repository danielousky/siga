require "test_helper"

# Ningún `id` se repite dentro de una pantalla.
#
# ## ⚠️ Por qué esto tiene un test y no es solo higiene
#
# Un `id` repetido es HTML inválido, sí. Pero lo que cuesta es Turbo: después de
# pintar un Turbo Stream vuelve a enfocar por `id` —para no perder el foco si el
# elemento enfocado fue reemplazado— y `getElementById` devuelve SIEMPRE el
# primero de la página.
#
# Ya mordió dos veces el mismo día:
#
#     number_field_tag :score   →  id="score" en los treinta campos
#                                  Enter saltaba al alumno siguiente y el foco
#                                  volvía solo al PRIMERO de la lista
#
#     el panel de contexto      →  id="id" por año escolar, id="nivel" por
#                                  nivel, en TODAS las pantallas
#
#     el flash de la libreta    →  dos id="flash", y el que un stream agarra es
#                                  el de afuera del frame — el que no se ve
#
# El síntoma nunca se parece a la causa: nada falla, nada se registra.
class IdsUnicosTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)

    # ⚠️ DOS años escolares y DOS niveles, o el panel de contexto no dibuja sus
    # selectores y este test pasa sin mirar la mitad que vino a cuidar: los
    # `id` repetidos de ahí salen de un formulario POR OPCIÓN.
    con_el_colegio(@a.colegio) do
      AcademicPeriod.create!(school: @a.colegio, name: "2026-2027",
                             start_date: Date.new(2026, 9, 15), end_date: Date.new(2027, 7, 31))
      Grade.create!(school: @a.colegio, level: :secundaria, name: "1er Año")
    end
  end

  # Las pantallas del DIRECTOR, que es quien ve el panel de contexto completo
  # —con su selector de año y de nivel, que fue una de las dos fuentes.
  test "las pantallas de la dirección no repiten ids" do
    sign_in @a.director

    {
      "el panel"      => dashboards_administrador_path,
      "alumnos"       => students_path,
      "secciones"     => sections_path,
      "profesores"    => teachers_path,
      "la sección"    => section_path(@a.seccion),
      "sus alumnos"   => alumnos_section_path(@a.seccion),
      "años escolares" => academic_periods_path
    }.each { |nombre, ruta| sin_repetidos(nombre, ruta) }
  end

  test "las pantallas del profesor no repiten ids" do
    sign_in @a.profesor

    {
      "su panel"    => dashboards_profesor_path,
      "la libreta"  => section_path(@a.seccion, area: @a.escenario.materia.id),
      "el plan"     => planificar_section_path(@a.seccion, area: @a.escenario.materia.id),
      "la planilla" => evaluation_activity_notas_path(@a.actividad)
    }.each { |nombre, ruta| sin_repetidos(nombre, ruta) }
  end

  private

  def sin_repetidos(nombre, ruta)
    get ruta
    return unless response.successful?

    ids = css_select("[id]").map { |e| e["id"] }.compact_blank
    repetidos = ids.tally.select { |_, veces| veces > 1 }.keys

    assert_empty repetidos,
                 # Turbo re-enfoca y reemplaza por id, y agarra siempre el primero.
                 "#{nombre} (#{ruta}) repite: #{repetidos.join(', ')}"
  end
end
