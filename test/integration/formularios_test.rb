require "test_helper"

# Que todos los formularios se vean como el mismo producto.
#
# Había CUATRO estructuras distintas para la misma pantalla, y una se veía
# claramente mal:
#
#   profesor · administrador  →  %fieldset + %legend, que en el tema del colegio
#                                NO tienen ninguna regla CSS: el navegador los
#                                dibujaba con su borde gris hundido, adentro de
#                                una tarjeta. Y el de profesor tenía uno VACÍO.
#   estudiante                →  sin tarjeta en `new`/`edit`, con las tarjetas
#                                dentro del parcial, `style` en línea, y
#                                "Cancelar" fuera de la barra de acciones.
#   representante             →  sin tarjeta y con `user[document]` DOS VECES.
#   el resto                  →  bien.
#
# Esto no se ve en una revisión de código —cada archivo por separado parece
# razonable— y tampoco lo veía ningún test, porque todos devolvían 200.
class FormulariosTest < ActionDispatch::IntegrationTest
  ALTAS = {
    "estudiante"    => :new_student_path,
    "profesor"      => :new_teacher_path,
    "administrador" => :new_admin_path,
    "representante" => :new_representative_path,
    "materia"       => :new_subject_path,
    "departamento"  => :new_department_path,
    "sección"       => :new_section_path,
    "grado"         => :new_grade_path,
    "período"       => :new_academic_period_path,
    "inscripción"   => :new_enrollment_path
  }.freeze

  setup do
    @a, _b = dos_colegios_completos
    sign_in @a.director
  end

  ALTAS.each do |nombre, ruta|
    test "el alta de #{nombre} usa la estructura de la casa" do
      get send(ruta)

      assert_response :success
      assert_select ".card-academic", minimum: 1, message: "sin tarjeta: los campos flotan sobre el fondo"
      assert_select ".form-acciones", 1, "los botones van en UNA barra de acciones"
    end

    # `fieldset` y `legend` solo tienen estilo en el panel oscuro de SIGA
    # (`.siga-fieldset`). En el tema del colegio los dibuja el navegador.
    test "el alta de #{nombre} no usa fieldset sin estilo" do
      get send(ruta)

      assert_select "fieldset:not([class])", false,
                    "un fieldset sin clase se dibuja con el borde por defecto del navegador"
    end

    # Dos inputs con el mismo `name` se ven repetidos y, al enviar, gana el
    # último — que suele ser el que la persona no llenó. Pasó dos veces: en el
    # alta de representantes y en la de colegios.
    test "el alta de #{nombre} no repite ningún campo" do
      get send(ruta)

      # ⚠️ Los RADIO quedan fuera: un grupo de opciones comparte el `name` por
      # definición —así es como el navegador sabe que son excluyentes— y contarlo
      # como duplicado marcaría cada grupo de botones como un error.
      # Los `hidden` de Rails para los checkbox, por la misma razón.
      nombres = css_select("input[name], select[name], textarea[name]")
                  .reject { |e| %w[radio hidden].include?(e["type"]) }
                  .map { |e| e["name"] }
                  .reject { |n| n.end_with?("[]") || n == "authenticity_token" || n == "_method" }

      repetidos = nombres.tally.select { |_, veces| veces > 1 }.keys

      assert_empty repetidos, "campos repetidos: #{repetidos.join(', ')}"
    end
  end

  # El estilo vive en `system.css`; una vista que escribe colores o márgenes a
  # mano se sale del sistema sin que nadie lo note.
  #
  # ⚠️ La excepción es `--ancla` (MOR-196), y no es un agujero en la regla.
  #
  # Lo que se prohíbe es escribir APARIENCIA a mano: un color, un margen, un
  # ancho. `--ancla` no pinta nada — le da a cada pista un nombre propio para
  # que su popover se ancle a SU botón y no al último de la página, que es el
  # bug que tenía. Es un valor POR INSTANCIA, que es exactamente para lo que
  # existe el atributo `style`; las reglas siguen en la hoja de estilos.
  SOLO_LA_ANCLA = /\Astyle="--ancla: --pista-[0-9a-f]+"\z/

  test "ningún formulario escribe estilo en línea" do
    ALTAS.each_value do |ruta|
      get send(ruta)
      formulario = response.body[%r{<form.*</form>}m].to_s
      estilos = formulario.scan(/style="[^"]*"/).reject { |e| "style=#{e[6..]}" =~ SOLO_LA_ANCLA }

      assert_empty estilos, "#{ruta} tiene `style=` dentro del formulario: #{estilos.join(' ')}"
    end
  end
end
