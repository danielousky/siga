class SubjectsController < ApplicationController
  before_action :set_subject, only: [:show, :edit, :update, :destroy]

  # Por nombre o por CÓDIGO: el colegio conoce sus materias por las dos cosas, y
  # el código es el que aparece en el horario y en el boletín.
  CAMPOS_DE_BUSQUEDA = %w[subjects.name subjects.code].freeze

  def index
    scope = Subject.includes(department: :school)
    scope = scope.where(*BusquedaSinAcentos.condicion(CAMPOS_DE_BUSQUEDA, params[:q])) if params[:q].present?

    @pagy, @subjects = pagy(scope.order(:name))
  end

  # La materia.
  #
  # Lo único que agrega esta pantalla sobre la fila de la lista es la RED: en
  # qué grados se cursa y quién la dicta. Sin eso no vale la pena abrirla — y
  # así era antes, un `dl` con el código, el nombre y el departamento, que son
  # exactamente las tres columnas del listado.
  # ⚠️ La ficha también ASIGNA, no solo informa (MOR-198).
  #
  # Daniel, mirando una materia recién creada: *«¿qué es esto? ¿Por qué no puedo
  # asignar desde allí los grados y los profes?»*. Y tenía razón: la pantalla
  # decía «no está asignada a ningún grado, así que nadie puede cargarle notas.
  # Se asigna desde el grado» —o sea, describía el problema, nombraba la
  # solución y no llevaba a ella—. Un callejón con instrucciones.
  #
  # No hay endpoints nuevos: son los mismos `grade_subjects#create` y
  # `teacher_sections#create` que ya usan las fichas del grado y de la sección,
  # vistos desde el otro lado.
  def show
    @grados = @subject.grades.order(:name)
    @quienes = TeacherSection.del_anio_de_la_sesion.where(subject_id: @subject.id)
                             .includes(:subject, teacher: :user, section: [ :grade, :academic_period ])
                             .to_a
                             .sort_by { |a| [ a.section.grade.name, a.section.name ] }

    @grados_libres = Grade.where.not(id: @subject.grade_ids).order(:name)

    # ⚠️ Solo las secciones de los grados donde ESTA materia se cursa: asignarle
    # un profesor en una sección que no la dicta crea una fila que después no
    # aparece en ningún lado. Y del año de la sesión, porque una sección es de
    # su año.
    @secciones_libres =
      Section.del_anio_de_la_sesion
             .where(grade_id: @subject.grade_ids)
             .where.not(id: TeacherSection.where(subject_id: @subject.id).select(:section_id))
             .includes(:grade).order(:name)

    @profesores = Teacher.includes(:user).to_a.sort_by { |p| p.user.apellidos_y_nombres }
  end

  def new
    @subject = Subject.new
  end

  def edit; end

  def create
    @subject = Subject.new(subject_params)
    if @subject.save
      redirect_to @subject, notice: "Materia creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @subject.update(subject_params)
      redirect_to @subject, notice: "Materia actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @subject.destroy
      redirect_to subjects_url, notice: "Materia eliminada exitosamente."
    else
      redirect_to @subject, alert: @subject.errors.full_messages.join(", ")
    end
  end

  private

  def set_subject
    @subject = Subject.find(params[:id])
  end

  def subject_params
    params.require(:subject).permit(:code, :name, :department_id)
  end
end
