class School < ApplicationRecord
  # ⚠️ Cuántas materias aplazadas puede arrastrar un alumno (MOR-169).
  #
  # La referencia venezolana son DOS, y en el último año ninguna —no se egresa
  # debiendo—. Pero los mecanismos los fijan circulares del MPPE que cambian, y
  # en primaria la norma es menos clara. Se propone 2 y el colegio lo corrige.
  #
  # Cero es válido y significa «aplazó una, repite». Seis es el tope de arriba
  # porque más que eso no es arrastrar: es no evaluar.
  validates :tope_de_arrastre,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 6 }

  # ⚠️ Lo público va ACÁ ARRIBA. Este modelo tiene un `private` temprano —antes
  # incluso de los `enum`— y cualquier método que caiga después queda privado sin
  # que nada avise hasta que una vista lo llama. Pasó tres veces en un mismo día.

  # Qué dicta el colegio, escrito para una persona (MOR-160).
  #
  # «Preescolar y Primaria» · «Bachillerato y Media Técnica» · «Bachillerato».
  #
  # ⚠️ Un colegio recién creado devuelve nil, y eso NO es un error: todavía no
  # dijo qué dicta. Distinguirlo de «primaria» es justamente el punto — en el
  # panel de SIGA delata al colegio que se registró y se quedó a medias.
  def que_dicta
    return nil if niveles.empty?

    niveles.map { |n| GradoOficial.etiqueta(n) }
           .to_sentence(two_words_connector: " y ", last_word_connector: " y ")
  end
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

  # La rúbrica con que este colegio traduce una nota a un nivel (MOR-136).
  # Sin filas, la boleta muestra el número — que es lo que hace hoy.
  has_many :rubrics, -> { en_orden }, dependent: :destroy, inverse_of: :school

  # ⚠️ Los cinco niveles se editan JUNTOS, en una sola pantalla y un solo
  # guardado. No es comodidad: una rúbrica es una escalera, y sus peldaños solo
  # tienen sentido unos respecto de otros —«PA» cubre de 17 a 18 *porque* «PC»
  # empieza en 19—. Editándolos de a uno, el colegio pasa por estados donde la
  # escalera tiene un hueco o un solape, y esos estados se pueden guardar.
  #
  # `allow_destroy` porque el colegio de TRES niveles es un caso real y tiene
  # que poder borrar dos filas en el mismo guardado en que ajusta las otras.
  accepts_nested_attributes_for :rubrics, allow_destroy: true,
                                reject_if: ->(a) { a[:code].blank? && a[:name].blank? }

  # Deja la rúbrica en la propuesta de SIGA. Es lo que ofrece el botón de
  # «Restablecer», y lo que usa la siembra.
  #
  # ⚠️ Borra y vuelve a crear, en una transacción. Actualizar en su lugar
  # obligaría a emparejar filas por código —y el colegio pudo renombrarlos— con
  # el riesgo de chocar contra el índice único de `valor` a mitad de camino.
  def restablecer_la_rubrica!
    transaction do
      rubrics.destroy_all
      Rubric::POR_DEFECTO.each { |datos| rubrics.create!(datos) }
    end
    rubrics.reload
  end

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
  # ⚠️ `Grade.unscoped.where(school_id:)` y NO `grades`, y la diferencia importa.
  #
  # `Grade` es `SchoolScoped`: su `default_scope` filtra por `Current.school_id`.
  # Preguntarle los niveles a un colegio que NO es el de la sesión devolvía cero
  # filas —y por lo tanto `nil`— sin ningún error. Justo lo que hace el panel de
  # SIGA, que lista todos los colegios de la plataforma.
  #
  # Pidiendo el `school_id` explícito, quien decide qué se puede leer es el RLS,
  # que es la capa que corresponde: un director que intente los grados de otro
  # colegio recibe cero filas de la BASE, no un filtro de la app que se puede
  # saltar. Es exactamente el reparto de las dos capas.
  def niveles
    Grade.unscoped.where(school_id: id).distinct.pluck(:level).compact.map(&:to_sym)
         .sort_by { |n| GradoOficial::NIVELES.index(n) || 99 }
  end

  def dicta?(nivel) = niveles.include?(nivel.to_sym)

  # Los niveles que este colegio puede ELEGIR en la barra de contexto.
  #
  # ⚠️ No es lo mismo que `niveles`, y la diferencia es el colegio técnico: sus
  # grados son `secundaria` y `media_tecnica`, pero el selector ofrece una sola
  # opción —«Bachillerato»— que abarca las dos. Ver `GradoOficial::ABARCA`.
  #
  # Con una sola opción el selector no se dibuja: no hay nada que elegir.
  def niveles_para_elegir
    niveles.filter_map { |n| GradoOficial.se_elige_como(n) }.uniq
  end

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

  # El nombre en MAYÚSCULA y el código sin lo que no es letra ni número.
  #
  # ⚠️ El nombre NO se muestra en Tipo Título como el de una persona o una
  # materia (`MOR-188`), y es a propósito: los nombres de colegio venezolanos
  # empiezan por una sigla —«U.E.», «E.B.N.», «C.E.I.»— y `titulo` la
  # destrozaría («U.e.»). Acá la mayúscula es la forma de mostrar Y la de
  # guardar.
  def normalizar_el_nombre
    self.name     = Normaliza.mayuscula(name)
    # ⚠️ ASCII, no `[[:alnum:]]` (MOR-201). En Ruby esa clase incluye la Ñ y las
    # vocales acentuadas, así que «ÑPPD01» pasaba como código válido. Un código se
    # compara y se imprime en una planilla del MPPE: si admite acentos, dos
    # códigos que se leen igual son distintos para el índice único.
    self.dea_code = dea_code.to_s.gsub(/[^A-Za-z0-9]/, "").upcase.presence
  end

  # ⚠️ Se deduce SIEMPRE, y antes solo si estaba en blanco (MOR-208).
  #
  # Mientras hubo un campo «Ubicación» tenía sentido respetar lo escrito a mano.
  # Ese campo se fue —preguntaba lo mismo que el estado y el municipio, diez
  # centímetros más arriba— así que ya no hay nada que respetar: si se deja el
  # valor viejo, un colegio que corrige su municipio sigue mostrando el anterior
  # en la barra de arriba, para siempre y sin manera de arreglarlo.
  #
  # Solo se pisa cuando hay de dónde deducir: un colegio sin ubicación cargada
  # conserva la que traía.
  def deducir_la_ubicacion
    deducida = [ municipio, entidad_federal ].compact_blank.join(", ").presence
    self.location = deducida if deducida
  end

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

  has_many :departments, dependent: :restrict_with_error
  has_many :students, dependent: :restrict_with_error
  has_many :teachers, dependent: :restrict_with_error
  has_many :admins, dependent: :restrict_with_error
  has_many :academic_periods, dependent: :restrict_with_error
  has_many :grades, dependent: :restrict_with_error
  has_many :subjects, dependent: :restrict_with_error

  # ⚠️ El código DEA es un CÓDIGO (MOR-201).
  #
  # Daniel, después de escribir «--ñp´^`«+» en el campo: *«para el código DEA no
  # creo que incluya caracteres especiales»*. No los incluye: lo asigna el MPPE
  # y tiene la forma «PD01234567» —letras y dígitos—. Es la misma regla que el
  # código de una materia (`MOR-185`), y por la misma razón: un código se
  # compara, se busca y se imprime en una planilla; un acento o un guion bajo lo
  # vuelven otro código.
  #
  # No se valida el LARGO ni el prefijo: el MPPE los ha cambiado, y rechazar un
  # código correcto porque nuestro patrón envejeció deja al colegio sin poder
  # registrarse.
  validates :dea_code, presence: true, uniqueness: true,
                       format: { with: /\A[A-Za-z0-9]+\z/,
                                 message: "solo admite letras y números, sin espacios ni símbolos" }
  # ⚠️ `location` dejó de ser obligatorio (MOR-208).
  #
  # El registro pide lo mínimo —nombre, código DEA y qué dicta— y la ubicación
  # se completa después, en la identidad del colegio. Exigirla acá haría fallar
  # el alta con un error sobre un campo que la persona no vio nunca; y eso ya
  # pasó una vez, cuando la ciudad salió del formulario en `MOR-196` y el error
  # decía «Ubicación no puede estar en blanco».
  #
  # Se sigue DEDUCIENDO del municipio y el estado en cuanto los haya, y las
  # vistas ya la tratan como opcional (`if Current.school&.location.present?`).
  validates :name, presence: true
  validates :name, format: { with: /\A[#{Normaliza::LETRAS_DE_INSTITUCION}]+\z/,
                             message: "solo admite letras, números y los signos . , & \u2019 -" },
                   allow_blank: true

  # ⚠️ La ciudad NO se pregunta si ya se preguntó dónde queda (MOR-196).
  #
  # Daniel: *«no pidas Ciudad si ya estás pidiendo el resto de los datos»*. Y
  # tenía razón: el formulario pedía «Ciudad», y tres campos más abajo el
  # estado, el municipio y la parroquia. Es la misma pregunta hecha dos veces,
  # que es justo lo que `MOR-159` ya había sacado de esta pantalla con «qué
  # dicta el colegio».
  #
  # `location` no se borra porque no es redundante para MOSTRAR: es lo que sale
  # en la barra de arriba y en el panel de SIGA, donde «Libertador, Distrito
  # Capital» se lee de un vistazo y tres columnas no. Se deduce, y sigue siendo
  # editable en la ficha del colegio para el que prefiera decir «Caracas».
  before_validation :normalizar_el_nombre
  before_validation :deducir_la_ubicacion
end
