require "test_helper"

# Que crear algo termine en una pantalla que existe, y quede registrado.
#
# Dos cosas que se rompieron juntas y ningún test veía:
#
# 1. Al borrar los `show` que solo repetían la fila del listado (MOR-135), los
#    controllers siguieron haciendo `redirect_to @department`. El helper
#    `department_path` **sigue existiendo** —`PATCH` y `DELETE` comparten esa
#    ruta— así que no explota: crea bien y **deja al usuario en un 404**.
#    Quince redirecciones así, en cinco recursos.
#
# 2. `ActivityLog` tenía etiquetas para secciones, profesores, administradores
#    y períodos, y **ningún controller las emitía**.
class AltasYBajasTest < ActionDispatch::IntegrationTest
  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  def logs = con_el_colegio(@a.escenario.colegio) { ActivityLog.count }
  def ultimo_log = con_el_colegio(@a.escenario.colegio) { ActivityLog.order(:created_at).last }

  test "crear un departamento lleva a una pantalla que existe y queda registrado" do
    assert_difference "logs", 1 do
      post departments_path, params: { department: { name: "Ciencias Sociales" } }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success, "el redirect después de crear tiene que llevar a una pantalla que existe"

    assert_equal "department_created", ultimo_log.action
    assert_match(/creó el departamento Ciencias Sociales/, ultimo_log.message)
  end

  test "editar un departamento también" do
    departamento = con_el_colegio(@a.escenario.colegio) do
      Department.create!(school: @a.escenario.colegio, name: "Artes")
    end

    assert_difference "logs", 1 do
      patch department_path(departamento), params: { department: { name: "Artes y Patrimonio" } }
    end

    follow_redirect!
    assert_response :success
    assert_equal "department_updated", ultimo_log.action
  end

  test "borrar deja constancia con el nombre que tenía" do
    departamento = con_el_colegio(@a.escenario.colegio) do
      Department.create!(school: @a.escenario.colegio, name: "Departamento Efímero")
    end

    assert_difference "logs", 1 do
      delete department_path(departamento)
    end

    follow_redirect!
    assert_response :success
    assert_equal "department_destroyed", ultimo_log.action
    assert_match(/eliminó el departamento Departamento Efímero/, ultimo_log.message)
  end

  # El caso general: ningún recurso puede redirigir a una ruta que no existe.
  # Se comprueba sobre los cinco que perdieron su `show`.
  test "ningún alta termina en una pantalla inexistente" do
    rutas = {
      departments_path       => { department: { name: "Prueba #{SecureRandom.hex(3)}" } },
      academic_periods_path  => { academic_period: { name: "2099-2100",
                                                     start_date: "2099-09-01",
                                                     end_date: "2100-07-31" } }
    }

    rutas.each do |ruta, params|
      post ruta, params: params
      assert_response :redirect, "#{ruta} debería redirigir tras crear"

      follow_redirect!
      assert_response :success,
        "#{ruta} redirige a una pantalla que no existe — pasa cuando se borra un " \
        "`show` y el controller sigue haciendo `redirect_to @registro`"
    end
  end
end
