# Dos colegios completos, cada uno con TODO lo que la app sabe modelar.
#
# Es el prerrequisito de cualquier test de aislamiento, y no es un detalle: **sin
# dos inquilinos poblados, un test de aislamiento no prueba nada.** El error
# clásico es escribirlo desde adentro del colegio correcto —loguearse como admin
# de A, pedir datos de A, ver datos de A, pasar— y eso pasaría igual con el
# aislamiento apagado.
#
# Ver MOR-90.
module DosColegios
  # Un colegio con su gente y sus datos. Delega en el escenario académico lo que
  # ya sabía armar y agrega los tres roles y el rastro que deja usarlo.
  Completo = Struct.new(:escenario, :director, :profesor, :estudiante,
                        :registro_de_profesor, :registro_de_admin,
                        :actividad, :nota, :boletin, keyword_init: true) do
    def colegio     = escenario.colegio
    def periodo     = escenario.periodo
    def grado       = escenario.grado
    def seccion     = escenario.seccion
    def materia     = escenario.materia
    def alumno      = escenario.alumno
    def inscripcion = escenario.inscripcion
    def lapso(n = 1) = escenario.lapso(n)

    def departamento = materia.department
  end

  def dos_colegios_completos
    [colegio_completo("Colegio A"), colegio_completo("Colegio B")]
  end

  def colegio_completo(nombre)
    esc = escenario_academico(nombre: nombre, alumnos: 2)
    sufijo = esc.colegio.id

    con_el_colegio(esc.colegio) do
      director = usuario("dir", sufijo)
      admin    = Admin.create!(user: director, school: esc.colegio, role: :director)

      docente  = usuario("prof", sufijo)
      registro = Teacher.create!(user: docente, school: esc.colegio)
      TeacherSection.create!(teacher: registro, section: esc.seccion, subject: esc.materia)

      actividad = actividad(esc, lapso: esc.lapso(1), peso: 100, descripcion: "Examen de #{nombre}")
      nota      = nota(actividad, esc.alumno, 17)

      boletin = ReportCard.create!(
        enrollment: esc.inscripcion, evaluation_moment: esc.lapso(1), issued_by: director,
        snapshot: ReportCardData.para(enrollment: esc.inscripcion, evaluation_moment: esc.lapso(1))
      )

      Completo.new(
        escenario: esc, director: director, profesor: docente, estudiante: esc.alumno.user,
        registro_de_profesor: registro, registro_de_admin: admin,
        actividad: actividad, nota: nota, boletin: boletin
      )
    end
  end

  private

  def usuario(prefijo, sufijo)
    User.create!(
      name: prefijo.capitalize, last_name: "De#{sufijo}",
      email: "#{prefijo}.#{sufijo}@aislamiento.test", password: "123123"
    )
  end
end
