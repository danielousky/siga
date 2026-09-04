require "test_helper"

# Los rótulos de los campos salen de `es.yml`, no de las vistas.
#
# Sale de MOR-209: es la red que ese renombre demostró que faltaba.
#
# ## Por qué
#
# Renombrar `Grade#leader_teacher` a `coordinator_teacher` dejó el listado de
# grados diciendo «PROFESOR GUÍA», porque el encabezado era un literal en la
# plantilla y no contenía el nombre de ninguna columna: ningún `grep` del
# identificador lo tocaba. Lo encontró Daniel mirando la pantalla.
#
# Con el rótulo en `es.yml`, ese encabezado habría cambiado solo al editar UN
# archivo. Este test es lo que impide que los literales vuelvan a entrar de a
# poco — que es como se fueron acumulando los ochenta y nueve que había.
#
# ## Lo que este test NO pide
#
# Un literal que **difiere** de la traducción está permitido y es correcto: el
# formulario de la demo pide «Su nombre y apellido» y no «Nombre», y una
# ponderación se rotula «Peso (%)» aunque el atributo sea «Peso». La regla es
# más chica y más útil: **no repetir a mano lo que `es.yml` ya dice.** Una copia
# igual es la que se queda vieja sin que nadie se entere.
class RotulosTest < ActiveSupport::TestCase
  ETIQUETA = /\.label :([a-z_]+), "([^"#]+)"/

  test "ninguna vista repite a mano un rótulo que es.yml ya da" do
    repetidos = []

    Rails.root.glob("app/views/**/*.haml").each do |ruta|
      texto = ruta.read
      corta = ruta.to_s.sub("#{Rails.root}/", "")

      texto.scan(ETIQUETA) do |atributo, literal|
        modelos_de(ruta, texto).each do |modelo|
          next unless modelo.human_attribute_name(atributo) == literal

          repetidos << "#{corta}: `.label :#{atributo}, \"#{literal}\"` — " \
                       "es.yml ya dice eso; basta `.label :#{atributo}`"
        end
      end
    end

    assert_empty repetidos,
                 "rótulos escritos a mano que duplican es.yml:\n  " +
                 repetidos.join("\n  ")
  end

  # La otra mitad: que `es.yml` cubra de verdad a la persona. Sin esto los
  # mensajes de error salían en inglés —«First name no puede estar en blanco»—
  # aunque las pantallas se vieran perfectas, porque las vistas escribían el
  # rótulo a mano y el error no.
  test "la identidad de una persona está traducida" do
    sin_traducir = User.attribute_names.reject do |atributo|
      User.human_attribute_name(atributo) != atributo.humanize
    end - %w[id created_at updated_at]

    identidad = %w[first_name last_name second_last_name document document_type
                   cedula_escolar birth_date sex email phone]

    faltan = identidad & sin_traducir

    assert_empty faltan,
                 "sin traducir en es.yml: #{faltan.join(', ')}. El rótulo de la " \
                 "vista tapa el hueco, pero el mensaje de error sale en inglés."
  end

  private

  # `fields_for :user` es la excepción que importa: los formularios de rol
  # editan atributos de la PERSONA, no del rol.
  def modelos_de(ruta, texto)
    base = ruta.to_s.split("/")[-2].singularize.camelize.safe_constantize
    modelos = [ base ].select { |m| m.respond_to?(:human_attribute_name) }
    modelos << User if texto.include?("fields_for :user")
    modelos
  end
end
