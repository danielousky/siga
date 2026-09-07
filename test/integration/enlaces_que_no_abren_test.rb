require "test_helper"

# Un enlace que rebota es peor que no tener enlace.
#
# Daniel, viendo la ficha de una sección como profesor: *«¿para qué colocamos el
# enlace a otro profe si como profesor solo puedo ver mis datos? Evitar el error
# es mejor UI que indicar que ocurrió»*.
#
# ⚠️ La condición de la vista tiene que ser LA MISMA que la del controller. Dos
# listas de permisos se desparejan, y el síntoma es justamente ése: una pantalla
# que ofrece una puerta que otra rechaza.
class EnlacesQueNoAbrenTest < ActionDispatch::IntegrationTest
  setup do
    @a, = dos_colegios_completos(nivel: :primaria)
    con_el_colegio(@a.colegio) do
      @a.seccion.update!(leader_teacher: @a.registro_de_profesor)
    end
  end

  test "el profesor ve el nombre del guía, sin enlace" do
    sign_in @a.profesor
    get section_path(@a.seccion)

    assert_response :success
    assert_select ".detail-value", /#{@a.profesor.apellidos_y_nombres}/
    assert_select "a[href=?]", teacher_path(@a.registro_de_profesor), count: 0
  end

  # Y no es que el enlace sobre: es que no abre. Comprobado.
  test "y si lo tocara, rebotaría" do
    sign_in @a.profesor
    get teacher_path(@a.registro_de_profesor)

    assert_response :redirect
  end

  test "la dirección sí lo ve enlazado, porque sí puede entrar" do
    sign_in @a.director
    get section_path(@a.seccion)

    assert_select "a[href=?]", teacher_path(@a.registro_de_profesor)

    get teacher_path(@a.registro_de_profesor)
    assert_response :success
  end
end
