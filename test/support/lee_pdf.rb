# Leer lo que dice un PDF de Prawn, sin una gema que lea PDF.
#
# ## Por qué existe
#
# Durante meses los tests de los documentos comprobaron que el archivo
# empezara por `%PDF`. Con eso pasaron en verde un boletín con las competencias
# a un tamaño de letra que nadie pidió, un pie cortado contra el borde de la
# hoja y un certificado de sección que podía repetir al primer alumno en todas
# sus páginas. Ninguno de los tres «fallaba»: se veían mal, y un test que no
# mira no ve.
#
# ## Cómo se puede leer
#
# Prawn escribe las órdenes de dibujo SIN comprimir, así que están a la vista:
#
#     BT                              empieza un texto
#     72.0 700.5 Td                   en esta coordenada
#     /F1.0 9 Tf                      con esta fuente y este tamaño
#     [<416c756d> 12 <6e6f>] TJ       «Alum» + «no», en hexadecimal
#     ET
#
#     72.0 650.0 468.0 18.4 re        un rectángulo: x, y de ABAJO, ancho, alto
#
# Los bytes del texto son Windows-1252 —lo que cubren las fuentes de fábrica de
# Prawn— y se pasan a UTF-8 para poder comparar «PROSECUCIÓN» con su acento.
#
# ⚠️ Sirve mientras el documento use las fuentes de fábrica. Con una TTF
# embebida los textos pasan a ser índices de glifo, y esto deja de leerlos: el
# día que se embeba una, estos tests tienen que fallar — no pasar a ciegas.
module LeePdf
  Texto = Data.define(:pagina, :x, :y, :size, :negrita, :texto)

  # Lo mínimo de una hoja para saber si está bien repartida: con qué texto
  # empieza, y de dónde a dónde llega lo pintado.
  Hoja = Data.define(:empieza, :arriba, :abajo) do
    def ocupado = arriba - abajo
  end

  # El texto de cada página, de corrido y en el orden en que se dibujó.
  def paginas_de(pdf)
    contenidos_de(pdf).map { |contenido| textos_del(contenido).map(&:last).join }
  end

  # Cada texto con su sitio, su tamaño y si va en negrita.
  def textos_de(pdf)
    negritas = fuentes_en_negrita(pdf)

    contenidos_de(pdf).each_with_index.flat_map do |contenido, pagina|
      textos_del(contenido).map do |x, y, fuente, size, texto|
        Texto.new(pagina: pagina + 1, x: x, y: y, size: size, negrita: negritas.include?(fuente), texto: texto)
      end
    end
  end

  # Lo más bajo que se pinta en todo el documento, en puntos desde el borde de
  # abajo de la hoja: un rectángulo o el renglón de un texto.
  def lo_mas_bajo_de(pdf)
    contenidos_de(pdf).flat_map { |contenido| alturas_del(contenido) }.min
  end

  # Cada hoja, resumida. Es lo que usan los tests que barren cientos de
  # largos: decodifica UN texto por hoja —el primero— en vez de todos, que es
  # donde se iba la mitad del tiempo de esos tests.
  def hojas_de(pdf)
    contenidos_de(pdf).map do |contenido|
      primero = contenido[%r{BT\n-?[\d.]+ -?[\d.]+ Td\n/F[\d.]+ [\d.]+ Tf\n\[(.*?)\] TJ}m, 1].to_s
      rectangulos = contenido.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\b/)
      renglones   = contenido.scan(/(-?[\d.]+) (-?[\d.]+) Td\b/).map { |_, y| y.to_f }

      Hoja.new(empieza: en_claro(primero),
               arriba: (rectangulos.map { |_, y, _, alto| y.to_f + alto.to_f } + renglones).max,
               abajo:  (rectangulos.map { |_, y, _, _| y.to_f } + renglones).min)
    end
  end

  # Los rectángulos RELLENOS de todo el documento, como `[x, y, ancho, alto]`.
  # Un borde también es un rectángulo, pero se traza (`S`); un fondo se rellena
  # (`f`). Es lo que deja contar cuántas bandas pinta una barra.
  def rellenos_de(pdf)
    contenidos_de(pdf).flat_map do |contenido|
      contenido.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\nf\b/).map { |medidas| medidas.map(&:to_f) }
    end
  end

  # De dónde a dónde llega lo pintado en cada página: `[lo más alto, lo más bajo]`.
  def extension_de(pdf)
    contenidos_de(pdf).map do |contenido|
      rectangulos = contenido.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\b/)
      textos      = contenido.scan(/(-?[\d.]+) (-?[\d.]+) Td\b/).map { |_, y| y.to_f }

      [ (rectangulos.map { |_, y, _, alto| y.to_f + alto.to_f } + textos).max, alturas_del(contenido).min ]
    end
  end

  private

  # El flujo de órdenes de cada página. Los otros `stream` del archivo son
  # imágenes y fuentes: no tienen ningún `BT`.
  def contenidos_de(pdf)
    pdf.b.scan(/stream\r?\n(.*?)endstream/m).map(&:first).select { |contenido| contenido.include?("BT\n") }
  end

  def textos_del(contenido)
    contenido.scan(%r{BT\n(-?[\d.]+) (-?[\d.]+) Td\n/(F[\d.]+) ([\d.]+) Tf\n\[(.*?)\] TJ}m).map do |x, y, fuente, size, trozos|
      [ x.to_f, y.to_f, fuente, size.to_f, en_claro(trozos) ]
    end
  end

  # Los trozos en hexadecimal de un `TJ`, juntos y en UTF-8.
  def en_claro(trozos)
    trozos.scan(/<([0-9a-f]+)>/i).map { |(hex)| [ hex ].pack("H*") }.join
          .force_encoding("Windows-1252").encode("UTF-8")
  end

  def alturas_del(contenido)
    contenido.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) re\b/).map { |_, y, _, _| y.to_f } +
      contenido.scan(/(-?[\d.]+) (-?[\d.]+) Td\b/).map { |_, y| y.to_f }
  end

  # Qué `/F…` del documento son la negrita. Prawn las numera en el orden en que
  # se usan, así que no se puede asumir que la 2 sea la negrita.
  def fuentes_en_negrita(pdf)
    pdf.b.scan(%r{/(F\d+\.\d+) (\d+) 0 R}).select do |_, objeto|
      pdf.b[/\n#{objeto} 0 obj\n<<.*?>>/m].to_s.include?("-Bold")
    end.map(&:first)
  end
end
