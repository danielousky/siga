class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # El MPPE acepta cuatro documentos, no uno. `cedula_e` es la cédula de un
  # extranjero residente, no un tipo de documento distinto: por eso la
  # nacionalidad NO es un campo aparte — ya está acá, y duplicarla sería invitar
  # a que se contradigan.
  enum :document_type, { cedula_v: 0, cedula_e: 1, pasaporte: 2, carne_diplomatico: 3 }

  DOCUMENT_TYPE_LABELS = {
    "cedula_v"          => "Cédula de identidad (V)",
    "cedula_e"          => "Cédula de identidad (E)",
    "pasaporte"         => "Pasaporte",
    "carne_diplomatico" => "Carné diplomático"
  }.freeze

  enum :sex, { female: 0, male: 1 }

  SEX_LABELS = { "female" => "Femenino", "male" => "Masculino" }.freeze

  has_one :address, dependent: :destroy
  has_one :student, dependent: :destroy
  has_one :teacher, dependent: :destroy
  has_one :admin, dependent: :destroy

  validates :document,       uniqueness: true, allow_nil: true
  validates :cedula_escolar, uniqueness: true, allow_nil: true
  validates :first_name, :last_name, presence: true
  validate  :tiene_algun_identificador

  # Nombre completo con los dos apellidos: "Álvaro José López Medina".
  #
  # Vive acá y no en cada vista porque el segundo apellido es opcional, y
  # `"#{first_name} #{last_name} #{second_last_name}"` deja un espacio colgando
  # cuando falta. Se veía en pantalla.
  def nombre_completo
    [ first_name, apellidos ].compact_blank.join(" ")
  end

  def apellidos
    [ last_name, second_last_name ].compact_blank.join(" ")
  end

  # Cómo se identifica esta persona, con lo que tenga.
  #
  # El MPPE resuelve esto igual: en sus planillas, "en el espacio correspondiente
  # a la Cédula de Identidad se registrará el Número de la Cédula Escolar" cuando
  # el alumno no tiene la primera.
  def identificador
    document.presence || cedula_escolar
  end

  def identificador_etiqueta
    return DOCUMENT_TYPE_LABELS[document_type] if document.present?
    "Cédula escolar" if cedula_escolar.present?
  end

  private

  # Una persona sin ningún identificador no puede aparecer en una planilla del
  # MPPE, así que tampoco debería poder existir acá.
  #
  # No es `presence` sobre ninguno de los dos por separado: un alumno de primaria
  # normalmente NO tiene cédula, y un profesor NUNCA tiene cédula escolar.
  def tiene_algun_identificador
    return if document.present? || cedula_escolar.present?

    errors.add(:base, "Hace falta la cédula de identidad o la cédula escolar")
  end
end
