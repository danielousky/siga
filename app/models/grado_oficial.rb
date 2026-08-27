# Los grados que existen en Venezuela (MOR-153).
#
# ## Por qué esto es una constante y no una tabla
#
# Los grados no son una decisión del colegio: los fija el Reglamento de la LOE.
# Son catorce, en ese orden, con esos nombres. Cambiarlos exigiría una reforma
# del reglamento — no una pantalla de configuración.
#
# Ponerlos en una tabla invitaría a editarlos, y a que cada colegio termine con
# su propia variante («1ero», «Primer Año», «1er. Año»), que es exactamente lo
# que hoy hace imposible emparejar una planilla importada con un grado.
#
#     preescolar   1er, 2do, 3er NIVEL      3 grados
#     primaria     1er … 6to GRADO          6 grados
#     secundaria   1er … 5to AÑO            5 grados
#
# ## La palabra distingue el nivel, y eso es la palanca
#
# «4to Grado» es primaria y «4to Año» es secundaria. No hay ambigüedad posible,
# así que **el nivel se DEDUCE del nombre** en vez de capturarse: un campo que
# no se llena no se puede llenar mal. Ver `Grade#nivel_y_orden_del_catalogo`.
#
# ## ⚠️ Decisión pendiente: la Educación Media Técnica
#
# La Media Técnica son SEIS años y gradúa Técnico Medio, así que un colegio que
# la dicte tiene un «6to Año» que este catálogo no contempla. No está incluido a
# propósito: agregar un nivel que no sé si algún colegio de la cartera dicta es
# peor que dejar la constancia de que falta. El día que haga falta, es una fila
# más en `CATALOGO` y una entrada más en el enum de `Grade#level`.
class GradoOficial
  Entrada = Data.define(:nivel, :orden, :nombre) do
    # El orden es GLOBAL, no por nivel: un colegio completo lista sus catorce
    # grados de 1er Nivel a 5to Año, y eso tiene que salir de un `ORDER BY`.
    def to_s = nombre
  end

  NIVELES = %i[preescolar primaria secundaria].freeze

  CATALOGO = [
    [ :preescolar, "1er Nivel" ], [ :preescolar, "2do Nivel" ], [ :preescolar, "3er Nivel" ],
    [ :primaria,   "1er Grado" ], [ :primaria,   "2do Grado" ], [ :primaria,   "3er Grado" ],
    [ :primaria,   "4to Grado" ], [ :primaria,   "5to Grado" ], [ :primaria,   "6to Grado" ],
    [ :secundaria, "1er Año" ],   [ :secundaria, "2do Año" ],   [ :secundaria, "3er Año" ],
    [ :secundaria, "4to Año" ],   [ :secundaria, "5to Año" ]
  ].each_with_index.map { |(nivel, nombre), i| Entrada.new(nivel: nivel, orden: i + 1, nombre: nombre) }
                   .freeze

  # Etiquetas para la pantalla. El nivel se nombra como lo nombra un director,
  # no como lo nombra el enum.
  ETIQUETAS = {
    preescolar: "Preescolar",
    primaria: "Primaria",
    secundaria: "Bachillerato"
  }.freeze

  # Lo que un director reconoce de cada nivel, para que elegir no sea adivinar.
  DESCRIPCIONES = {
    preescolar: "Tres niveles. La calificación es cualitativa.",
    primaria: "Primero a sexto grado. Boletín por literales.",
    secundaria: "Primer a quinto año. Boletín por notas del 1 al 20."
  }.freeze

  class << self
    def de_nivel(nivel) = CATALOGO.select { |e| e.nivel == nivel.to_sym }

    def de_niveles(*niveles)
      pedidos = niveles.flatten.compact.map(&:to_sym)
      CATALOGO.select { |e| pedidos.include?(e.nivel) }
    end

    # Busca por nombre, tolerando cómo lo escribió una persona: «1ER AÑO»,
    # «1er año» y «1er  Año» son el mismo grado.
    #
    # ⚠️ Esta tolerancia es la que le sirve al importador. Sin ella, una planilla
    # con «5TO AÑO» en mayúsculas no empareja con nada y el colegio ve un grado
    # que «falta» estando cargado.
    def para(nombre)
      buscado = normalizar(nombre)

      CATALOGO.find { |e| normalizar(e.nombre) == buscado }
    end

    def nivel_de(nombre) = para(nombre)&.nivel
    def orden_de(nombre) = para(nombre)&.orden

    def nombres = CATALOGO.map(&:nombre)

    def normalizar(texto)
      I18n.transliterate(texto.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
