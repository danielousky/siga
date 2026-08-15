require "test_helper"

# La regla de color (MOR-135).
#
#     El color lo usa el DATO, nunca el CONTROL.
#
# ## Por qué, en un sistema escolar
#
# El rojo de SIGA tiene un significado que no se puede gastar: **un número en
# rojo es un niño aplazado**. Aparece en la libreta que mira una madre desde el
# teléfono, en las notas del alumno, en el conteo de inasistencias de un
# coordinador. Es la señal de más carga emocional del producto.
#
# Si el rojo también quiere decir "este botón borra cosas", deja de decir lo
# primero. Y en una pantalla donde conviven los dos —la ficha del alumno tiene
# notas aplazadas Y tenía un botón Eliminar— el ojo no puede distinguir cuál de
# los dos rojos importa.
#
#     ROJO DE DATO                      ROJO DE CONTROL (prohibido)
#     ────────────                      ───────────────────────────
#     nota-valor--aplazada              btn-danger
#     portal-nota--aplazada             identidad-quitar
#     ficha-nota--aplazada              .borrar (el marco)
#     falta-conteo--alta
#
# Lo destructivo se sigue señalando: por **peso y posición**, no por tono.
# `.btn-danger` tiene borde fuerte y en hover se vuelve tinta sólida; vive en
# un bloque rotulado de la pantalla de edición, con confirmación y con la
# explicación de qué se pierde. El contexto carga lo que antes cargaba el color.
class ReglaDeColorTest < ActiveSupport::TestCase
  HOJA = Rails.root.join("app/assets/stylesheets/system.css").freeze

  SEMANTICO = /--(?:success|danger|warning)-(?:text|bg|border)/

  # Las dos excepciones, y por qué cada una lo es.
  #
  # `.asistencia-boton` — en la toma de asistencia el botón **es** el estado:
  #   tocarlo cicla presente → ausente → tarde. Control y dato son el mismo
  #   objeto, así que no se pueden separar. Quitarle el color no dejaría un
  #   control neutro: dejaría un dato invisible.
  #
  # `.carga-fila[...] .carga-input` — el campo se tiñe por el estado de guardado
  #   de SU PROPIA fila. Es feedback sobre un dato, no decoración de un control.
  EXCEPCIONES = [ ".asistencia-boton", ".carga-input" ].freeze

  # Se recorre regla por regla contando llaves, porque un `@media` anida y una
  # regex glotona se lleva por delante lo que viene después.
  def self.reglas_de(css)
    reglas, i, n = [], 0, css.length
    while i < n
      j = css.index("{", i)
      break unless j

      selector = css[i...j].strip.lines.last.to_s.strip
      prof, k = 1, j + 1
      while k < n && prof.positive?
        prof += 1 if css[k] == "{"
        prof -= 1 if css[k] == "}"
        k += 1
      end
      reglas << [ selector, css[(j + 1)...(k - 1)] ] unless selector.start_with?("@")
      i = k
    end
    reglas
  end

  test "ningún botón usa color semántico" do
    culpables = self.class.reglas_de(HOJA.read).filter_map do |selector, cuerpo|
      next unless selector.match?(/\.btn[\w-]*/)
      next if EXCEPCIONES.any? { |e| selector.include?(e) }
      next unless cuerpo.match?(SEMANTICO)

      "#{selector} → #{cuerpo.scan(SEMANTICO).uniq.join(', ')}"
    end

    assert_empty culpables,
      "El color semántico es del DATO, no del CONTROL. Estas reglas de botón lo usan:\n" \
      "  #{culpables.join("\n  ")}\n" \
      "Lo destructivo se señala por peso y posición — ver la nota en .btn-danger."
  end

  test "el rojo sigue significando algo donde importa" do
    css = HOJA.read

    # Si alguien "limpia" el rojo de las notas, la regla pierde su razón de ser.
    %w[
      .nota-valor--aplazada
      .portal-nota--aplazada
      .ficha-nota--aplazada
      .falta-conteo--alta
    ].each do |clase|
      regla = self.class.reglas_de(css).find { |sel, _| sel == clase }
      assert regla, "falta la regla #{clase}"
      assert regla[1].match?(/--danger-/),
        "#{clase} debería llevar el rojo: es el dato que le da sentido a la regla"
    end
  end

  # Un color escrito a mano en un `style` de vista se sale del sistema de
  # tokens, y por ahí entraron las dos violaciones que había:
  #
  #   · `enrollments/index` pintaba el ámbar con `#f57f17`
  #   · `dashboards/estudiante` usaba `.status-badge.status-pendiente` —dos
  #     clases que no existen en ninguna hoja— con un `style` que las pintaba
  #     de VERDE. El nombre decía "pendiente" y el color decía "aprobado".
  #
  # `var(--token)` en línea se tolera: sigue adentro del sistema. Un hex, no.
  test "ninguna vista escribe un color a mano" do
    literales = /#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(/

    culpables = Rails.root.glob("app/views/**/*.haml").flat_map do |ruta|
      ruta.read.lines.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#")
        next unless linea.match?(/style[:=]/)
        next unless linea.match?(literales)

        "#{ruta.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 90]}"
      end
    end

    assert_empty culpables,
      "Colores escritos a mano, fuera del sistema de tokens:\n  #{culpables.join("\n  ")}"
  end

  # El azul institucional NO es color semántico: es la afordancia del control
  # principal, y esa convención se queda. La regla habla de verde/rojo/ámbar.
  test "el botón principal sigue siendo azul de marca" do
    regla = self.class.reglas_de(HOJA.read).find { |sel, _| sel == ".btn-primary" }

    assert regla, "falta .btn-primary"
    assert regla[1].match?(/--brand-/), ".btn-primary debe usar el azul de marca"
    assert_not regla[1].match?(SEMANTICO), ".btn-primary no debe usar color semántico"
  end
end
