class Admin < ApplicationRecord
  include SchoolScoped
  include EntraAlSistema

  # ⚠️ Los cinco son roles DENTRO de un colegio. `desarrollador` es el
  # super-admin de ESE colegio, no "gente de SIGA": eso vive en `SigaStaff`, sin
  # `school_id` (MOR-133).
  #
  # Que este enum mezclara los dos ejes es la raíz de los cuatro agujeros que
  # aparecieron en dos días. El nombre quedó por compatibilidad con los datos ya
  # cargados; lo que cambió es que ya no significa "plataforma".
  # ⚠️ `asistente` se agregó en `MOR-208`, y con el valor 5 —el siguiente libre—
  # porque un enum de enteros se rompe si se renumera: las filas ya guardadas
  # apuntan al número, no al nombre.
  #
  # Daniel, definiendo el registro: *«puedes preguntarle el cargo para saber si
  # es director o asistente. Puede ser director, asistente u otro»*. Los tres
  # existen ahora: `otro` cae en `coordinador`, que es el que ya cubría «trabaja
  # acá y no es ninguno de los otros».
  enum :role, { desarrollador: 0, director: 1, finanzas: 2, coordinador: 3,
                secretaria: 4, asistente: 5 }

  # Los cargos que se OFRECEN al registrarse, que no son los seis.
  #
  # ⚠️ Quien abre la cuenta de un colegio es quien lo dirige o quien lo ayuda a
  # dirigirlo. Ofrecerle «finanzas» o «desarrollador» en su primer minuto es
  # pedirle que entienda el modelo de permisos antes de haber entrado.
  CARGOS_AL_REGISTRARSE = {
    "director" => "Director o directora",
    "asistente" => "Asistente de dirección",
    "coordinador" => "Otro cargo"
  }.freeze

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  validates :role, presence: true
end
