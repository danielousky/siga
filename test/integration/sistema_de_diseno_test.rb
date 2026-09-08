require "test_helper"

# El sistema de diseño, y lo que impide saltárselo.
#
# ## Por qué existe este archivo
#
# Daniel, 8 de septiembre de 2026: *«ayer hice una captura de por lo menos cinco
# tipos de títulos principales. Eso es inconcebible… todos los títulos deben ser
# idénticos… un framework vale, nuestro propio framework»*.
#
# La auditoría le dio la razón por más —había siete formas, más dos escritas a
# mano con `style:` inline— y dejó claro que **el diagnóstico no era que faltara
# el framework**: hay 709 clases en 9.548 líneas de CSS. El problema era que
# **era opcional**. La cabecera correcta existía desde `MOR-192` y la usaban
# catorce pantallas de ochenta y cuatro.
#
# ⚠️ Nadie eligió divergir. La pieza correcta existía, no era obligatoria, y el
# camino corto era escribir `%h1`. Un sistema de diseño que no falla cuando se
# lo ignoran no es un sistema: es una sugerencia.
#
# Este proyecto ya sostiene tres reglas así —`nombres_de_las_acciones_test` los
# verbos, `plural_en_espanol_test` los plurales, `hoja_de_estilos_test` las
# variables— y funcionan **porque fallan**.
#
# Spec completo en `docs/specs/sistema-de-diseno.md`.
class SistemaDeDisenoTest < ActiveSupport::TestCase
  HOJA = Rails.root.join("app/assets/stylesheets/system.css")

  TONOS = %w[guardar accion documento ver secondary danger].freeze

  # ⚠️ LOS MAILERS QUEDAN FUERA, y no es una excepción de conveniencia.
  #
  # Un correo HTML **necesita** estilos inline y `<table>` de maquetación:
  # Gmail y Outlook descartan las hojas externas y no soportan flex ni grid. La
  # regla del correo es otra regla, no una versión relajada de ésta.
  #
  # Los dos `%h1` con `style:` que encontró la auditoría son los dos de
  # mailers — o sea que ahí estaban bien.
  MAILERS = %r{app/views/(layouts/mailer|\w*_mailer)}
  VISTAS  = Rails.root.glob("app/views/**/*.haml").reject { |v| v.to_s.match?(MAILERS) }.freeze

  # Las tablas del panel de SIGA llevan `siga-tabla` a propósito: ese panel es
  # deliberadamente distinto al del colegio, para que confundirlos sea imposible
  # (`MOR-133`). Y la boleta y la constancia son papel, no pantalla.
  TABLAS_VALIDAS = /table-academic|siga-tabla|table-boleta|table-constancia/

  # ── Los seis tonos, y ninguno más ─────────────────────────────────────────

  # ⚠️ `btn-primary` se retiró, y no es un renombre.
  #
  # Al pasar el alta al verde —«el verde significa: esto queda guardado»— el
  # azul se quedó sin trabajo. Y «primario» nunca fue un trabajo: es jerarquía
  # visual, justo lo que `MOR-172` reemplazó por QUÉ HACE el botón.
  test "btn-primary no vuelve, ni al CSS ni a las vistas" do
    en_el_css = HOJA.read.match?(/^\.btn-primary[\s{,]/)
    assert_not en_el_css,
      ".btn-primary volvió a la hoja. Los tonos se nombran por lo que HACEN: " \
      "#{TONOS.join(' · ')}"

    en_vistas = VISTAS.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        # Las líneas de comentario Haml explican la regla; no la rompen.
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/btn-primary/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 80]}"
      end
    end

    assert_empty en_vistas,
      "vistas que todavía usan btn-primary. La pregunta no es de qué color: es " \
      "cuál de los seis verbos hace el botón (ver /siga/estilo):\n  " + en_vistas.join("\n  ")
  end

  # El tono no tiene default a propósito: escribir un botón sin pensar qué hace
  # daba un botón azul, y así el color volvía a no decir nada.
  test "el helper boton exige tono" do
    parametros = ApplicationHelper.instance_method(:boton).parameters

    assert_includes parametros, [ :keyreq, :tono ],
      "`boton` volvió a tener un default de tono. Ese default es el agujero: " \
      "un botón que no decide qué hace sale del color de todos los demás."
  end

  # ⚠️ La primera versión de este test buscaba `boton "` —con la comilla— y se
  # le escapaban las tres llamadas que pasan una VARIABLE:
  # `boton paso.verbo, …`. El CI las encontró igual, pero reventando en cinco
  # tests de pantallas que no tenían nada que ver.
  #
  # Y el tono puede caer en la línea SIGUIENTE, porque la llamada se parte. Por
  # eso se mira el bloque de la llamada, no el renglón.
  test "todas las llamadas a boton dicen su tono" do
    sin_tono = VISTAS.flat_map do |vista|
      lineas = vista.read.lines
      lineas.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/=\s*boton\s/)
        # La llamada puede ocupar hasta tres renglones.
        next if lineas[n, 3].join.match?(/tono:/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 80]}"
      end
    end

    assert_empty sin_tono,
      "botones sin tono; hay que elegir uno de los seis:\n  " + sin_tono.join("\n  ")
  end

  test "los seis tonos existen en la hoja de estilos" do
    hoja = HOJA.read

    TONOS.each do |tono|
      assert_match(/^\.btn-#{tono}\s*[{,]/, hoja, "falta el tono .btn-#{tono}")
    end
  end

  # ── Nada escrito a mano ───────────────────────────────────────────────────

  # ⚠️ El caso más grave que encontró la auditoría: dos `%h1` con la tipografía
  # y el color escritos dentro de la vista. Un color a mano no responde al tema
  # oscuro, no se puede cambiar desde los tokens, y nadie lo encuentra.
  test "ninguna vista lleva estilos escritos a mano" do
    culpables = VISTAS.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/\bstyle:\s*["']|\bstyle=["']/)
        # ⚠️ Un `style` con INTERPOLACIÓN es un dato, no un estilo: el ancho de
        # una barra de progreso es «cuánto llevo cargado», y eso no cabe en una
        # hoja de estilos. Lo que se prohíbe es el valor FIJO escrito a mano.
        next if linea.match?(/style:\s*"[^"]*\#\{/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 90]}"
      end
    end

    assert_empty culpables,
      "estilos inline. Van a system.css con su clase, o no van:\n  " + culpables.join("\n  ")
  end

  # ⚠️ Una `<table>` suelta se ve distinta a las otras cuarenta, y la diferencia
  # aparece recién cuando alguien abre esa pantalla. La clase la pone quien
  # escribe la tabla, no el que la descubre después.
  test "toda tabla lleva su clase" do
    sueltas = VISTAS.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/^\s*%table/)
        next if linea.match?(TABLAS_VALIDAS)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 80]}"
      end
    end

    assert_empty sueltas,
      "tablas sin clase; la única es .table-academic:\n  " + sueltas.join("\n  ")
  end

  # ── El alta, idéntica en las 84 pantallas ─────────────────────────────────

  # ⚠️ El tooltip no es decoración: en el teléfono NO HAY HOVER, y «Agregar» a
  # secas no dice de qué se trata (`MOR-173`). Es el nombre del control.
  test "el botón de alta de la cabecera lleva tooltip y aria-label" do
    cabecera = Rails.root.join("app/views/shared/_cabecera.html.haml").read

    assert_match(/btn btn-guardar btn-agregar/, cabecera,
                 "el alta va en verde: el verde significa «esto queda guardado»")
    assert_match(/data: \{ tooltip: alta\[:nombre\] \}/, cabecera)
    assert_match(/"aria-label": alta\[:nombre\]/, cabecera)
  end

  # ── Una sola cabecera, etapa ② ────────────────────────────────────────────

  # ⚠️ Las tres que quedan fuera NO son deuda: son contextos distintos.
  #
  # Devise vive en el layout de acceso —sin barra, sin menú, centrado en una
  # tarjeta—; el sitio público es marketing; la portada del boletín es PAPEL.
  # Forzarlas al mismo partial sería el error inverso al que la etapa ②
  # corrige.
  # ⚠️ Y `siga/` también: el panel de la plataforma es deliberadamente distinto
  # al del colegio —fondo oscuro, otra tipografía de menú— para que confundirlos
  # sea imposible (`MOR-133`). Sus `%h1` hablan ese idioma, no el del colegio.
  FUERA_DE_LA_CABECERA = %r{app/views/(devise|inicio|demo_requests|report_cards|constancias|documentos|siga/|verificaciones/no_encontrado)}

  test "ninguna vista escribe su propia cabecera" do
    culpables = VISTAS.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/card-academic-header/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1}"
      end
    end

    assert_empty culpables,
      "cabeceras escritas a mano; la única es `shared/cabecera`:\n  " + culpables.join("\n  ")
  end

  # ⚠️ Un `%h1` suelto es cómo se llegó a siete formas de título: la pieza
  # correcta existía y el camino corto era escribirlo.
  test "el título de una pantalla sale del parcial, no de un %h1 suelto" do
    sueltos = VISTAS.reject { |v| v.to_s.match?(FUERA_DE_LA_CABECERA) }.flat_map do |vista|
      vista.read.lines.each_with_index.filter_map do |linea, n|
        next if linea.strip.start_with?("-#", "#")
        next unless linea.match?(/^\s*%h1[\s={]/)

        "#{vista.relative_path_from(Rails.root)}:#{n + 1} → #{linea.strip[0, 70]}"
      end
    end

    assert_empty sueltos,
      "títulos escritos a mano. Van por `shared/cabecera` (ver docs/specs/" \
      "cabecera-unica.md):\n  " + sueltos.join("\n  ")
  end

  # El parcial es el único que emite el título, así que tiene que saber emitir
  # los dos niveles: `<h1>` para la pantalla, `<h2>` para una tarjeta.
  test "la cabecera distingue el título de pantalla del de tarjeta" do
    cabecera = Rails.root.join("app/views/shared/_cabecera.html.haml").read

    assert_match(/nivel = local_assigns\.fetch\(:nivel, 1\)/, cabecera)
    assert_match(/etiqueta_del_titulo = nivel == 2 \? :h2 : :h1/, cabecera)
  end

  # ⚠️ La FRANJA es solo del título de PANTALLA.
  #
  # Con ella también en los de tarjeta, el portal del representante salía con
  # cuatro barras azules apiladas —«Calificaciones», «Asistencia»,
  # «Boletines»— y el H1 dejaba de distinguirse de los H2. Una marca que
  # aparece en todo deja de marcar nada; lo destapó el barrido visual de las
  # tres vistas, no un test.
  test "el título de tarjeta no lleva franja" do
    cabecera = Rails.root.join("app/views/shared/_cabecera.html.haml").read

    assert_match(/nivel == 2 \? "cabecera-de-lista-titular-simple" : "cabecera-de-lista-franja"/,
                 cabecera)
  end

  # ⚠️ Un comentario Haml SE TRAGA todo lo que quede más indentado debajo.
  #
  #     - @columnas.each do |columna|
  #     -# ⚠️ el momento de la evaluación…      ← en la columna 0
  #             %th= columna.nombre             ← se lo tragó: la tabla salió sin
  #                                               columnas, y NADA falló
  #
  # `-#` es un comentario de BLOQUE, no de línea: consume su cuerpo entero, igual
  # que `- if` consume el suyo. Un comentario mal indentado se lleva por delante
  # la vista que viene debajo, Haml compila feliz y el HTML sale válido — solo
  # que le falta la mitad. Pasó tres veces en un día y el único síntoma fue un
  # test que no encontraba lo que buscaba.
  test "ningún comentario Haml se traga la vista que viene debajo" do
    culpables = VISTAS.flat_map do |vista|
      lineas = vista.read.lines
      lineas.each_with_index.filter_map do |linea, n|
        sangria = linea[/\A */].size
        next unless linea.lstrip.start_with?("-#")

        # La siguiente línea que sea CÓDIGO. Entre medio puede haber más texto
        # del comentario, que sí va indentado a propósito.
        siguiente = lineas[(n + 1)..].find { |l| l.strip.match?(/\A[%.#=-][^#]/) }
        next unless siguiente && siguiente[/\A */].size > sangria

        "#{vista.relative_path_from(Rails.root)}:#{n + 1}"
      end
    end

    assert_empty culpables,
      "comentarios Haml que se tragan el bloque de abajo; la vista se dibuja de " \
      "menos SIN FALLAR:\n  " + culpables.join("\n  ")
  end
end
