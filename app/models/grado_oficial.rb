# Los grados que existen en Venezuela (MOR-153).
#
# ## Por qué esto es una constante y no una tabla
#
# Los grados no son una decisión del colegio: los fija el Reglamento de la LOE.
# Son quince, en ese orden, con esos nombres. Cambiarlos exigiría una reforma
# del reglamento — no una pantalla de configuración.
#
# Ponerlos en una tabla invitaría a editarlos, y a que cada colegio termine con
# su propia variante («1ero», «Primer Año», «1er. Año»), que es exactamente lo
# que hoy hace imposible emparejar una planilla importada con un grado.
#
#     preescolar     1er, 2do, 3er NIVEL      3 grados
#     primaria       1er … 6to GRADO          6 grados
#     secundaria     1er … 5to AÑO            5 grados   → Bachiller
#     media_tecnica  6to AÑO                  1 grado    → Técnico Medio
#
# ## La palabra distingue el nivel, y eso es la palanca
#
# «4to Grado» es primaria y «4to Año» es secundaria. No hay ambigüedad posible,
# así que **el nivel se DEDUCE del nombre** en vez de capturarse: un campo que
# no se llena no se puede llenar mal. Ver `Grade#nivel_y_orden_del_catalogo`.
#
# ## ⚠️ La Media Técnica son SEIS años, y por eso NO es un nivel paralelo
#
# Un colegio técnico dicta 1er a 5to Año igual que cualquier bachillerato, y
# agrega un 6to que gradúa Técnico Medio. O sea que `media_tecnica` **aporta un
# solo grado** y no seis: los cinco primeros ya existen y son los mismos.
#
# Modelarla como un nivel completo duplicaría «1er Año» … «5to Año» y chocaría
# contra el índice único de `grades.name` por colegio — con un error que no
# explica nada.
#
# De ahí `IMPLICA`: marcar Media Técnica siembra también el bachillerato,
# porque no existe un sexto año sin los cinco anteriores.
class GradoOficial
  Entrada = Data.define(:nivel, :orden, :nombre) do
    # El orden es GLOBAL, no por nivel: un colegio completo lista sus grados de
    # 1er Nivel a 6to Año, y eso tiene que salir de un `ORDER BY`.
    def to_s = nombre
  end

  NIVELES = %i[preescolar primaria secundaria media_tecnica].freeze

  # Un nivel que no puede existir solo. Marcar Media Técnica siembra también el
  # bachillerato: no hay sexto año sin los cinco anteriores.
  IMPLICA = { media_tecnica: :secundaria }.freeze

  CATALOGO = [
    [ :preescolar, "1er Nivel" ], [ :preescolar, "2do Nivel" ], [ :preescolar, "3er Nivel" ],
    [ :primaria,   "1er Grado" ], [ :primaria,   "2do Grado" ], [ :primaria,   "3er Grado" ],
    [ :primaria,   "4to Grado" ], [ :primaria,   "5to Grado" ], [ :primaria,   "6to Grado" ],
    [ :secundaria, "1er Año" ],   [ :secundaria, "2do Año" ],   [ :secundaria, "3er Año" ],
    [ :secundaria, "4to Año" ],   [ :secundaria, "5to Año" ],
    [ :media_tecnica, "6to Año" ]
  ].each_with_index.map { |(nivel, nombre), i| Entrada.new(nivel: nivel, orden: i + 1, nombre: nombre) }
                   .freeze

  # ── Los niveles que se ELIGEN, que son TRES y no cuatro ──────────────────
  #
  # El selector de la barra de contexto ofrece Preescolar, Primaria y
  # Bachillerato. **Media Técnica no es una opción**, y no es una simplificación
  # de la pantalla: es lo que dice el dominio.
  #
  # Un colegio técnico dicta 1er a 5to Año como cualquier bachillerato y agrega
  # un 6to. Si el selector ofreciera «Bachillerato» y «Media Técnica» por
  # separado, elegir «Bachillerato» **escondería el 6to Año** — que es
  # exactamente la trampa que `Grade#media?` existe para evitar, y la que dejó
  # ciega a la certificación 31059 en su momento.
  #
  #     LA OPCIÓN OFRECE     Y ABARCA
  #     ────────────────     ────────
  #     Preescolar           preescolar
  #     Primaria             primaria
  #     Bachillerato         secundaria + media_tecnica     ← las dos
  ABARCA = {
    preescolar: %i[preescolar],
    primaria: %i[primaria],
    secundaria: %i[secundaria media_tecnica]
  }.freeze

  # Etiquetas para la pantalla. El nivel se nombra como lo nombra un director,
  # no como lo nombra el enum.
  ETIQUETAS = {
    preescolar: "Preescolar",
    primaria: "Primaria",
    secundaria: "Bachillerato",
    media_tecnica: "Media Técnica"
  }.freeze

  # Lo que un director reconoce de cada nivel, para que elegir no sea adivinar.
  DESCRIPCIONES = {
    preescolar: "Tres niveles. La calificación es cualitativa.",
    primaria: "Primero a sexto grado. Boletín por literales.",
    secundaria: "Primer a quinto año. Boletín por notas del 1 al 20.",
    media_tecnica: "Agrega el sexto año, que gradúa Técnico Medio. Incluye el bachillerato."
  }.freeze

  class << self
    def de_nivel(nivel) = CATALOGO.select { |e| e.nivel == nivel.to_sym }

    # ⚠️ Expande las implicaciones: pedir Media Técnica trae también los cinco
    # años del bachillerato. Sin esto, un colegio técnico terminaría con un
    # «6to Año» suelto y sin los grados que lo preceden.
    def de_niveles(*niveles)
      pedidos = niveles.flatten.compact.map(&:to_sym)
      pedidos |= pedidos.filter_map { |n| IMPLICA[n] }

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

    # Bajo qué opción del selector cae un nivel del enum. `media_tecnica` cae
    # bajo «Bachillerato»; ver `ABARCA`.
    def se_elige_como(nivel)
      ABARCA.find { |_opcion, abarcados| abarcados.include?(nivel.to_sym) }&.first
    end

    # Qué valores del enum abarca una opción del selector. Devuelve `[]` para
    # una opción que no existe, que es lo que hace que un valor viejo guardado
    # en la sesión caiga a «todos» en vez de filtrar por nada.
    def abarcados_por(opcion) = ABARCA.fetch(opcion.to_sym, [])

    def nivel_de(nombre) = para(nombre)&.nivel
    def orden_de(nombre) = para(nombre)&.orden

    def nombres = CATALOGO.map(&:nombre)

    def normalizar(texto)
      I18n.transliterate(texto.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
