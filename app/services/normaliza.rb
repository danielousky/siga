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

  # Quita acentos, baja a minúscula y colapsa espacios. Para comparar contra una
  # lista, no para guardar.
  def limpiar(valor)
    valor.to_s.strip.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/\s+/, " ")
  end
end
