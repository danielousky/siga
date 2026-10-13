# Los ajustes sueltos de la plataforma (`Setup`), desde la consola (spec
# `docs/specs/del-registro-al-cobro.md`, decisiones 35 y 36).
#
#     bin/rails ajustes:estado                                  qué vale cada uno, sin tocar nada
#     AJUSTE=paypal VALOR=pagos@ejemplo.com bin/rails ajustes:poner
#     AJUSTE=paypal VALOR= bin/rails ajustes:poner              lo vacía: «no hay»
#
# Lo normal es `/siga/ajustes`. Esto es para donde nadie puede entrar ahí —la
# muestra, cuyo equipo lleva una clave al azar— y para dejarlos puestos al
# desplegar, sin esperar a que el fundador abra la pantalla.
#
# ⚠️ Pasa por el MISMO modelo que la pantalla: limpia y valida igual, y un valor
# mal escrito no se guarda.
#
# ⚠️ En producción, las variables NO van en la línea del `run` —el `env` del
# contenedor parte el valor en el primer espacio—: se ponen con
# `config:set --no-restart`, se corre, y se quitan. Ver
# `docs/tareas-de-operacion.md`.
namespace :ajustes do
  desc "Qué vale cada ajuste suelto (Setup), y de dónde sale. No toca nada."
  task estado: :environment do
    puts ""
    Setup::CAMPOS.each_key do |nombre|
      fila = Setup.fila(nombre)
      origen = if fila then "guardado"
               elsif nombre == "whatsapp" && Setup.whatsapp then "de SIGA_WHATSAPP, mientras nadie lo guarde"
               else "sin cargar"
               end
      valor = nombre == "whatsapp" ? Setup.whatsapp : Setup.valor(nombre)
      puts format("  %-18s %-34s %s", nombre, valor || "—", origen)
    end
    puts ""
  end

  desc "Pone un ajuste suelto: AJUSTE=<nombre> VALOR=<valor>. Sin VALOR, lo vacía."
  task poner: :environment do
    nombre = ENV["AJUSTE"].to_s.strip
    unless Setup::CAMPOS.key?(nombre)
      abort "❌ AJUSTE tiene que ser uno de estos: #{Setup::CAMPOS.keys.join(', ')}."
    end

    fila = Setup.para_guardar({ nombre => ENV["VALOR"].to_s }, por: nil).first
    abort "❌ #{nombre}: #{fila.errors.full_messages.to_sentence}" unless fila.save

    puts "✅ #{nombre}: #{fila.valor.presence || '— (vacío: no se ofrece)'}"
  end
end
