# Buscar "lopez" y encontrar a López.
#
# `ILIKE` ignora mayúsculas pero **no ignora acentos**, y nadie escribe tildes en
# un buscador. En Venezuela eso deja afuera a López, Pérez, Guzmán, Rodríguez,
# Martínez, Hernández, Díaz, Gómez — la mayoría de los apellidos del país.
#
# Lo traicionero del bug era que **funcionaba en la otra mitad**: "ramos" sí
# encontraba a Ramos, porque Ramos no lleva tilde. Se prueba con uno sin acento,
# anda, y se da por bueno (MOR-137).
#
# ## Por qué `translate()` y no `unaccent`
#
# `unaccent` es la respuesta de manual y acá **no se puede usar**: desde
# PostgreSQL 13 no es una extensión *trusted*, así que `CREATE EXTENSION` exige
# superusuario. El rol de la app es `siga_app`, que a propósito **no lo es** — un
# superusuario se salta el RLS antes de mirarlo (`MOR-87`).
#
# Meter `unaccent` significaría o bien darle privilegios al rol de la app, o bien
# sumarle un paso de superusuario al aprovisionamiento de cada base. `translate()`
# es SQL puro: no instala nada, no pide privilegios y no toca el despliegue.
class BusquedaSinAcentos
  # Los dos lados del mapa tienen que medir lo mismo: `translate()` empareja
  # carácter por carácter y descarta en silencio lo que sobra del origen.
  ACENTOS = "áàäâãéèëêíìïîóòöôõúùüûñç"
  LLANAS  = "aaaaaeeeeiiiiooooouuuunc"

  # `ñ` → `n` es una decisión, no un descuido.
  #
  # En español la eñe es una letra propia y no una ene con adorno: "año" y "ano"
  # son dos palabras muy distintas. Pero esto es un BUSCADOR de personas, y quien
  # escribe "nunez" está buscando a Núñez. Ser permisivo acá no tiene costo: el
  # falso positivo es que aparezca un apellido de más en una lista.
  #
  # Lo que NO se toca nunca es el dato guardado: el apellido de esa persona es
  # "Núñez", con eñe, y así sale en el boletín y en la certificación del MPPE.
  # Se normaliza la COMPARACIÓN, jamás lo que se escribe en la base.

  # Solo `tabla.columna` o `columna`, ambos en minúsculas. Los campos vienen de
  # constantes del código y no del usuario, pero interpolarlos sin mirar es la
  # clase de atajo que un día recibe un parámetro.
  CAMPO_VALIDO = /\A[a-z_]+(\.[a-z_]+)?\z/

  class CampoInvalido < ArgumentError; end

  # Devuelve `[sql, binds]`, listo para pasarle a `where`:
  #
  #     scope.where(*BusquedaSinAcentos.condicion(CAMPOS, params[:q]))
  #
  # El término va por bind, nunca interpolado.
  def self.condicion(campos, termino)
    campos = Array(campos)
    raise ArgumentError, "hacen falta campos donde buscar" if campos.empty?

    sql = campos.map { |campo| "#{aplanar(campo)} LIKE #{aplanar(':termino')}" }.join(" OR ")

    [sql, { termino: "%#{termino.to_s.strip}%" }]
  end

  # La misma expresión para los dos lados de la comparación. Aplicarla solo a la
  # columna arregla la mitad del problema: "López" escrito con tilde seguiría sin
  # encontrar a "lopez" guardado sin ella.
  def self.aplanar(expresion)
    validar!(expresion) unless expresion.start_with?(":")

    "translate(lower(#{expresion}), '#{ACENTOS}', '#{LLANAS}')"
  end

  def self.validar!(campo)
    return if campo.match?(CAMPO_VALIDO)

    raise CampoInvalido, "#{campo.inspect} no es un nombre de columna: se interpola en el SQL"
  end
  private_class_method :validar!
end
