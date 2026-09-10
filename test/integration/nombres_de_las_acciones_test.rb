require "test_helper"

# Una misma acción se llama IGUAL en todas partes.
#
# Daniel: *«los botones de NEW ENTIDAD, algunos dicen "Crear", otros "Nuevo",
# otros "Registrar"... Otros dicen "Cargar". Me parece que el término correcto
# es Registrar»*. Había **cinco** fórmulas para lo mismo:
#
#     Crear el año escolar · Crear nuevo departamento
#     Nuevo administrador · Nueva inscripción · Nuevo lapso · Nuevo grado
#     Registrar representante · Registrar nuevo alumno · Registrar nueva materia
#     Cargar un alumno · Cargar un profesor
#     Agregar una materia · Inscribir a uno
#
# Y peor: el botón y su destino no coincidían. «Registrar nueva materia» llevaba
# a una pantalla titulada «Nueva materia». Es la misma queja que Daniel ya había
# hecho antes —«misma acción, distintos nombres, confunde»— y volvió sola porque
# nada la sostenía.
#
# ## El criterio
#
#     CABECERA del listado    «Registrar <cosa>»
#     TÍTULO de la pantalla   el MISMO texto que el botón que te trajo
#     ESTADO VACÍO            el mismo, para el botón que va al mismo lugar
#     SUBMIT                  «Crear» / «Guardar cambios» — lo pone Rails
#
# ⚠️ «Registrar» y no «Nuevo/Nueva», y hay una razón además de la de Daniel: se
# esquiva la concordancia de género. Con «Nuevo/Nueva» hay que acordarse de cuál
# va con cada sustantivo, y ese es exactamente el tipo de detalle que se afloja
# cuando alguien agrega una pantalla apurado.
#
# ⚠️ Lo que NO entra: los verbos de `PasosDeArranque` («Armar las secciones»,
# «Elegir los niveles», «Subir la matrícula»). Esos ENSEÑAN qué es el paso y
# apuntan al listado, no al alta — otro destino, otro nombre, y está bien.
class NombresDeLasAccionesTest < ActiveSupport::TestCase
  VISTAS = Rails.root.join("app/views").freeze

  # ⚠️ `importaciones` no tiene UN alta: tiene tres puertas al mismo `new` —
  # «Subir la matrícula», «Subir materias y profesores», «Subir notas
  # anteriores»— y cada una carga una planilla distinta. «Registrar
  # importación» no significaría nada para un director; lo que él elige es QUÉ
  # sube. Es la misma excepción que los verbos de `PasosDeArranque`.
  # Y `departments`, que desde MOR-205 no tiene botón de cabecera: su alta es un
  # campo dentro de la propia lista, así que no hay nombre que comparar.
  SIN_ALTA_UNICA = %w[importaciones departments].freeze

  # Cada carpeta con `index` + `new`: el botón de la cabecera y el título.
  def altas
    VISTAS.glob("*/new.html.haml").filter_map do |nueva|
      indice = nueva.dirname.join("index.html.haml")
      next unless indice.exist?

      titulo = titulo_de(nueva)
      boton = boton_de_cabecera(indice)
      next if titulo.nil? || boton.nil?

      [ nueva.dirname.basename.to_s, boton, titulo ]
    end
  end

  # ⚠️ Lo primero: comprobar que se está COMPROBANDO algo.
  #
  # Los tres tests de abajo recorren `altas` y saltan lo que no puedan leer. Con
  # `boton_de_cabecera` devolviendo `nil` —lo que pasó desde MOR-192— la lista
  # quedaba vacía y los tres pasaban sin mirar una sola vista. Verde por no
  # haber hecho nada, que es la peor manera de estar verde.
  test "la lista de altas no está vacía: si no, los demás tests no prueban nada" do
    faltan = Dir[Rails.root.join("app/views/*/new.html.haml")].filter_map do |nueva|
      carpeta = File.basename(File.dirname(nueva))
      next unless File.exist?(File.join(File.dirname(nueva), "index.html.haml"))
      next if SIN_ALTA_UNICA.include?(carpeta)

      carpeta unless altas.any? { |c, _, _| c == carpeta }
    end

    assert_empty faltan, "listados con alta que este test NO está mirando: #{faltan.join(', ')}"
    assert_operator altas.size, :>=, 8, "se esperaban al menos los ocho listados"
  end

  test "todos los botones de alta empiezan por «Registrar»" do
    fuera = altas.reject { |_, boton, _| boton.start_with?("Registrar ") }
                 .map { |carpeta, boton, _| "#{carpeta}: «#{boton}»" }

    assert_empty fuera,
      "botones de alta que no siguen el criterio «Registrar <cosa>»:\n  " + fuera.join("\n  ")
  end

  # ⚠️ La mitad que de verdad confunde: pulsar «Registrar nueva materia» y llegar
  # a una pantalla que dice otra cosa. El botón es una promesa; el título, si
  # cumplió.
  test "el botón y el título de su pantalla dicen lo mismo" do
    distintos = altas.reject { |_, boton, titulo| boton == titulo }
                     .map { |carpeta, boton, titulo| "#{carpeta}: «#{boton}» → «#{titulo}»" }

    assert_empty distintos,
      "el botón lleva a una pantalla que se llama distinto:\n  " + distintos.join("\n  ")
  end

  # ⚠️ La regla tiene DOS capas, y confundirlas fue el bug (MOR-205).
  #
  # Daniel: *«en los index sin registros dice arriba [+ Agregar] y abajo el
  # mismo link pero con otro nombre [+ Registrar Nuevo …]. Confunde»*. Y era
  # exactamente eso: el mismo destino, en la misma pantalla, con dos nombres.
  #
  #     VISIBLE en el botón   «Agregar»       cabecera y estado vacío
  #     TOOLTIP / nombre      «Registrar X»   qué se agrega
  #
  # El verbo se repite y el sustantivo lo pone el contexto: quien está en
  # Departamentos no necesita que un botón le diga que agrega departamentos.
  test "el estado vacío dice lo mismo que la cabecera" do
    distintos = VISTAS.glob("*/index.html.haml").filter_map do |indice|
      texto = indice.read
      next unless texto.include?("cabecera_de_lista")

      # ⚠️ `(?!importacion)`: el estado vacío tiene DOS acciones —subir la
      # planilla y agregar a mano—, y la de importar también va a un `new_…`.
      # Sin excluirla, el test comparaba «Subir la matrícula» contra «Agregar» y
      # marcaba como inconsistente justo lo que sí es consistente: ese botón se
      # llama igual arriba y abajo.
      vacio = texto[/texto: "([^"]+)", ruta: new_(?!importacion)[a-z_]+_path/, 1]
      next if vacio.nil? || vacio == "Agregar"

      "#{indice.dirname.basename}: el estado vacío dice «#{vacio}» y la cabecera «Agregar»"
    end

    assert_empty distintos,
      "el mismo destino con dos nombres:\n  " + distintos.join("\n  ")
  end

  # El submit lo pone Rails desde `es.yml` («Crear» / «Guardar cambios»), y por
  # eso `f.submit` va A SECAS. Escribirle un texto a mano es cómo empezaron a
  # separarse los otros.
  test "los formularios no escriben su propio texto de guardar" do
    a_mano = VISTAS.glob("**/_form.html.haml").filter_map do |form|
      linea = form.read[/^\s*= f\.submit "([^"]+)"/, 1]
      next if linea.nil?

      "#{form.relative_path_from(VISTAS)}: «#{linea}»"
    end

    assert_empty a_mano,
      "usan un texto propio en vez del de `es.yml`:\n  " + a_mano.join("\n  ")
  end

  # ⚠️ El menú y la pantalla que abre dicen lo MISMO.
  #
  # Daniel, viendo `/alumnos`: «este debe decir "Alumnos" como sus hermanos
  # users, en lugar de "Registro de alumnos"». Había cinco pantallas con un
  # título distinto al del enlace que llevaba a ellas —«Catálogo de materias»,
  # «Departamentos académicos», «Ponderación por lapso»— y el efecto es el mismo
  # que con los botones: se pulsa una cosa y se llega a otra.
  test "el menú y el título de la pantalla que abre dicen lo mismo" do
    del_menu = Rails.root.join("app/helpers/menu_helper.rb").read
                    .scan(/nombre: "([^"#]+)", icono: :\w+, ruta: (\w+)_path/)
                    .to_h { |nombre, ruta| [ ruta, nombre ] }

    # ⚠️ Los PORTALES quedan fuera. En el del representante, «Todos» es una
    # pestaña dentro de su propia navegación —«todos mis representados»— y no el
    # nombre de una sección; exigir que la pantalla se llame igual sería exigir
    # que se llame «Todos». La regla es para el menú de la administración.
    portales = %w[representante dashboards]

    distintos = VISTAS.glob("*/index.html.haml").filter_map do |indice|
      carpeta = indice.dirname.basename.to_s
      next if portales.include?(carpeta)

      nombre = del_menu[carpeta] || del_menu[carpeta.singularize]
      next if nombre.nil?

      titulo = indice.read[/^\s*%h1 (.+)$/, 1]&.strip
      next if titulo.nil? || titulo == nombre

      "#{carpeta}: el menú dice «#{nombre}» y la pantalla «#{titulo}»"
    end

    assert_empty distintos,
      "el menú promete una cosa y la pantalla dice otra:\n  " + distintos.join("\n  ")
  end

  # ── Subir una planilla se llama IGUAL en las nueve vistas ────────────────
  #
  # Daniel, señalando la pantalla de profesores con una flecha a cada botón:
  # *«mismo link, nombres distintos»*. Arriba decía «Subir materias y
  # profesores» y el del estado vacío, dos centímetros abajo, «Subir el
  # pensum». Los dos van a `/importaciones/new?tipo=pensum`.
  #
  # ⚠️ El test mira el MARCADO, no el texto renderizado, y es a propósito: lo
  # que hay que impedir es que una vista vuelva a escribir el nombre a mano. Un
  # test sobre el HTML pasaría igual el día que alguien copie el texto correcto
  # en una vista nueva, y esa copia es exactamente de donde salió la divergencia.
  test "ninguna vista escribe a mano el nombre de una planilla" do
    escritos = VISTAS.glob("**/*.haml").filter_map do |vista|
      texto = vista.read
      usados = Importacion::ACCIONES.values.select { |nombre| texto.include?(%("#{nombre}")) }
      [ vista.relative_path_from(VISTAS).to_s, usados ] if usados.any?
    end

    assert_empty escritos,
                 "El nombre de una planilla lo pone `Importacion::ACCIONES`; " \
                 "estas vistas lo escriben a mano: #{escritos.to_h}"
  end

  # Y el destino también: `boton_de_importar` lo arma con el tipo.
  test "ninguna vista arma a mano el botón de subir una planilla" do
    a_mano = VISTAS.glob("**/*.haml").select do |vista|
      vista.read.match?(/boton\s+"[^"]*[Ss]ubir[^"]*",/)
    end

    assert_empty a_mano.map { |v| v.relative_path_from(VISTAS).to_s },
                 "Se usa `boton_de_importar <tipo>`: nombre, destino, icono y tono en un solo lugar."
  end

  # ⚠️ Y hay UN glifo para la flecha que sube.
  #
  # Había dos claves —`subir` e `importar`— y la de `importar` apuntaba la
  # flecha hacia ABAJO: era `descargar` con otro nombre, o sea que la misma
  # acción se dibujaba de dos maneras y una era idéntica a la contraria.
  test "importar y descargar no comparten glifo" do
    glifos = IconosHelper::CAMINOS

    assert glifos.key?(:subir), "falta el icono `subir`"
    refute glifos.key?(:importar), "`importar` era `subir` con otro nombre: se usa `subir`"
    refute_equal glifos[:subir], glifos[:descargar],
                 "subir y descargar son acciones opuestas y no pueden verse igual"
  end

  private

  # ⚠️ El primer `%span` DESPUÉS de la cabecera, y solo dentro de ella.
  #
  # La primera versión usaba `/card-academic-header.*?%span (.+)$/m` y con `/m`
  # el punto también casa saltos de línea: se comía media vista y devolvía como
  # «botón» un bloque de veinte renglones.
  # ⚠️ Se lee del `alta:` de `shared/_cabecera_de_lista`, y esto es un ARREGLO.
  #
  # Buscaba `card-academic-header` —la cabecera vieja— y MOR-192 se la llevó de
  # las ocho vistas de listado. Desde entonces devolvía `nil` en todas, así que
  # los tres tests de este archivo pasaban por no examinar nada: el `next` los
  # saltaba en silencio. Es la misma clase de falla que la regla de CSS
  # huérfana de MOR-194 — algo deja de aplicar y no hay error que lo diga.
  #
  # Ahora el nombre vive en un solo lugar del marcado, así que se lee de ahí. El
  # botón MUESTRA «Agregar»; el nombre completo —«Registrar inscripción»— es el
  # del tooltip, que es lo que esta regla cuida.
  # ⚠️ El título de una pantalla ya no es un `%h1` suelto: desde la etapa ② lo
  # pone `shared/cabecera` (`docs/specs/cabecera-unica.md`).
  #
  # Y por eso este método existe en vez de un regex suelto: es exactamente la
  # clase de guarda que «deja de guardar en silencio» cuando el marcado cambia
  # debajo. Acá no fue silencio porque el test de arriba comprueba primero que
  # esté comprobando algo — y fue lo que avisó.
  def titulo_de(vista)
    texto = vista.read

    # Las dos formas de llamar al parcial: la simple y la que lleva bloque de
    # acciones —`render layout: … locals: { titulo: … }`—, que es la que usan
    # las pantallas con un [Volver] a la derecha.
    simple = texto[/= render "shared\/cabecera",\s*titulo: "([^"]+)"/, 1]
    return simple.strip if simple

    con_bloque = texto[/render layout: "shared\/cabecera".*?titulo: "([^"]+)"/m, 1]
    return con_bloque.strip if con_bloque

    texto[/^\s*%h1 (.+)$/, 1]&.strip
  end

  def boton_de_cabecera(indice)
    texto = indice.read

    # La cabecera nueva: el nombre viaja en el `alta:` del parcial.
    nombre = texto[/nombre: "([^"]+)"/, 1]
    return nombre if nombre

    # ⚠️ Y el alta que va como BOTÓN dentro del bloque de acciones, en vez de
    # como `alta:`. Antes esta rama leía `card-academic-header`, que desde la
    # etapa ② ya no existe en ninguna vista: `shared/cabecera` es la única.
    texto[/boton "(Registrar [^"]+)", *new_/, 1]
  end
end
