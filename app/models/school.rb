class School < ApplicationRecord
  # Quién dio de alta este colegio (MOR-158).
  #
  # Es la semilla de `Account`: el día que la cuenta exista, este usuario es su
  # dueño natural. Se guarda ahora porque después es imposible de reconstruir —
  # el primer `Admin` puede haberse ido, o pueden ser tres, y ninguno dice quién
  # fue el que se registró.
  #
  # `optional` de verdad: los colegios que da de alta el equipo de SIGA no tienen
  # a nadie que se haya registrado.
  belongs_to :registrado_por, class_name: "User", optional: true

  # Qué niveles dicta este colegio, deducido de los grados que tiene cargados.
  #
  # ## Por qué no es una columna
  #
  # Sería un segundo lugar donde vive la misma verdad, y los dos se irían
  # separando: el colegio agrega preescolar, crea sus tres niveles, y la columna
  # sigue diciendo que no lo dicta. Los grados SON la respuesta.
  #
  # El único momento en que hace falta preguntarlo es el primer día, cuando
  # todavía no hay grados — y ahí es una pregunta del asistente de arranque, no
  # un campo que se guarda. Ver `SembrarGrados`.
  def niveles
    grades.distinct.pluck(:level).compact.map(&:to_sym)
          .sort_by { |n| GradoOficial::NIVELES.index(n) || 99 }
  end

  def dicta?(nivel) = niveles.include?(nivel.to_sym)

  # Los pasos de la puesta en marcha que este colegio decidió no hacer.
  #
  # ⚠️ Es lo ÚNICO que el arranque guarda. Todo lo demás se deduce de los datos
  # —¿hay grados?, ¿hay período?— porque una bandera se queda vieja el día que
  # nadie se acuerda de moverla. «No aplica» es la excepción honesta: un colegio
  # sin departamentos se ve idéntico a uno que todavía no los cargó.
  def omitio_paso?(clave) = pasos_omitidos.include?(clave.to_s)

  def omitir_paso!(clave)
    update!(pasos_omitidos: (pasos_omitidos | [ clave.to_s ]))
  end

  def retomar_paso!(clave)
    update!(pasos_omitidos: (pasos_omitidos - [ clave.to_s ]))
  end
  # El logotipo del colegio: su identidad, y tiene que aparecer en todos lados
  # —incluidos los documentos oficiales que la familia se lleva en la mano.
  #
  # Un boletín con el escudo del colegio ES el boletín del colegio. Sin él, el
  # papel parece de la empresa de software, y lo que el colegio está entregando
  # es SU documento.
  #
  # ## Por qué archivo adjunto y no una URL
  #
  # Una URL apunta a un servidor ajeno: el día que el colegio rehace su web, el
  # logo desaparece de todos los boletines ya emitidos. Y en un PDF hace falta
  # el archivo, no un enlace — Prawn dibuja bytes.
  has_one_attached :logo

  # La firma del director, escaneada (MOR-135).
  #
  # ⚠️ **Esto NO es una firma digital.** Es un facsímil: una imagen de la firma
  # manuscrita, igual que el sello que un colegio estampa en el papel. No
  # certifica nada por sí misma —cualquiera que tenga el PDF puede recortarla— y
  # no hay que venderla como si lo hiciera.
  #
  # Lo que SÍ da autenticidad en este boletín es el **código de verificación**:
  # un tercero entra a `/verificar/CÓDIGO` —o escanea el QR— y ve lo que el
  # colegio emitió, contra la base. La firma escaneada es lo que hace que el
  # papel se vea como el papel que la familia espera; la verificación es lo que
  # lo hace comprobable.
  has_one_attached :firma

  # El sello húmedo del colegio, escaneado (MOR-135).
  #
  # En el papel el sello se estampa **sobre** la firma, no al lado: se solapan
  # a propósito, porque un sello junto a una firma en blanco se puede recortar
  # y pegar en otro documento. Acá se dibuja igual — encima, corrido y con algo
  # de transparencia, como queda la tinta sobre el bolígrafo.
  #
  # Vale la misma advertencia que para la firma: **es un facsímil**. Lo que hace
  # comprobable el boletín es su código de verificación y el QR.
  has_one_attached :sello

  FORMATOS_DE_IMAGEN = %w[image/png image/jpeg].freeze
  PESO_MAXIMO = 2.megabytes

  # Se mantienen los nombres viejos: `MOR-135` los dejó usados en la vista de
  # identidad del colegio y renombrarlos no agrega nada.
  FORMATOS_DE_LOGO = FORMATOS_DE_IMAGEN
  PESO_MAXIMO_DEL_LOGO = PESO_MAXIMO

  validate :logo_dibujable
  validate :firma_dibujable
  validate :sello_dibujable

  # Lo que Prawn puede dibujar en un PDF, o `nil`.
  #
  # Devuelve `nil` en vez de explotar a propósito: un documento oficial no se
  # puede caer porque alguien subió una imagen rara. Sale sin escudo, que es feo
  # pero sirve; sin boletín, la familia se queda sin nada.
  def logo_para_pdf  = imagen_para_pdf(logo)
  def firma_para_pdf = imagen_para_pdf(firma)
  def sello_para_pdf = imagen_para_pdf(sello)

  private

  def imagen_para_pdf(adjunto)
    return nil unless adjunto.attached?
    return nil unless FORMATOS_DE_IMAGEN.include?(adjunto.blob.content_type)

    StringIO.new(adjunto.blob.download)
  rescue StandardError
    nil
  end

  def logo_dibujable  = validar_imagen(logo, :logo, "Un escudo")
  def firma_dibujable = validar_imagen(firma, :firma, "Una firma escaneada")
  def sello_dibujable = validar_imagen(sello, :sello, "Un sello escaneado")

  def validar_imagen(adjunto, campo, que)
    return unless adjunto.attached?

    unless FORMATOS_DE_IMAGEN.include?(adjunto.blob.content_type)
      errors.add(campo, "tiene que ser PNG o JPG: son los formatos que se pueden imprimir en el boletín")
    end

    return unless adjunto.blob.byte_size > PESO_MAXIMO

    errors.add(campo, "no puede pesar más de 2 MB — #{que} no lo necesita, y la conexión de un colegio sí")
  end
  # ⚠️ `school_type` NO alcanza para describir un colegio, y por eso ya casi no
  # se usa (MOR-153).
  #
  # Es excluyente —o primaria o secundaria— y un colegio venezolano corriente
  # dicta preescolar Y primaria Y bachillerato. Se conserva porque el MPPE lo
  # pide en algunos formatos y porque hay filas cargadas con él.
  #
  # Lo que el colegio dicta de verdad se DEDUCE de sus grados: ver `#niveles`.
  enum :school_type, { primary: 0, secondary: 1 }


  has_many :departments, dependent: :restrict_with_error
  has_many :students, dependent: :restrict_with_error
  has_many :teachers, dependent: :restrict_with_error
  has_many :admins, dependent: :restrict_with_error
  has_many :academic_periods, dependent: :restrict_with_error
  has_many :grades, dependent: :restrict_with_error
  has_many :subjects, dependent: :restrict_with_error

  validates :dea_code, presence: true, uniqueness: true
  validates :name, :location, :school_type, presence: true
end
