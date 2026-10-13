# El colegio de muestra (spec `docs/specs/del-registro-al-cobro.md`, § 4.3).
#
#     bin/rails muestra:restablecer    borra TODO y vuelve a sembrar
#     bin/rails muestra:estado         qué hay, sin tocar nada
#
# ⚠️ Solo corren en la instancia que se declaró muestra (`SIGA_MUESTRA=1`) y
# cuya base no tiene ningún colegio de verdad. Las dos condiciones las
# comprueba `RestablecerLaMuestra`, no esta tarea: son las mismas para el
# trabajo que la corre cada noche.
#
# Es una tarea y no un comando suelto por lo mismo que las de `demo.rake`:
# `dokku run` parte la orden por espacios, y una tarea es un solo token.
namespace :muestra do
  desc "Devuelve la muestra a su estado sembrado. Solo en la instancia de muestra."
  task restablecer: :environment do
    RestablecerLaMuestra.ahora!
  rescue RestablecerLaMuestra::NoEsLaMuestra => e
    abort "\n🚫 #{e.message}\n"
  end

  desc "Qué hay en la muestra y si sus puertas abren, sin tocar nada"
  task estado: :environment do
    puts ""
    puts "MUESTRA        #{Muestra.activa? ? 'declarada' : 'NO declarada'} (#{Muestra::VARIABLE})"

    Current.sin_aislamiento do
      puts "COLEGIOS       #{School.order(:id).map { |c| "#{c.name} (#{c.dea_code})" }.join(' · ').presence || 'ninguno'}"
      puts "PERSONAS       #{User.count}"
      puts "ALUMNOS        #{Student.unscoped.count}"
      puts "NOTAS          #{ActivityGrade.unscoped.count}"
      puts ""
      puts "PUERTAS"
      Muestra::TODAS.each do |cuenta|
        abre = Muestra.usuario_de(cuenta).present?
        puts format("  %-3s %-16s %s", abre ? "✓" : "✗", cuenta.clave, cuenta.correo)
      end
    end
    puts ""
  end
end
