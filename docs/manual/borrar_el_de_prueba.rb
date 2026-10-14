# Saca el colegio que `capturar.rb` registró para fotografiar la puesta en
# marcha.
#
# ⚠️ Se busca por el CORREO DE QUIEN LO REGISTRÓ, no por el nombre del colegio.
# El nombre tiene que parecer real —sale impreso en tres capturas del manual— y
# un nombre creíble puede ser el de alguien. El correo lleva el sello de la hora
# y el dominio @siga.test: no es de nadie.
correo = ARGV.first.to_s
abort("Falta el correo del registrador.") if correo.empty?
abort("Solo se borran los de @siga.test, y ese no lo es.") unless correo.end_with?("@siga.test")

# El orden es el de `prueba:borrar`, y no es estético: casi todo lleva
# `dependent: :restrict_with_error`, que existe justamente para que nadie borre
# por accidente el trabajo de un lapso.
ADENTRO_HACIA_AFUERA = %w[
  ActivityGrade MomentGrade FinalGradeBook ActivityCompetency Indicator Competency
  EvaluationActivity Attendance ReportCard Enrollment TeacherSection Section
  EvaluationMoment GradeSubject Grade Subject Department AcademicPeriod
  Rubric Subscription ActivityLog
].freeze

Current.sin_aislamiento do
  registrador = User.find_by(email: correo)
  abort("No está #{correo}: nada que borrar.") if registrador.nil?

  colegios = School.where(registrado_por_id: registrador.id)
  abort("#{correo} no registró ningún colegio.") if colegios.empty?
  marcas = [ "gid://siga/User/#{registrador.id}", *colegios.map { |c| "gid://siga/School/#{c.id}" } ]

  colegios.each do |colegio|
    ActiveRecord::Base.transaction do
      ids = { school_id: colegio.id }
      ADENTRO_HACIA_AFUERA.each { |m| m.constantize.unscoped.where(ids).delete_all }

      personas = %w[Student Teacher Admin Representative]
                 .flat_map { |m| m.constantize.unscoped.where(ids).pluck(:user_id) }.uniq
      %w[StudentRepresentative Student Teacher Admin Representative]
        .each { |m| m.constantize.unscoped.where(ids).delete_all }

      # Una persona con rol en OTRO colegio se queda: es UNA fila (MOR-138).
      sin_otro_rol = personas.reject do |uid|
        [ Student, Teacher, Admin, Representative ].any? { |m| m.unscoped.exists?(user_id: uid) }
      end

      # ⚠️ El colegio ANTES que su registrador: `schools.registrado_por_id` es
      # la única clave foránea que va del colegio HACIA la persona, y al revés
      # revienta contra un `fk_rails_…` que no explica nada.
      colegio.destroy!
      User.unscoped.where(id: sin_otro_rol).delete_all
    end
    puts "  ✓ «#{colegio.name}» borrado"
  end

  # ⚠️ Y los correos que el registro dejó en la cola (14 de octubre de 2026).
  # Registrarse encola dos —la bienvenida y el aviso a SIGA— y en desarrollo
  # no suele haber worker que los mande: quedaban esperando a una persona que
  # ya no existe, y el primer worker que arrancaba —el del humo de `bin/ci`—
  # los contaba como fallidos, con un `DeserializationError` que no decía de
  # dónde venían.
  pendientes = SolidQueue::Job.where(finished_at: nil).select do |trabajo|
    marcas.any? { |marca| trabajo.arguments.to_s.include?(marca) }
  end
  pendientes.each(&:destroy)
  puts "  ✓ #{pendientes.size} correos del registro, fuera de la cola" if pendientes.any?

  User.unscoped.where(email: correo).delete_all
end
