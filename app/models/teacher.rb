class Teacher < ApplicationRecord
  include SchoolScoped
  # ⚠️ Por SUBCONSULTA y no por `joins`: son muchas secciones por profesor
  # y un join los duplicaría. Ver `DelNivel#llega_al_nivel_por_los`.
  llega_al_nivel_por_los TeacherSection, :teacher_id
  include EntraAlSistema
  include PuertaDeLaMuestra

  belongs_to :user
  belongs_to :school
  accepts_nested_attributes_for :user

  # Las secciones de las que es GUÍA: pasa lista y responde por esos alumnos.
  has_many :led_sections, class_name: "Section", foreign_key: :leader_teacher_id,
                          dependent: :nullify
  # Y los grados que COORDINA, que es otra cosa y casi siempre está vacío.
  has_many :coordinated_grades, class_name: "Grade", foreign_key: :coordinator_teacher_id,
                                dependent: :nullify
  has_many :teacher_sections, dependent: :restrict_with_error
  has_many :sections, through: :teacher_sections
end
