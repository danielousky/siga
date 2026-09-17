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
  # ⚠️ Las TRES dan permisos de dirección, y «Otro cargo» mapeaba a
  # `coordinador`, que NO los tiene.
  #
  # Quien abre la cuenta de un colegio es su PRIMER administrador, y no hay
  # nadie más que pueda darle permisos: eligiendo «Otro cargo» quedaba
  # encerrada —sin poder cargar profesores, ni tocar la configuración académica,
  # ni entrar a `/administradores` para corregirse el rol—. Un callejón sin
  # salida en el minuto uno.
  #
  # Le pasó a Yoleima, la primera directora real que registró un colegio.
  #
  # ⚠️ El cargo sigue siendo un DATO —qué es esta persona en el colegio— y por
  # eso se guarda distinto; lo que no puede es decidir si puede trabajar. El
  # día que el colegio tenga varios administradores, el director reparte los
  # roles acotados desde `/administradores`.
  CARGOS_AL_REGISTRARSE = {
    "director" => "Director o directora",
    "asistente" => "Asistente de dirección",
    "otro" => "Otro cargo"
  }.freeze

  # ⚠️ «otro» no es un valor del enum: es una etiqueta del formulario. Se guarda
  # como `asistente`, que es el rol de dirección sin ser el director.
  CARGO_AL_ROL = { "director" => "director", "asistente" => "asistente",
                   "otro" => "asistente" }.freeze

  def self.rol_al_registrarse(cargo) = CARGO_AL_ROL.fetch(cargo.to_s, "asistente")

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  validates :role, presence: true
end
