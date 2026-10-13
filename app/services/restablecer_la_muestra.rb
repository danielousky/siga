# Devuelve el colegio de muestra a su estado sembrado (spec
# `docs/specs/del-registro-al-cobro.md`, § 4.3: «se resiembra cada noche»).
#
#     1 · ¿ES la muestra?     la instancia lo declaró, Y en la base no hay
#                             ningún colegio que no sea de la muestra
#     2 · BORRAR todo         en el orden que dicta el esquema
#     3 · SEMBRAR de nuevo    los mismos seeds de siempre
#     4 · tirar los archivos  de lo que se borró
#
# ## ⚠️ Esto BORRA UNA BASE ENTERA, y por eso el primer paso son dos preguntas
#
# Ninguna alcanza sola:
#
#     LA VARIABLE   `SIGA_MUESTRA=1` — alguien la puede poner donde no debe
#     LOS DATOS     ningún colegio fuera de `Muestra::COLEGIOS` — el sitio de
#                   verdad tiene colegios de verdad, y ahí esto se niega
#
# La segunda mira lo que HAY, no lo que alguien declaró: es la que impide que
# una variable mal puesta borre a un cliente. Es la misma comprobación de
# `demo:es_solo_demo`, sin la lista de excepciones: aquí no se autoriza nada a
# mano, porque corre solo y de noche.
#
# ## ⚠️ Borrar y sembrar van en UNA transacción
#
# Con dos, una siembra que falla a la mitad deja la muestra vacía hasta que
# alguien se entere —y nadie mira una muestra a las cuatro de la mañana—. En
# una sola, si algo falla la base queda como estaba ayer: tocada por los
# visitantes, pero entera.
#
# Mientras corre, quien esté adentro sigue viendo los datos de ayer —PostgreSQL
# no le enseña a nadie una transacción a medias— y al terminar su sesión deja
# de valer: las personas nacen de nuevo, con otro número.
#
# ## ⚠️ Los archivos se tiran DESPUÉS, y solo si todo salió bien
#
# Un archivo borrado no vuelve con un `ROLLBACK`. Por eso primero se anota qué
# había, y recién con la transacción confirmada se borra del disco: si la
# siembra falla, las filas de ayer vuelven y sus archivos siguen ahí.
class RestablecerLaMuestra
  class NoEsLaMuestra < StandardError; end

  # Las tablas de los adjuntos. `OrdenDeBorrado` las deja fuera a propósito
  # —limpiar la demo vieja de producción no podía tocar los archivos de nadie—;
  # aquí todo archivo es de la muestra, y dejarlos sería sumar los escudos y los
  # comprobantes de cada noche, para siempre.
  ADJUNTOS = %w[active_storage_attachments active_storage_variant_records active_storage_blobs].freeze

  def self.ahora!(...) = new(...).ahora!

  # `siembra` es lo que vuelve a llenar la base. Se puede pasar otra cosa para
  # probar el borrado y la vuelta atrás sin esperar el minuto que tarda sembrar.
  def initialize(salida: $stdout, siembra: -> { Rails.application.load_seed })
    @salida = salida
    @siembra = siembra
  end

  def ahora!
    comprobar_que_es_la_muestra!

    viejos = llaves_de_los_archivos

    Current.sin_aislamiento do
      # `requires_new`: si ya hubiera una transacción abierta —la de un test, la
      # de quien lo llame desde otra— esta tiene que poder deshacerse SOLA.
      ActiveRecord::Base.transaction(requires_new: true) do
        borrar_todo
        @siembra.call
      end
    end

    tirar(viejos)
    @salida.puts "✅ La muestra volvió a su estado sembrado."
    true
  end

  # Público porque también lo pregunta quien solo quiere saber, sin tocar nada.
  def comprobar_que_es_la_muestra!
    unless Muestra.activa?
      raise NoEsLaMuestra, "Esta instancia no se declaró muestra (#{Muestra::VARIABLE}=1). No se toca nada."
    end

    ajenos = Current.sin_aislamiento { School.where.not(dea_code: Muestra::COLEGIOS).order(:id).pluck(:name, :dea_code) }
    return if ajenos.empty?

    raise NoEsLaMuestra,
          "En esta base hay colegios que NO son de la muestra: " \
          "#{ajenos.map { |nombre, dea| "#{nombre} (#{dea})" }.join(', ')}. " \
          "Restablecer los borraría. No se toca nada."
  end

  private

  def conexion = ActiveRecord::Base.connection

  def llaves_de_los_archivos
    conexion.select_values("SELECT key FROM active_storage_blobs")
  end

  def borrar_todo
    (ADJUNTOS + OrdenDeBorrado.calcular).each do |tabla|
      conexion.execute("DELETE FROM #{conexion.quote_table_name(tabla)}")
    end

    # ⚠️ Los ajustes de la plataforma NO se borran con lo demás —ver
    # `OrdenDeBorrado`—, pero los datos para pagar aquí son de EJEMPLO: los
    # seeds los vuelven a escribir, y lo que un visitante hubiera logrado
    # cambiar no amanece.
    #
    # `setup` sí se queda: el WhatsApp de la muestra es el de verdad, y quien lo
    # puso no tiene por qué volver a ponerlo cada mañana.
    conexion.execute("DELETE FROM siga_settings")
  end

  # Lo que quedó en el disco de la base de ayer.
  def tirar(llaves)
    servicio = ActiveStorage::Blob.service

    llaves.each do |llave|
      servicio.delete(llave)
      servicio.delete_prefixed("variants/#{llave}/")
    rescue StandardError => e
      # Un archivo que no se pudo borrar no deshace una muestra que ya está
      # sembrada: se anota y se sigue.
      Rails.logger.warn("[RestablecerLaMuestra] no se pudo borrar #{llave}: #{e.class}: #{e.message}")
    end
  end
end
