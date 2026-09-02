# Mirar una cuenta de producción sin abrir una consola (MOR-200).
#
# ## Por qué existe
#
# Daniel se quedó sin poder entrar y diagnosticarlo requería `dokku run … bin/rails
# runner "…"`, que **no funciona**: la orden pasa por dos shells y el segundo se
# come los `|` de los bloques y las comillas de la interpolación. Se pierden
# quince minutos peleando con el escape justo cuando alguien está afuera.
#
# Acá la orden no lleva comillas: `bin/rails soporte:cuentas`.
#
# ## ⚠️ Solo LEE
#
# No cambia contraseñas, no borra roles y no toca correos. Lo que muestra son
# los correos y los roles de un colegio —datos que un director ya ve en su
# panel— y nada de alumnos ni notas. Cualquier arreglo se hace a la vista, con
# una orden aparte y decidida por una persona.
namespace :soporte do
  desc "Lista los usuarios con acceso de un colegio (por defecto, el último creado)"
  task cuentas: :environment do
    Current.sin_aislamiento do
      colegios = ENV["COLEGIO"] ? School.where(id: ENV["COLEGIO"]) : School.order(:id).last(2)

      colegios.each do |colegio|
        puts "\n══ #{colegio.name}  (id #{colegio.id}, DEA #{colegio.dea_code})"
        puts "   registrado por: #{colegio.registrado_por&.email || '—'}"

        { "ADMIN" => Admin, "PROFESOR" => Teacher, "REPRESENTANTE" => Representative }.each do |etiqueta, clase|
          clase.unscoped.where(school_id: colegio.id).includes(:user).each do |rol|
            u = rol.user
            extra = etiqueta == "ADMIN" ? " rol=#{rol.role}" : ""
            puts "   #{etiqueta.ljust(14)} user##{u.id}  #{u.apellidos_y_nombres}"
            puts "   #{' ' * 14} correo=#{u.email.inspect}  clave=#{u.encrypted_password.present?}  cédula=#{u.document.inspect}#{extra}"
          end
        end
      end

      # ⚠️ Lo que causó el incidente: UNA persona con varios roles en el mismo
      # colegio. Es legítimo —un director puede ser representante de su hijo—
      # pero cuando aparece sin que nadie lo haya querido, es la fusión que
      # producía la búsqueda por correo.
      puts "\n══ Personas con más de un rol en el mismo colegio"
      %w[admins teachers representatives students].each do |tabla|
        ActiveRecord::Base.connection.select_all(<<~SQL.squish).each do |fila|
          SELECT user_id, school_id, COUNT(*) AS cuantos FROM #{tabla}
          GROUP BY user_id, school_id HAVING COUNT(*) > 1
        SQL
          puts "   #{tabla}: user##{fila['user_id']} tiene #{fila['cuantos']} filas en el colegio #{fila['school_id']}"
        end
      end
    end
  end

  # Quitarle a una persona un rol que no debería tener.
  #
  # ⚠️ Existe por el incidente de `MOR-200`: buscar personas por correo fusionó
  # al director con un «representante nuevo», y esa fila de más queda ahí
  # después de arreglar la causa. Un rol sobrante no es cosmético — le da a esa
  # persona una entrada al portal de representantes que nadie le quiso dar.
  #
  # ⚠️ Pide los TRES datos explícitos y no adivina ninguno. Una tarea de soporte
  # que borra por nombre o por «el último» es la que un día borra el que no era:
  #
  #     bin/rails soporte:quitar_rol ROL=representative USUARIO=630 COLEGIO=5
  #
  # Y no borra la persona ni sus datos: solo la fila del rol.
  desc "Quita UN rol de UNA persona en UN colegio (ROL, USUARIO, COLEGIO)"
  task quitar_rol: :environment do
    clases = { "representative" => Representative, "teacher" => Teacher,
               "admin" => Admin, "student" => Student }
    clase = clases[ENV["ROL"].to_s.downcase]
    abort "ROL debe ser uno de: #{clases.keys.join(', ')}" if clase.nil?
    abort "Faltan USUARIO y COLEGIO" if ENV["USUARIO"].blank? || ENV["COLEGIO"].blank?

    Current.sin_aislamiento do
      filas = clase.unscoped.where(user_id: ENV["USUARIO"], school_id: ENV["COLEGIO"])
      abort "No hay ningún #{clase.name} de user##{ENV['USUARIO']} en el colegio #{ENV['COLEGIO']}" if filas.empty?

      filas.each do |fila|
        puts "  quitando #{clase.name}##{fila.id} — #{fila.user.apellidos_y_nombres} en #{fila.school.name}"
        fila.destroy!
      end

      puts "  ✓ listo. La persona y sus otros roles quedan intactos."
    end
  end
end
