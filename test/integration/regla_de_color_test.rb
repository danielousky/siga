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

  # Las reglas de la hoja, analizadas UNA vez por proceso.
  #
  # ⚠️ Este archivo se llevaba el 23 % del trabajo de TODA la suite —191 de 831
  # segundos, en cuatro tests— y no por lo que comprueba, sino por cómo leía:
  #
  #     13 veces     se analizaba la hoja entera, una por cada regla que se buscaba
  #     15 s cada    porque `css[k]` sobre un texto con acentos no es un salto:
  #                  Ruby cuenta los caracteres desde el principio, cada vez
  #
  # Recorrer medio millón de caracteres así es recorrerlos medio millón de veces.
  # Por BYTES es un salto de verdad —`{` y `}` ocupan uno solo, y ningún acento
  # contiene esos bytes— y guardando el resultado se hace una sola vez. Mismo
  # análisis, mismas reglas: se comparó la salida de los dos antes de cambiarlo.
  def self.reglas = @reglas ||= reglas_de(HOJA.read)

  ABRE   = "{".ord
  CIERRA = "}".ord

  # Se recorre regla por regla contando llaves, porque un `@media` anida y una
  # regex glotona se lleva por delante lo que viene después.
  def self.reglas_de(css)
    bytes = css.b
    reglas, i, n = [], 0, bytes.bytesize
    while i < n
      j = bytes.index("{", i)
      break unless j

      selector = texto(bytes.byteslice(i, j - i)).strip.lines.last.to_s.strip
      prof, k = 1, j + 1
      while k < n && prof.positive?
        byte = bytes.getbyte(k)
        prof += 1 if byte == ABRE
        prof -= 1 if byte == CIERRA
        k += 1
      end
      reglas << [ selector, texto(bytes.byteslice(j + 1, k - j - 2)) ] unless selector.start_with?("@")
      i = k
    end
    reglas
  end

  def self.texto(bytes) = bytes.force_encoding(Encoding::UTF_8)

  # ⚠️ Esta regla CAMBIÓ DE ALCANCE en MOR-207, y conviene que se lea acá y no
  # solo en un commit.
  #
  # Daniel: *«el tono de ese botón debe tender a verde, al igual que todos todos
  # los submit»* y *«el botón de eliminar debe tener un tono rojo»*. Guardar y
  # eliminar pasan a llevar color; el resto de la regla sigue en pie.
  #
  # ⚠️ Y `btn-guardar` / `btn-danger` NO pasan este test por casualidad: usan
  # tokens PROPIOS (`--guardar-*`, `--eliminar-*`) y no los semánticos del dato
  # (`--success-*`, `--danger-*`). Eso no era la intención cuando se escribieron
  # —fue así como salió— así que se declaran como excepción explícita: un test
  # que aprueba algo sin haberlo mirado no está cuidando nada.
  #
  # Lo que sigue prohibido, y es el corazón de la regla: que un botón se pinte
  # con el MISMO token que usa un dato. Si «Guardar» usara `--success-bg`, el
  # día que alguien retoque ese token para los chips de estado se movería
  # también el botón.
  test "ningún botón usa color semántico" do
    culpables = self.class.reglas.filter_map do |selector, cuerpo|
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
    # Si alguien "limpia" el rojo de las notas, la regla pierde su razón de ser.
    %w[
      .nota-valor--aplazada
      .portal-nota--aplazada
      .ficha-nota--aplazada
      .falta-conteo--alta
    ].each do |clase|
      regla = self.class.reglas.find { |sel, _| sel == clase }
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
  #
  # ⚠️ **Los CORREOS son la excepción, y no es pereza.** Gmail y Outlook
  # descartan `<style>`, `<link>` y las variables CSS: un correo que use tokens
  # llega como texto plano apilado. La única forma de que un correo se vea es
  # con los colores escritos en línea, y el sistema de tokens no llega hasta
  # ahí — no es que se lo salte, es que no existe del otro lado.
  #
  # La excepción es por CARPETA y no por archivo para que no haya que tocar este
  # test cada vez que se agregue un correo; y es solo `*_mailer`, así que una
  # vista de pantalla nunca cae acá por accidente.
  #
  # ⚠️ Y el LAYOUT del correo también (MOR-206). La excepción cubría
  # `app/views/*_mailer/` pero el banner —que es donde están casi todos los
  # colores de un correo— vive en `layouts/mailer_siga`, o sea del otro lado del
  # patrón. El nombre lo delata: `mailer` en un layout es un correo.
  CORREOS = %r{app/views/(\w*_mailer/|layouts/mailer)}
  test "ninguna vista escribe un color a mano" do
    literales = /#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(/

    culpables = Rails.root.glob("app/views/**/*.haml").reject { |r| r.to_s.match?(CORREOS) }.flat_map do |ruta|
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

  # ⚠️ `.btn-primary` SE RETIRÓ el 8 de septiembre de 2026, y este test lo
  # cuida al revés de como lo cuidaba antes.
  #
  # Comprobaba que el azul institucional siguiera siendo la afordancia del
  # control principal. Al pasar el alta al verde —«el verde significa: esto
  # queda guardado»— el azul se quedó sin trabajo, y «primario» nunca fue un
  # trabajo: es jerarquía visual, justo lo que MOR-172 reemplazó por qué HACE
  # el botón.
  #
  # El azul de marca no desapareció: vive en `.btn-ver` (suave) y en los
  # enlaces. Lo que desapareció es un tono cuyo nombre no decía nada.
  test "btn-primary ya no existe: un tono sin verbo no es un tono" do
    assert_nil self.class.reglas.find { |sel, _| sel == ".btn-primary" },
               ".btn-primary volvió a la hoja: los tonos se nombran por lo que HACEN"

    %w[.btn-guardar .btn-accion .btn-documento .btn-ver .btn-secondary .btn-danger].each do |tono|
      assert self.class.reglas.any? { |sel, _| sel == tono },
             "falta el tono #{tono}"
    end
  end

  # ── El alcance nuevo (MOR-207) ────────────────────────────────────────────

  test "guardar y eliminar tienen tono, con tokens propios" do
    css = HOJA.read

    %w[--guardar-primary --eliminar-primary].each do |token|
      assert_match(/#{token}:\s*#[0-9a-f]{6}/i, css, "#{token} tiene que existir")
    end

    guardar = self.class.reglas.find { |selector, _| selector.strip == ".btn-guardar" }
    assert guardar, ".btn-guardar tiene que existir"
    assert_no_match(/--success-|--danger-/, guardar.last,
                    "el botón no puede compartir token con el dato: el día que se " \
                    "retoque el verde de un chip de estado se movería también «Guardar»")
  end
end
