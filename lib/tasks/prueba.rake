# El ambiente de una prueba de campo con un docente de verdad (MOR-136).
#
# ## Por qué es una tarea y no un seed
#
# Los seeds arman la DEMO —dos colegios, 290 alumnos, todo lleno— que es lo que
# se le enseña a un cliente. Esto es otra cosa: un colegio **chico y limpio**
# donde una maestra pueda cargar un lapso completo sin que le estorbe nada, y
# donde lo que ella haga no se mezcle con lo que están mirando los brokers.
#
#   bin/rails prueba:campo                    # lo monta
#   bin/rails prueba:campo DOCENTE=cyndi@…    # con su correo de verdad
#   bin/rails prueba:borrar                   # lo saca entero
#
# ## ⚠️ Pasa por `AltaDeUnColegio`, no por `create!`
#
# Es el MISMO camino que recorre alguien que se registra en `/registrarse`, así
# que montar el ambiente **es también una prueba del arranque**: si el andamiaje
# se rompe, se rompe acá antes de que lo vea un cliente. Escribir las filas a
# mano sería más rápido y no probaría nada.
#
# ⚠️ Los alumnos son INVENTADOS a propósito. La prueba mide cuánto tarda y dónde
# se traba, y ninguna de las dos cosas depende de que el niño exista. Cargar
# alumnos reales metería nombres de menores en un ambiente que además se le
# muestra a terceros.
namespace :prueba do
  COLEGIO_DE_PRUEBA = "U.E. DE PRUEBA".freeze

  # ⚠️ La MARCA de lo que crea esta tarea, y es lo que hace que `borrar` sea
  # confiable. Barrer solo «lo que cuelga del colegio» dejó viva la fila del
  # director la primera vez, y con esa fila `prueba:campo` ya no vuelve a correr
  # —el correo es único global— sin decir por qué.
  DOMINIO_DE_PRUEBA = "@prueba.test".freeze
  CEDULA_DE_PRUEBA  = "PRUEBA%".freeze

  # Nombres venezolanos comunes, claramente inventados. El apellido va partido
  # porque el SAIME verifica el PRIMERO (ver `CLAUDE.md § Identidad`).
  ALUMNOS = [
    %w[Alejandro Briceño Lara], %w[Camila Delgado Guzmán], %w[Diego Fuentes Rojas],
    %w[Emilia Guerrero Silva], %w[Gabriel Herrera Pinto], %w[Isabella Jiménez Ávila],
    %w[Mateo Lugo Ferrer], %w[Sofía Márquez Ocanto], %w[Santiago Nieves Bastidas],
    %w[Valentina Ochoa Zambrano]
  ].freeze

  desc "Monta un colegio chico y limpio para una prueba de campo con un docente"
  task campo: :environment do
    SeedGuard.new.verificar!
    clave = SeedGuard.new.clave

    if Current.sin_aislamiento { School.exists?(name: COLEGIO_DE_PRUEBA) }
      abort "Ya existe «#{COLEGIO_DE_PRUEBA}». Corre `bin/rails prueba:borrar` primero."
    end

    correo_docente = ENV.fetch("DOCENTE", "cyndi@prueba.test")

    # ⚠️ UNA transacción para todo. Sin esto, un fallo a mitad de camino
    # —una cédula repetida, una materia que no está— deja medio colegio
    # escrito y `prueba:campo` se niega a correr de nuevo porque «ya existe».
    ActiveRecord::Base.transaction do
    # ── El colegio, por la puerta de verdad ────────────────────────────────
    resultado = AltaDeUnColegio.crear(
      datos_de_la_persona: { first_name: "Dirección", last_name: "De Prueba",
                             email: "director@prueba.test", password: clave,
                             password_confirmation: clave },
      datos_del_colegio: { name: COLEGIO_DE_PRUEBA, dea_code: "PRUEBA001",
                           entidad_federal: "Distrito Capital", municipio: "Libertador" },
      # ⚠️ Solo primaria: el selector de nivel NO aparece con un nivel solo, y
      # eso es lo correcto para esta prueba — la maestra no tiene que lidiar con
      # un control que no decide nada.
      niveles: [ :primaria ],
      cargo: "director"
    )
    colegio = resultado.colegio
    puts "✓ #{colegio.name} · #{resultado.andamiaje.resumen}"

    Current.en_el_colegio(colegio) do
      grado  = Grade.find_by!(name: "5to Grado")
      anio   = AcademicPeriod.en_operacion || AcademicPeriod.order(:start_date).last
      lapsos = EvaluationMoment.where(academic_period: anio).order(:id)

      seccion = Section.create!(grade: grado, academic_period: anio, name: "A",
                                capacity: 30, classroom: "Aula 5")
      puts "✓ #{grado.name} #{seccion.name} · #{anio.name} · #{lapsos.count} lapsos"

      # ── La maestra ────────────────────────────────────────────────────────
      #
      # ⚠️ Sin contraseña a propósito. Entra por el código de un solo uso, que
      # es el camino real (`MOR-143`): un profesor al que el colegio da de alta
      # NO recibe una contraseña, recibe una invitación.
      # ⚠️ Lleva cédula porque el modelo la exige: al menos UNO de `document` o
      # `cedula_escolar` (`MOR-138`). Un profesor nunca tiene cédula escolar
      # —ésa es del alumno— así que le toca la de identidad.
      #
      # Y va en un rango alto a propósito: `users.document` es único GLOBAL, así
      # que una cédula «bonita» como V-12345678 choca contra la de cualquier
      # otro colegio de la base. Pasó en la primera corrida.
      persona = User.create!(first_name: "Cyndi", last_name: "Montoya",
                             email: correo_docente,
                             document: "V-99000001", document_type: :cedula_v)
      docente = Teacher.create!(user: persona, school: colegio)

      %w[MAT LEN].each do |code|
        materia = Subject.find_by(code: code) || Subject.where("code LIKE ?", "#{code}%").first
        next if materia.nil?

        TeacherSection.create!(teacher: docente, section: seccion, subject: materia)
        puts "✓ le toca #{materia.name}"
      end

      # ── Los alumnos ───────────────────────────────────────────────────────
      ALUMNOS.each_with_index do |(nombre, apellido, segundo), i|
        usuario = User.create!(first_name: nombre, last_name: apellido,
                               second_last_name: segundo,
                               cedula_escolar: "PRUEBA#{format('%03d', i + 1)}")
        alumno = Student.create!(user: usuario, school: colegio,
                                 school_card: "P-#{format('%03d', i + 1)}")
        Enrollment.create!(student: alumno, section: seccion,
                           enrollment_date: anio.start_date)
      end
      puts "✓ #{ALUMNOS.size} alumnos inscritos (inventados)"

      # ── El código de acceso de la maestra ─────────────────────────────────
      #
      # ⚠️ `set_reset_password_token` devuelve el código EN CLARO y guarda el
      # digest. Leer `persona.reset_password_token` después devuelve el digest y
      # el enlace no abre nada — está documentado en `CLAUDE.md § 6.5`.
      codigo = persona.send(:set_reset_password_token)

      puts
      puts "  ── Para entrar ──────────────────────────────────────────────"
      puts "  Directora   director@prueba.test / #{clave}"
      # ⚠️ `/activar/:token`, NO la pantalla de Devise.
      #
      # `/users/password/edit` existe y devuelve **302**: la ruta redirige a la
      # pantalla propia de activación (`MOR-143`), que saluda por el nombre y
      # explica qué es esto. Mandar la de Devise funciona por el redirect, pero
      # si alguien la copia sin el token no lleva a ninguna parte.
      puts "  Maestra     #{correo_docente}"
      puts "              #{ENV.fetch('SIGA_HOST', 'http://localhost:3000')}/activar/#{codigo}"
      puts "              (elige su contraseña ahí; el código dura 6 horas)"
      puts "  ─────────────────────────────────────────────────────────────"
    end
    end
  end

  desc "Saca el colegio de prueba entero"
  task borrar: :environment do
    SeedGuard.new.verificar!

    colegio = Current.sin_aislamiento { School.find_by(name: COLEGIO_DE_PRUEBA) }

    Current.sin_aislamiento do
      ActiveRecord::Base.transaction do
      if colegio.nil?
        # ⚠️ Puede no haber colegio y sí quedar personas: una corrida que falló
        # a mitad, o un borrado anterior que no llegó al final. Se barre igual.
        sueltas = User.where("email LIKE ? OR cedula_escolar LIKE ?",
                             "%#{DOMINIO_DE_PRUEBA}", CEDULA_DE_PRUEBA)
        cuantas = sueltas.count
        sueltas.delete_all
        abort(cuantas.zero? ? "No hay nada que borrar." : "✓ #{cuantas} personas sueltas borradas.")
      end

      # ⚠️ De adentro hacia afuera: casi todo lleva `restrict_with_error`, que
      # existe para que nadie borre por accidente el trabajo de un lapso.
      ids = { school_id: colegio.id }
      ActivityGrade.unscoped.where(ids).delete_all
      MomentGrade.unscoped.where(ids).delete_all
      FinalGradeBook.unscoped.where(ids).delete_all
      ActivityCompetency.unscoped.where(ids).delete_all
      Indicator.unscoped.where(ids).delete_all
      Competency.unscoped.where(ids).delete_all
      EvaluationActivity.unscoped.where(ids).delete_all
      Attendance.unscoped.where(ids).delete_all
      ReportCard.unscoped.where(ids).delete_all
      Enrollment.unscoped.where(ids).delete_all
      TeacherSection.unscoped.where(ids).delete_all
      Section.unscoped.where(ids).delete_all
      EvaluationMoment.unscoped.where(ids).delete_all
      GradeSubject.unscoped.where(ids).delete_all
      Grade.unscoped.where(ids).delete_all
      Subject.unscoped.where(ids).delete_all
      Department.unscoped.where(ids).delete_all
      AcademicPeriod.unscoped.where(ids).delete_all
      Rubric.unscoped.where(ids).delete_all
      Subscription.unscoped.where(ids).delete_all
      ActivityLog.unscoped.where(ids).delete_all

      # Las PERSONAS se van solo si no tienen rol en otro colegio: una madre con
      # hijos en dos planteles es UNA fila (`MOR-138`).
      personas = (Student.unscoped.where(ids).pluck(:user_id) +
                  Teacher.unscoped.where(ids).pluck(:user_id) +
                  Admin.unscoped.where(ids).pluck(:user_id) +
                  Representative.unscoped.where(ids).pluck(:user_id)).uniq

      %w[StudentRepresentative Student Teacher Admin Representative]
        .each { |m| m.constantize.unscoped.where(ids).delete_all }

      sin_otro_rol = personas.reject do |id|
        [ Student, Teacher, Admin, Representative ].any? { |m| m.unscoped.exists?(user_id: id) }
      end

      # ⚠️ EL COLEGIO SE VA PRIMERO, y el orden no es estético.
      #
      # `schools.registrado_por_id` apunta a `users` desde `MOR-158`: quién dio
      # de alta el colegio. Borrar a esa persona antes revienta contra la clave
      # foránea con un mensaje que habla de `fk_rails_107a55d48b` y no dice
      # nada. Es la única FK que va del colegio HACIA la persona, y por eso se
      # escapa de la intuición de «borrar de adentro hacia afuera».
      colegio.destroy!

      User.unscoped.where(id: sin_otro_rol).delete_all

      # ⚠️ Y el barrido por MARCA, que es la red de seguridad: si un rol se
      # borró antes de tiempo, su persona ya no aparece por asociación y se
      # queda para siempre bloqueando el correo — que es único global.
      User.unscoped.where("email LIKE ? OR cedula_escolar LIKE ?",
                          "%#{DOMINIO_DE_PRUEBA}", CEDULA_DE_PRUEBA).delete_all
      end
    end

    puts "✓ «#{COLEGIO_DE_PRUEBA}» borrado."
  end
end
