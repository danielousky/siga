# Una importación de matrícula, de punta a punta (MOR-126).
#
# El nombre va en español —como `Planilla`, `EscalaLiteral` o `BusquedaSinAcentos`—
# porque toda la maquinaria del importador lo está, y mezclar `Import` con
# `Planilla` en la misma línea se lee peor que mezclar `Importacion` con
# `Student`. El plural lo aprende el inflector en `config/initializers/
# inflections.rb`, donde ya viven `solicitud` y `constancia`: con eso la tabla,
# las rutas y los helpers salen bien solos.
class Importacion < ApplicationRecord
  include SchoolScoped

  # ⚠️ El archivo trae los datos personales de 360 menores, así que no vive para
  # siempre. Ver `#purgable?` abajo.
  #
  # Active Storage no lleva RLS —igual que Solid Queue, es maquinaria de la
  # plataforma y no dato de ningún colegio—. Lo que aísla al archivo es la fila
  # que lo referencia: sin poder ver la `Importacion`, no hay cómo llegar al
  # adjunto.
  has_one_attached :archivo

  belongs_to :school
  belongs_to :subido_por, class_name: "User"

  # `cargada`      el archivo está arriba y ya se leyeron sus encabezados
  # `mapeada`      alguien dijo qué columna es cuál y vio la previsualización
  # `confirmada`   se escribió en la base; `resultado` dice qué pasó
  # `descartada`   se abandonó a mitad, o se subió otra en su lugar
  enum :estado, { cargada: 0, mapeada: 1, confirmada: 2, descartada: 3 }

  ETIQUETAS = {
    "cargada" => "Sin mapear", "mapeada" => "Lista para confirmar",
    "confirmada" => "Importada", "descartada" => "Descartada"
  }.freeze

  # Cuánto se conserva el archivo después de importarlo. Treinta días alcanzan
  # para investigar un reclamo —"a mi hijo lo pusieron en la sección
  # equivocada"— y no convierten al servidor en un archivo de datos de menores.
  CONSERVAR_EL_ARCHIVO = 30.days

  validates :nombre_del_archivo, presence: true

  scope :recientes, -> { order(created_at: :desc) }
  scope :en_curso,  -> { where(estado: [ :cargada, :mapeada ]) }

  def etiqueta_de_estado = ETIQUETAS.fetch(estado, estado)

  def terminada? = confirmada? || descartada?

  # El archivo ya no hace falta y tiene datos de menores adentro.
  def purgable? = confirmada? && updated_at < CONSERVAR_EL_ARCHIVO.ago

  # La planilla, leída. Se relee del adjunto en cada paso a propósito: la
  # previsualización tiene que mostrar exactamente lo que después se va a
  # escribir, y eso solo se garantiza leyendo la misma fuente las dos veces.
  def planilla
    @planilla ||= archivo.open do |archivo_local|
      Planilla.new(archivo_local.path, extension: File.extname(nombre_del_archivo))
    end
  end

  # El mapeo que propone el sistema, para que la persona solo corrija lo que
  # esté mal en vez de armarlo desde cero.
  def mapeo_sugerido
    planilla.encabezados.index_with { |e| ColumnasDeMatricula.para(e)&.clave&.to_s }.compact
  end

  def mapeo_efectivo = mapeo.presence || mapeo_sugerido

  # Las columnas obligatorias que nadie mapeó. Mientras haya alguna, la
  # importación no puede avanzar: rellenarlas con un valor por defecto sería
  # inventar datos de un alumno.
  def obligatorias_sin_mapear
    mapeadas = mapeo_efectivo.values.map(&:to_s)

    ColumnasDeMatricula.obligatorias.reject { |c| mapeadas.include?(c.clave.to_s) }
  end

  def lista_para_previsualizar? = obligatorias_sin_mapear.empty?
end
