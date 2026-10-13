class Enrollment < ApplicationRecord
  include SchoolScoped

  enum :status, { regular: 0, retirado: 1 }

  belongs_to :section
  belongs_to :student, foreign_key: :student_id
  llega_al_anio_por :section
  llega_al_nivel_por section: :grade
  # ⚠️ De la inscripción MÁS NUEVA a la más vieja, por el año escolar.
  #
  # El panel del alumno ordenaba por `grades.name`, y eso es correcto DENTRO de
  # un año y desastroso entre varios: un muchacho de 5to Año abría SIGA y veía
  # las notas de 1er Año de hace tres años, porque «1er» ordena antes que «5to».
  # Es la pantalla que ve una familia.
  #
  # Hoy no se nota porque cada colegio tiene un año escolar. Se rompe el día que
  # haya dos — o sea, en cuanto se pueda clonar el año.
  scope :recientes_primero, -> {
    joins(section: :academic_period).order("academic_periods.start_date DESC")
  }

  # La LISTA DE CLASE: los inscritos regulares, en el orden en que se pasa lista.
  #
  #     Enrollment.en_orden_de_lista(seccion.enrollments)
  #     Enrollment.en_orden_de_lista(Enrollment.where(section_id: ids))
  #
  # ## ⚠️ Estaba escrita CINCO veces, y en DOS órdenes distintos
  #
  #     pestaña «Alumnos»    ORDER BY users.last_name    ← SQL, PRIMER apellido
  #     informes             sort_by apellidos_y_nombres ← Ruby, LOS DOS
  #     la libreta                    ídem
  #     Educación Inicial             ídem
  #     el Excel de la lista          ídem
  #
  # El primero no tenía desempate, y los apellidos repetidos abundan: «3er Grado
  # A» tiene cinco pares. Con eso, la pantalla y el Excel que se baja DE esa
  # pantalla podían numerar distinto al mismo niño — «la número 12» no era la
  # misma niña en los dos papeles.
  #
  # ## ⚠️ El orden va en RUBY y no en SQL, y es a propósito
  #
  # `apellidos_y_nombres` es un método —arma «López Medina, Álvaro» con los dos
  # apellidos— y no una columna, así que no hay `ORDER BY` que lo produzca. Y el
  # `ORDER BY` de PostgreSQL usa el `collation` de la base, que en un contenedor
  # suele ser `C`: byte a byte, con todos los acentos al final.
  def self.en_orden_de_lista(desde = all)
    desde.where(status: :regular)
         .includes(student: :user)
         .to_a
         .sort_by { |inscripcion| inscripcion.student.user.clave_alfabetica }
  end

  derives_school_from :student
  validates_same_school :section

  has_many :moment_grades, dependent: :restrict_with_error
  has_many :final_grade_books, dependent: :restrict_with_error

  validates :enrollment_date, presence: true
  validates :student_id, uniqueness: { scope: :section_id }

  # ⚠️ Editar una inscripción es moverla de sección DENTRO DEL GRADO, o
  # retirarla: nada más. Daniel, 13 de octubre de 2026, con el desplegable de
  # «Editar» abierto en la muestra —veintidós secciones de los tres niveles—:
  # *«deberían aparecer solo las secciones del año correspondiente. Es decir,
  # es solo cambio de sección o retiro»*.
  #
  # Pasarla a otro grado o a otro año escolar no la corrige: la vuelve otra
  # inscripción, con las notas de un grado colgando de otro que no las dio.
  # Para eso se retira y se inscribe de nuevo. El formulario ya ofrece solo
  # las hermanas (`secciones_hermanas`); esto es para lo que llegue por otra
  # puerta.
  validate :el_cambio_de_seccion_es_dentro_del_grado, on: :update

  # Las secciones a las que se puede mover: las del mismo grado en el mismo año
  # escolar, la suya incluida. Las de la sección GUARDADA: si el formulario
  # vuelve con un error, la que se intentó no cambia qué se ofrece.
  def secciones_hermanas
    actual = Section.find_by(id: section_id_in_database) || section
    Section.where(grade_id: actual.grade_id, academic_period_id: actual.academic_period_id)
           .includes(:grade).order(:name)
  end

  # Las materias que van en el boletín de este alumno (MOR-211).
  #
  # ## ⚠️ Es una UNIÓN, y la segunda mitad NO es opcional
  #
  # Lo natural sería `section.materias_dictadas` y listo. Deja el boletín
  # histórico VACÍO: `CargaDeHistorial` escribe la persona, la inscripción y las
  # notas, y **no crea `TeacherSection`** — no sabe quién dictó Biología en 2019
  # y no tiene por qué inventarlo.
  #
  # Derivando solo de quién dicta, se perdería de vista exactamente lo que el
  # importador vino a cargar: diez años de historial se verían en blanco, sin un
  # solo error que lo avisara. Por eso también cuentan las materias que TIENEN
  # nota para este alumno: una nota es prueba de que esa materia se vio.
  def materias_del_boletin
    ids = section.materias_dictadas.ids |
          MomentGrade.where(enrollment_id: id).distinct.pluck(:subject_id) |
          FinalGradeBook.where(enrollment_id: id).distinct.pluck(:subject_id)

    Subject.where(id: ids).order(:name)
  end

  private

  def el_cambio_de_seccion_es_dentro_del_grado
    return unless will_save_change_to_section_id? && section

    antes = Section.find_by(id: section_id_in_database)
    return if antes.nil?
    return if section.grade_id == antes.grade_id && section.academic_period_id == antes.academic_period_id

    errors.add(:base, "La sección nueva tiene que ser de #{antes.grade.name}, en " \
                      "#{antes.academic_period.name}: pasar a otro grado o a otro año escolar " \
                      "es otra inscripción. Retire esta e inscriba de nuevo.")
  end
end
