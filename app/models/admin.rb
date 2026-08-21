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
  enum :role, { desarrollador: 0, director: 1, finanzas: 2, coordinador: 3, secretaria: 4 }

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  validates :role, presence: true
end
