# La constancia de estudios.
#
# El documento que más pide una familia venezolana y que ningún sistema barato
# emite: lo escribe la secretaría en Word, uno por uno, cada vez. Se solicita
# para el pasaporte, para una beca, para el seguro, para una embajada, para
# mudarse de colegio — y siempre "para mañana".
#
# ## Es distinto del boletín, y por eso no lo hereda
#
# El boletín **certifica calificaciones** y por eso congela un snapshot: lo que
# decía en diciembre tiene que seguir diciéndolo en marzo (`MOR-98`).
#
# La constancia **certifica una situación de hoy**: que esta persona está inscrita
# en este grado, en este año escolar, en este colegio. Si mañana cambia de
# sección, la constancia de mañana dice lo nuevo — y eso es correcto. Por eso se
# dibuja de la base y no de un archivo.
#
# > Congelarla sería un error: emitirla dos veces con seis meses de diferencia y
# > que las dos digan lo mismo cuando el alumno cambió de grado convierte un
# > documento en un papel falso.
#
# Reusa `ReportCardPdf.texto` y `representable?`: la limitación de las fuentes de
# Prawn con los alfabetos que Windows-1252 no cubre es exactamente la misma, y
# duplicar ese comentario sería duplicar la trampa.
class ConstanciaDeEstudiosPdf
  MARGEN = 54

  # ⚠️ Recibe las CONSTANCIAS EMITIDAS, no las inscripciones.
  #
  # Cada una trae su código de verificación, que es lo que le da al papel un QR
  # que un tercero puede escanear. Antes recibía inscripciones y el documento
  # salía sin manera de comprobarlo.
  def initialize(constancias)
    @constancias = Array(constancias)
  end

  def render
    documento = Prawn::Document.new(page_size: "LETTER", margin: MARGEN, info: {
      Title: "Constancia de estudios", Creator: "SIGA", CreationDate: Time.current
    })

    @constancias.each_with_index do |constancia, i|
      documento.start_new_page if i.positive?
      pagina(documento, constancia)
    end

    documento.render
  end

  private

  def pagina(pdf, constancia)
    inscripcion = constancia.enrollment
    colegio = inscripcion.section.grade.school
    alumno  = inscripcion.student

    membrete(pdf, colegio)
    titulo(pdf)
    cuerpo(pdf, colegio, alumno, inscripcion)
    firma(pdf, colegio)
    verificacion(pdf, constancia)
  end

  # El código de verificación con su QR, igual que en el boletín.
  #
  # ⚠️ El QR lleva la URL COMPLETA: un papel impreso no tiene contexto, y
  # «/verificar/CON-…» no le sirve a nadie que lo escanee.
  #
  # ⚠️ Y el texto dice qué se comprueba, que NO es lo mismo que el boletín: una
  # constancia dice la situación del día en que se emitió. El verificador
  # confirma que el colegio emitió ESE papel ESE día — no que hoy siga siendo
  # cierto. Prometer lo otro sería mentir en un documento.
  def verificacion(pdf, constancia)
    host = ENV.fetch("SIGA_HOST", "localhost:3000")
    url = "https://#{host}/verificar/#{constancia.code}"
    alto = pdf.cursor

    pdf.bounding_box([ 0, alto ], width: pdf.bounds.width - 70, height: 44) do
      pdf.text "Código de verificación: <b>#{constancia.code}</b>", size: 8, inline_format: true
      pdf.move_down 2
      pdf.text "Escanee el código o entre a #{url} para comprobar que este documento " \
               "fue emitido por el plantel el " \
               "#{I18n.l(constancia.created_at.to_date, format: :long)}.",
               size: 7, color: "666666"
    end

    qr(pdf, url, en: [ pdf.bounds.width - 58, alto + 4 ], lado: 54)
  end

  # El QR como VECTORES y no como imagen: sale nítido a cualquier tamaño de
  # impresión y no arrastra una gema de imágenes al PDF.
  #
  # ⚠️ La zona de silencio —el margen blanco— no es decorativa: sin ella muchos
  # lectores no enganchan el código. El estándar pide cuatro módulos.
  def qr(pdf, texto, en:, lado:)
    matriz = RQRCodeCore::QRCode.new(texto, level: :m)
    modulos = matriz.module_count
    silencio = 4
    paso = lado.to_f / (modulos + silencio * 2)

    pdf.fill_color "000000"
    modulos.times do |fila|
      modulos.times do |columna|
        next unless matriz.checked?(fila, columna)

        pdf.fill_rectangle([ en[0] + (columna + silencio) * paso,
                             en[1] - (fila + silencio) * paso ], paso, paso)
      end
    end
  end

  def membrete(pdf, colegio)
    escudo = colegio.logo_para_pdf
    if escudo
      pdf.bounding_box([0, pdf.cursor + 4], width: 64, height: 50) do
        pdf.image escudo, fit: [60, 48], position: :left, vposition: :top
      rescue StandardError
        nil
      end
    end

    pdf.text texto(colegio.name).upcase, size: 15, style: :bold, align: :center
    pdf.text texto(colegio.location.to_s), size: 9, align: :center, color: "666666"
    pdf.text "Código DEA #{texto(colegio.dea_code)}", size: 9, align: :center, color: "666666"
    pdf.move_down 6
    pdf.stroke_horizontal_rule
    pdf.move_down 40
  end

  def titulo(pdf)
    pdf.text "CONSTANCIA DE ESTUDIOS", size: 16, style: :bold, align: :center,
             character_spacing: 1.5
    pdf.move_down 36
  end

  # El texto va en un solo párrafo justificado, como el documento en papel que
  # esto reemplaza. Una secretaria tiene que poder leerlo y reconocerlo.
  def cuerpo(pdf, colegio, alumno, inscripcion)
    seccion = inscripcion.section
    quien   = "#{alumno.user.nombre_completo}"
    cedula  = alumno.user.document.presence
    carnet  = alumno.school_card.presence

    identificacion = if cedula
                       "titular de la cédula de identidad N° #{seguro(cedula)}"
                     elsif carnet
                       "con cédula escolar N° #{seguro(carnet)}"
                     else
                       "identificado(a) en los registros de esta institución"
                     end

    pdf.text <<~TEXTO.squish, size: 12, align: :justify, leading: 6, inline_format: true
      Quien suscribe, Director(a) de #{seguro(colegio.name)}, hace constar por medio
      de la presente que el(la) estudiante <b>#{seguro(quien)}</b>,
      #{identificacion}, cursa estudios en esta institución en el
      <b>#{seguro(seccion.grade.name)}</b>, sección <b>#{seguro(seccion.name)}</b>,
      durante el año escolar <b>#{seguro(seccion.academic_period.name)}</b>.
    TEXTO

    pdf.move_down 20

    pdf.text <<~TEXTO.squish, size: 12, align: :justify, leading: 6, inline_format: true
      Constancia que se expide a petición de la parte interesada, en
      #{seguro(ciudad(colegio))}, a los #{dia_en_letras} días del mes de
      #{mes_en_letras} de #{Date.current.year}.
    TEXTO
  end

  # Texto de la base, listo para entrar en un párrafo con `inline_format: true`.
  #
  # ⚠️ Los dos pasos son necesarios y por razones distintas:
  #
  #   · `ReportCardPdf.texto` translitera lo que la fuente no puede dibujar —un
  #     "Ștefan" saldría como excepción y tiraría abajo el documento;
  #   · el escape de `<`, `>` y `&` existe porque `inline_format` interpreta esas
  #     marcas. Sin él, un colegio llamado "Simón Bolívar & Asociados" o un
  #     apellido con un `<` convertirían el nombre en una etiqueta a medio
  #     cerrar, y Prawn levantaría un error de parseo sobre un dato legítimo.
  #
  # Lo encontré mirando el PDF: sin `inline_format` las etiquetas `<b>` salían
  # impresas tal cual. Los tests pasaban igual — verificaban que el PDF existía,
  # no lo que decía.
  def seguro(valor)
    texto(valor).gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def firma(pdf, _colegio)
    pdf.move_down 90

    pdf.bounding_box([pdf.bounds.width / 4, pdf.cursor], width: pdf.bounds.width / 2) do
      pdf.stroke_horizontal_rule
      pdf.move_down 6
      pdf.text "Director(a)", size: 10, align: :center
      pdf.move_down 2
      pdf.text "Firma y sello", size: 8, align: :center, color: "888888"
    end
  end

  # `schools.location` es texto libre —"Caracas, Distrito Capital"— y para la
  # fórmula alcanza con la ciudad. Es una de las quince columnas que `MOR-99`
  # dejó anotadas como faltantes: cuando el colegio tenga municipio y entidad
  # federal por separado, esto sale de ahí.
  def ciudad(colegio)
    colegio.location.to_s.split(",").first.to_s.strip.presence || "la ciudad"
  end

  DIAS = %w[cero uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece
            catorce quince dieciséis diecisiete dieciocho diecinueve veinte veintiuno
            veintidós veintitrés veinticuatro veinticinco veintiséis veintisiete
            veintiocho veintinueve treinta treinta y uno].freeze

  # En letras porque así lo escribe el documento oficial: es una defensa contra
  # la adulteración, la misma idea que el número y las letras de la certificación
  # EMG (MOR-99).
  def dia_en_letras = texto(DIAS[Date.current.day])

  def mes_en_letras = texto(I18n.t("date.month_names")[Date.current.month])

  def texto(valor) = ReportCardPdf.texto(valor)
end
