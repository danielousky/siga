# La cara de una persona en SIGA (MOR-149).
#
# Reconocer una cara es más rápido que leer un nombre, y en una lista de 360
# alumnos con apellidos repetidos —«Pérez, Ana» y «Pérez, Ana Sofía»— eso decide
# si la secretaria hace clic en la fila correcta.
#
# ## Sin foto NO es un hueco
#
# Un colegio que carga su matrícula desde una planilla no tiene 360 fotos, y
# probablemente no las tenga nunca. Así que el caso por defecto —iniciales sobre
# un color estable— **es el avatar**, no un marcador de posición esperando algo
# mejor. Si hay foto, la reemplaza; si no, se ve igual de terminado.
#
# ## ⚠️ La paleta no puede tocar los colores semánticos
#
# En SIGA el rojo significa **niño aplazado**, el ámbar **necesita atención** y el
# verde **al día**. Si el avatar de Rodríguez sale rojo porque su apellido cayó
# ahí, el rojo deja de querer decir lo que quiere decir — y en una lista donde
# conviven avatares y notas, el ojo no distingue cuál de los dos rojos importa.
#
# Por eso estos ocho tonos son deliberadamente **fríos y terrosos**: azules,
# morados, pizarras y un marrón. Ninguno se confunde con un estado.
module AvataresHelper
  # Los ocho, todos con contraste ≥ 4.5:1 contra blanco, medido — no elegidos a
  # ojo. Es el mínimo que exige WCAG AA para texto pequeño, y las iniciales de un
  # avatar de 28 px son texto pequeño.
  COLORES = %w[
    #1F5C8B #4A5578 #6B4E71 #2F6B6B
    #7A5230 #3E5C76 #5B4B8A #445A44
  ].freeze

  TAMANOS = { mini: 24, chico: 28, normal: 36, grande: 56, ficha: 96 }.freeze

  # El avatar de una persona: su foto, o sus iniciales.
  #
  #     avatar(alumno.user)
  #     avatar(profesor.user, tamano: :grande)
  #
  # ⚠️ Va SIEMPRE con el nombre al lado en un listado. Un avatar solo, sin texto,
  # obliga a reconocer a alguien por dos letras —y «MC» son Miguel Castillo y
  # María Colmenares—. Acá el avatar acompaña, no reemplaza.
  def avatar(persona, tamano: :normal, clase: nil)
    return nil if persona.nil?

    lado = TAMANOS.fetch(tamano, TAMANOS[:normal])
    clases = [ "avatar", "avatar--#{tamano}", clase ].compact.join(" ")

    if (imagen = foto_de(persona, lado))
      return image_tag(imagen, class: clases, width: lado, height: lado,
                               alt: "", loading: "lazy",
                               style: "--avatar-lado: #{lado}px")
    end

    tag.span(iniciales_de(persona), class: clases, "aria-hidden": "true",
             style: "--avatar-lado: #{lado}px; --avatar-color: #{color_de(persona)}")
  end

  # Avatar + nombre, que es como se usa el 95 % de las veces.
  def persona_con_avatar(persona, tamano: :chico, detalle: nil)
    return nil if persona.nil?

    tag.span(class: "persona-linea") do
      safe_join([
        avatar(persona, tamano: tamano),
        tag.span(class: "persona-linea-texto") do
          safe_join([
            tag.span(persona.apellidos_y_nombres, class: "persona-linea-nombre"),
            detalle.present? ? tag.span(detalle, class: "persona-linea-detalle") : nil
          ].compact)
        end
      ])
    end
  end

  # ⚠️ Las iniciales salen del PRIMER APELLIDO y el PRIMER NOMBRE, en ese orden.
  #
  # No de las dos primeras palabras: «DE LA CRUZ MARÍN JOSÉ LUIS» daría «DL», que
  # no identifica a nadie. Y el primer apellido es el que la persona reconoce como
  # suyo —es el que verifica el SAIME— así que va primero, igual que en los
  # listados.
  def iniciales_de(persona)
    apellido = persona.last_name.to_s.strip
    nombre = persona.first_name.to_s.strip

    [ inicial(apellido), inicial(nombre) ].compact.join.presence || "·"
  end

  # ⚠️ El color se deriva del nombre, no del `id`.
  #
  # Con el `id` la misma persona cambiaría de color entre el colegio A y el
  # colegio B —son filas distintas de `students`— y en la vista consolidada de una
  # red de colegios se vería como dos personas. Con el nombre es estable en todas
  # partes, incluso antes de guardar.
  def color_de(persona)
    semilla = "#{persona.last_name}#{persona.first_name}".downcase

    COLORES[semilla.each_char.sum(&:ord) % COLORES.size]
  end

  private

  # La miniatura, si se puede generar. `variant` necesita libvips en el sistema
  # —está en el Dockerfile desde MOR-149— pero si por lo que sea falla, se cae a
  # las iniciales en vez de romper la fila.
  def foto_de(persona, lado)
    return nil unless persona.respond_to?(:foto) && persona.foto.attached?
    return persona.foto unless persona.foto.variable?

    persona.foto.variant(resize_to_fill: [ lado * 2, lado * 2 ], format: :webp)
  rescue StandardError
    nil
  end

  def inicial(palabra)
    return nil if palabra.blank?

    # Las partículas no son iniciales: «de la Cruz» empieza por C.
    limpio = palabra.split.reject { |p| Normaliza::MINUSCULAS.include?(Normaliza.limpiar(p)) }.first

    (limpio || palabra).first&.upcase
  end
end
