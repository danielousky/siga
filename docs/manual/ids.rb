# Los ids que necesita `capturar.rb`, buscados por NOMBRE en la siembra de hoy.
#
#     bin/rails runner docs/manual/ids.rb    # → un JSON
#
# ⚠️ Estuvieron escritos a mano en `capturar.rb` —`PRIM, INI, MED = 76, 73, 85`—
# y cambian con cada `db:seed`. El 13 de octubre de 2026 ya no existía ninguno, y
# las capturas del manual seguían mostrando una siembra de septiembre. Daniel,
# ese día: *«el manual… actualizarlo siempre»*.
#
# Los personajes son los de la muestra (`Muestra::CUENTAS`): el director, García
# —guía de 5to Grado B, donde además dicta Matemática— y Andreína Suárez, con un
# hijo en cada nivel.
require "json"

Current.sin_aislamiento do
  colegio = School.unscoped.find_by!(name: "U.E. SIMÓN BOLÍVAR")

  Current.en_el_colegio(colegio) do
    anio   = AcademicPeriod.en_operacion
    lapsos = EvaluationMoment.where(academic_period: anio).order(:id).to_a
    garcia = User.find_by!(email: "profesor.bolivar@mail.com").teachers.first
    del_anio = Section.where(academic_period: anio).includes(:grade)

    # Primaria, guiada por García y con su Matemática: la misma sección sale en
    # «Soy guía de» y en «Dicto», que es lo que la captura del panel enseña.
    prim = del_anio.find { |s| s.leader_teacher_id == garcia.id && s.grade.primaria? }
    area = TeacherSection.find_by!(teacher: garcia, section: prim).subject
    actividad = EvaluationActivity.where(section: prim, subject: area, evaluation_moment: lapsos.first)
                                  .order(:date_scheduled).first
    vacio = lapsos.find { |l| !EvaluationActivity.exists?(section: prim, subject: area, evaluation_moment: l) }

    inicial = del_anio.find { |s| s.grade.califica_con_texto? }
    media   = del_anio.select { |s| s.grade.media? }.min_by { |s| [ s.grade.orden.to_i, s.name ] }

    representante = Representative.find_by!(user: User.find_by!(email: "representante.bolivar@mail.com"))
    hijos = StudentRepresentative.where(representative_id: representante.id).map(&:student)
    alumno = hijos.find { |h| h.enrollments.joins(section: :grade).where(sections: { academic_period_id: anio.id }).any? { |e| e.section.grade.media? } } || hijos.first

    puts({
      anio: anio.id, prim: prim.id, area: area.id, actividad: actividad.id, lapso_vacio: vacio&.id,
      inscripcion: Enrollment.en_orden_de_lista(prim.enrollments).first.id,
      inicial: inicial.id, media: media.id, alumno: alumno.id, representante: representante.id,
      profesora_de_inicial: inicial.leader_teacher.user.email
    }.to_json)
  end
end
