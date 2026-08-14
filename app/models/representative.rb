# El representante de uno o más alumnos, en UN colegio (MOR-110).
#
# Refleja a `Teacher` y `Admin`: es el registro de rol, con su colegio. Una
# persona con hijos en dos colegios tiene **dos** `Representative` —igual que un
# profesor que trabaja en dos—, así cada fila pertenece a un solo inquilino y el
# aislamiento no necesita ninguna excepción.
#
# El que resuelve entre los dos es `ApplicationController#colegio_de`: ver ahí el
# comentario sobre por qué en este caso —y solo en este— el colegio puede salir
# de la sesión.
class Representative < ApplicationRecord
  include SchoolScoped

  belongs_to :user
  belongs_to :school

  has_many :student_representatives, dependent: :destroy
  has_many :students, through: :student_representatives

  validates :user_id, uniqueness: { scope: :school_id,
                                    message: "ya es representante en este colegio" }

  # Los alumnos que representa, con todo lo que la pantalla necesita, en una
  # consulta. Un representante con tres hijos abre la pantalla una vez.
  def hijos
    students.includes(user: {}, enrollments: { section: [:grade, :academic_period] })
  end

  def nombre_completo = "#{user.name} #{user.last_name}"
end
