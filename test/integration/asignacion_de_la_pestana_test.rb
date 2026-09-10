require "test_helper"

# La asignación de ESTA sección, no la primera del profesor con esa área.
#
# Daniel, 10 de septiembre: *«el "Copiar el Plan entre secciones" del profesor
# ¿dónde quedó?»*. No había desaparecido: la pantalla estaba mirando el grado
# equivocado.
#
# `asignacion` buscaba solo por materia sobre `mis_asignaciones`, que son TODAS
# las del profesor —eso es a propósito: las hermanas viven en otras secciones—.
# Un profesor de Matemática en doce secciones recibía siempre la primera, y en
# 6to Grado A —que no tiene hermana— la pantalla decía «la otra sección de
# **1er Grado** ya tiene su plan».
#
# ⚠️ De `asignacion` cuelgan `otras_secciones`, `hermanas_sin_plan` y el plan
# del año pasado, así que el error alcanzaba a todo lo que compara grados.
class AsignacionDeLaPestanaTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    @lapso = @a.escenario.lapso(2)
    @otro_grado = con_el_colegio(@a.colegio) do
      grado = Grade.create!(name: "5to Grado", level: :primaria, orden: 5)
      seccion = Section.create!(grade: grado, academic_period: @a.seccion.academic_period,
                                name: "A", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: seccion,
                             subject: @a.escenario.materia)
      seccion
    end
    sign_in @a.profesor
  end

  def plan_de(seccion)
    get planificar_section_path(seccion, area: @a.escenario.materia.id, lapso: @lapso.id)
  end

  test "cada sección mira su propio grado" do
    plan_de @otro_grado

    # Sin esto, el aviso hablaba del grado de la PRIMERA asignación.
    assert_select ".plan-acciones", false,
                  "5to Grado A no tiene hermanas: no hay nada que ofrecer copiar"
  end

  # Con una hermana SIN plan, el botón sale y nombra el grado correcto.
  test "el botón de copiar nombra la sección hermana de verdad" do
    hermana = con_el_colegio(@a.colegio) do
      s = Section.create!(grade: @otro_grado.grade, academic_period: @a.seccion.academic_period,
                          name: "B", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s,
                             subject: @a.escenario.materia)
      competencia_con(0, "Resuelve problemas", lapso: @lapso, seccion: @otro_grado)
      s
    end

    plan_de @otro_grado

    assert_select ".plan-acciones button", /Duplicar en 5to Grado B/
    assert_equal "B", con_el_colegio(@a.colegio) { hermana.name }
  end

  # ⚠️ Y desde la HERMANA se ofrece copiar en el otro sentido: cada sección
  # calcula lo suyo. Con la asignación equivocada, las dos veían lo mismo.
  test "desde la hermana se ofrece copiar en el otro sentido" do
    hermana = con_el_colegio(@a.colegio) do
      s = Section.create!(grade: @otro_grado.grade, academic_period: @a.seccion.academic_period,
                          name: "B", capacity: 30)
      TeacherSection.create!(teacher: @a.registro_de_profesor, section: s,
                             subject: @a.escenario.materia)
      competencia_con(0, "Resuelve problemas", lapso: @lapso, seccion: s)
      s
    end

    plan_de hermana

    assert_select ".plan-acciones button", /Duplicar en 5to Grado A/
  end
end
