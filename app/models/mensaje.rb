# Un correo que el colegio le escribió a una familia (MOR-186).
#
# Daniel: *«debemos permitir darle seguimiento a los correos... Simple, pero que
# al menos diga qué y cuándo se envió»*.
#
# ## ⚠️ El destinatario es un `User`, no un `Representative`
#
# El mensaje se le escribió a la PERSONA. La misma señora puede ser
# representante de su hijo y profesora del colegio, y puede dejar de ser una de
# las dos cosas sin que eso borre lo que se le escribió.
#
# ## Y el correo va CONGELADO
#
# `correo` guarda la dirección a la que de verdad se mandó, no la que la persona
# tenga hoy. Si después se corrige, el registro tiene que seguir diciendo a
# dónde fue — que es exactamente lo que se pregunta cuando alguien dice que no
# le llegó.
class Mensaje < ApplicationRecord
  include SchoolScoped

  belongs_to :school
  belongs_to :destinatario, class_name: "User"
  belongs_to :remitente, class_name: "User"

  validates :asunto, :cuerpo, :correo, presence: true

  scope :recientes, -> { order(created_at: :desc) }
  scope :para, ->(usuario) { where(destinatario_id: usuario.id) }
end
