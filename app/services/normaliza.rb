# Los campos de la planilla que se limpian sin adivinar nada (MOR-126).
#
# El nombre y la fecha tienen clase propia porque pueden equivocarse y necesitan
# decirlo. Estos no: o se entiende el valor o no se entiende, y devolver `nil`
# es respuesta suficiente.
#
# El documento no está acá: vive en `User.normalizar_documento` desde `MOR-142`,
# porque quien BUSCA a una persona lo necesita tanto como quien la guarda.
module Normaliza
  module_function

  # ⚠️ El sexo NO se puede leer celda por celda, y esto casi se me pasa.
  #
  # En Venezuela conviven tres convenciones, y en dos de ellas la MISMA letra
  # significa lo contrario:
  #
  #     M / F   masculino · femenino     ← la común
  #     V / H   varón     · hembra       ← la de las planillas del MPPE
  #     H / M   hombre    · mujer        ← la de los formularios generales
  #
  # `H` es femenino en la segunda y masculino en la tercera. `M` es masculino en
  # la primera y femenino en la tercera. Una celda suelta no alcanza para saber.
  #
  # Lo que sí alcanza es la COLUMNA entera: si aparecen `H` y `M` juntas, es
  # hombre/mujer; en cualquier otro caso, `H` es hembra. Por eso esto recibe
  # todos los valores y devuelve el mapa de una vez.
  MASCULINO = %w[m masculino v varon varón 1].freeze
  FEMENINO  = %w[f femenino h hembra mujer 2].freeze

  def sexos(valores)
    presentes = valores.map { |v| limpiar(v) }.compact_blank.uniq
    hombre_mujer = presentes.include?("h") && presentes.include?("m")

    presentes.index_with do |valor|
      if hombre_mujer && valor == "h" then :male
      elsif hombre_mujer && valor == "m" then :female
      elsif MASCULINO.include?(valor) then :male
      elsif FEMENINO.include?(valor) then :female
      end
    end
  end

  # Para una celda suelta, con la convención por defecto del MPPE. Sirve para el
  # alta manual; el importador usa `sexos` porque tiene la columna entera.
  def sexo(valor)
    sexos([ valor ]).values.first
  end

  # Un correo que no es un correo se descarta en vez de guardarse: media
  # dirección no sirve para nada y ocupa el índice único.
  #
  # La comprobación es deliberadamente floja —hay algo, un arroba, y un punto
  # después— porque la validación de verdad la hace Devise al guardar. Acá solo
  # se trata de no meter `correo-malo` ni `n/a` en la columna.
  def correo(valor)
    v = valor.to_s.strip.downcase
    return nil if v.blank?

    v.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/) ? v : nil
  end

  # El teléfono se guarda como lo escribió el colegio, solo sin espacios de más.
  # No se normaliza a un formato: en Venezuela conviven `0414-1234567`,
  # `(0212) 555-1234` y `+58 414 1234567`, y los tres sirven para llamar.
  def telefono(valor)
    valor.to_s.strip.gsub(/\s+/, " ").presence
  end

  # ── el nombre de una persona ──────────────────────────────────────────────
  #
  # Se GUARDA en mayúscula y se MUESTRA en Tipo Título.
  #
  # La mayúscula es la forma canónica porque es la de los documentos: la cédula,
  # la partida de nacimiento y las planillas del MPPE vienen así, y una planilla
  # de colegio también. Guardar lo que llegó dejaría a los alumnos importados en
  # MAYÚSCULA y a los cargados a mano en Tipo Título, desparejos en el mismo
  # listado.
  #
  # Y se muestra en Tipo Título porque «DE LA CRUZ MARÍN JOSÉ LUIS» en la
  # pantalla de una madre grita.

  # Qué letras puede tener el nombre de una persona (MOR-191).
  #
  # ⚠️ Sale de `BusquedaSinAcentos::ACENTOS`, y esa dependencia es el punto.
  #
  # El invariante es: **si se puede escribir, el buscador tiene que saber
  # aplanarlo.** Con dos listas escritas a mano se desparejan —ya lo estaban: el
  # buscador aplanaba «ç» y «ã», y el formulario no dejaba teclearlas—, y el
  # resultado es una persona que existe y no aparece al buscarla.
  #
  # Eso importa acá más que en otros países: en Venezuela hay apellidos
  # italianos y portugueses de sobra —Gonçalves, D'Angelo, João— y el que no
  # puede escribir el suyo no piensa «falta un carácter», piensa que el sistema
  # está roto.
  #
  # El guion y el apóstrofo van por la misma razón, y uno de los dos ya estaba
  # medio adentro: `capitalizar` parte por «-» para que «María-José» salga con
  # las dos mitades en mayúscula — o sea que el código sabía mostrarlo y el
  # formulario no dejaba escribirlo.
  #
  # Es el CUERPO de una clase de caracteres para el controlador `campo-filtrado`.
  # ⚠️ El guion va AL FINAL, o «ñ-'» se leería como un rango.
  LETRAS_DE_NOMBRE = "A-Za-z#{BusquedaSinAcentos::ACENTOS}#{BusquedaSinAcentos::ACENTOS.upcase} '-".freeze

  # Qué puede tener el nombre de un COLEGIO (MOR-201).
  #
  # Daniel, después de escribir «La ^}´+ Escuelita^`[]»: *«caracteres especiales
  # en el nombre»*.
  #
  # No sirve la lista de una persona: los nombres venezolanos de plantel llevan
  # puntos y números —«U.E. Colegio San José», «E.B.N. 24 de Julio», «U.E.P.
  # Nuestra Señora de Fátima»— y filtrarlos con las letras a secas dejaría
  # «UE Colegio San José», que no es como se firma un documento.
  #
  # Lo que se agrega es lo que aparece de verdad en la fachada de un colegio:
  # dígitos, el punto de las siglas, la coma, el guion, el apóstrofo y el `&` de
  # «U.E. Andrés Bello & Cía.» —que existe, y que ya tenía un test propio porque
  # es el carácter que rompe el escapado del PDF—. Fuera queda lo que Daniel
  # tecleó, que no aparece en ningún plantel del país.
  #
  # ⚠️ Es una lista de lo PERMITIDO y no de lo prohibido, como el resto de los
  # filtros: la lista de lo que no se quiere es infinita y siempre falta un
  # símbolo.
  #
  # ⚠️ El guion va AL FINAL de la clase de caracteres, o `'-0` se lee como un
  # RANGO —del apóstrofo al cero— y deja pasar medio ASCII sin que nadie lo
  # note. Por eso no se concatena con `LETRAS_DE_NOMBRE`, que ya termina en
  # guion: se arma aparte.
  LETRAS_DE_INSTITUCION =
    "A-Za-z0-9#{BusquedaSinAcentos::ACENTOS}#{BusquedaSinAcentos::ACENTOS.upcase} .,&'-".freeze

  # Partículas que NO se capitalizan cuando van en medio: «De la Cruz», no «De
  # La Cruz». `san`, `santa` y `mc` sí se capitalizan —San Martín, McDonald— y
  # por eso esta lista no es la misma que la de `NombreDePersona`.
  MINUSCULAS = %w[de del la las los y e da das dos van von].freeze

  # ⚠️ A NFC, y no es cosmético: un acento descompuesto es INVISIBLE al buscador.
  #
  # «Ó» se puede escribir de dos maneras que se ven idénticas: un carácter
  # (U+00D3) o una O seguida de una tilde combinante (U+004F U+0301). macOS
  # produce la segunda —al teclear, al pegar, y al exportar un CSV desde
  # Numbers, que es justo por donde entra una matrícula al importador.
  #
  # `BusquedaSinAcentos` aplana con `translate()`, que mapea carácter por
  # carácter los acentos PRECOMPUESTOS. La tilde suelta no está en ese mapa, así
  # que un «LÓPEZ» descompuesto se guarda bien, se ve bien en pantalla y **no lo
  # encuentra nadie**: el apellido más común del país, mudo en el buscador.
  #
  # Comprobado: aplanar el NFC da «lopez»; el NFD da «lópez».
  #
  # Se canoniza al ENTRAR, que es el único lugar donde alcanza con hacerlo una
  # vez. Y no confundir con `limpiar`, que descompone A PROPÓSITO para comparar
  # contra una lista y jamás toca lo que se guarda.
  def canonico(texto)
    texto.to_s.unicode_normalize(:nfc).strip.gsub(/\s+/, " ")
  end

  def mayuscula(texto)
    canonico(texto).upcase.presence
  end

  def titulo(texto)
    palabras = canonico(texto).downcase.split(" ")

    palabras.each_with_index.map do |palabra, i|
      i.positive? && MINUSCULAS.include?(limpiar(palabra)) ? palabra : capitalizar(palabra)
    end.join(" ")
  end

  # `capitalize` a secas deja «María-josé»: los nombres compuestos con guion
  # llevan las dos mitades en mayúscula.
  def capitalizar(palabra)
    palabra.split("-").map(&:capitalize).join("-")
  end

  # Quita acentos, baja a minúscula y colapsa espacios. Para comparar contra una
  # lista, no para guardar.
  def limpiar(valor)
    valor.to_s.strip.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/\s+/, " ")
  end
end
