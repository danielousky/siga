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

  # Cada carpeta con `index` + `new`: el botón de la cabecera y el título.
  def altas
    VISTAS.glob("*/new.html.haml").filter_map do |nueva|
      indice = nueva.dirname.join("index.html.haml")
      next unless indice.exist?

      titulo = nueva.read[/^\s*%h1 (.+)$/, 1]&.strip
      boton = boton_de_cabecera(indice)
      next if titulo.nil? || boton.nil?

      [ nueva.dirname.basename.to_s, boton, titulo ]
    end
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

  # Y el botón del estado vacío que va al MISMO sitio se llama igual que el de
  # la cabecera: es el mismo destino visto desde otro lado de la pantalla.
  test "el estado vacío llama al alta con el mismo nombre" do
    distintos = VISTAS.glob("*/index.html.haml").filter_map do |indice|
      texto = indice.read
      cabecera = boton_de_cabecera(indice)
      next if cabecera.nil?

      # `{ texto: "…", ruta: new_algo_path` — la acción que va al alta.
      vacio = texto[/texto: "([^"]+)", ruta: new_[a-z_]+_path/, 1]
      next if vacio.nil? || vacio == cabecera

      "#{indice.dirname.basename}: cabecera «#{cabecera}» vs estado vacío «#{vacio}»"
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

  private

  # ⚠️ El primer `%span` DESPUÉS de la cabecera, y solo dentro de ella.
  #
  # La primera versión usaba `/card-academic-header.*?%span (.+)$/m` y con `/m`
  # el punto también casa saltos de línea: se comía media vista y devolvía como
  # «botón» un bloque de veinte renglones.
  def boton_de_cabecera(indice)
    lineas = indice.read.lines
    desde = lineas.index { |l| l.include?("card-academic-header") }
    return nil if desde.nil?

    lineas[desde + 1, 6].to_a.filter_map { |l| l[/^\s*%span ([A-ZÁÉÍÓÚ].+)$/, 1]&.strip }.first
  end
end
