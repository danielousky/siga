# Los dos documentos de fin de año de Educación Primaria (MOR-99).
#
# La forma 31059 certifica Media General y **no cubre primaria**. Lo que cubre
# primaria son estos dos, y se diferencian en una sola cosa: a dónde promueven.
#
#     CERTIFICADO DE EDUCACIÓN PRIMARIA
#     cursó el 6to Grado  →  promovido AL 1er AÑO DEL NIVEL DE EDUCACIÓN MEDIA
#     Se emite una vez, al terminar la primaria.
#
#     CONSTANCIA DE PROSECUCIÓN EN EL NIVEL DE EDUCACIÓN PRIMARIA
#     cursó el 3er Grado  →  promovido AL 4to GRADO DEL NIVEL DE EDUCACIÓN PRIMARIA
#     Se emite cada año, al aprobar un grado que no es el último.
#
# ## ⚠️ Los dos certifican el LITERAL, no el número
#
# «correspondiéndole el literal: ___». Es la escala A–E de primaria (`MOR-129`),
# y es lo que hace que estos documentos no puedan reutilizar el boletín: el
# boletín muestra «17 (B)» porque el número explica la letra a una familia; acá
# la casilla es del literal y nada más.
#
# ## Por qué son prosa con huecos y no una tabla
#
# El formato oficial es un párrafo corrido con líneas para llenar a mano. Los
# datos que SIGA tiene van impresos; los que no —la parroquia si el colegio no la
# cargó, el número de pasaporte de un alumno extranjero— quedan como línea, que
# es exactamente lo que hace el papel que reparte la zona educativa.
class DocumentoDePrimariaPdf
  include DibujaDocumentosOficiales
  include UnDocumentoPorAlumno

  MARGEN = 56

  TITULOS = {
    certificado: "CERTIFICADO\nDE EDUCACIÓN PRIMARIA",
    prosecucion: "CONSTANCIA DE PROSECUCIÓN\nEN EL NIVEL DE EDUCACIÓN PRIMARIA"
  }.freeze

  # Los `datos` vienen de `DocumentoDePrimaria`, que decide cuál de los dos es:
  # los de un alumno, o la lista de los de una sección. `new` y `render` los
  # pone `UnDocumentoPorAlumno`.

  private

  def dibujar(pdf)
    membrete(pdf)
    titulo(pdf)
    cuerpo(pdf)
    expedicion(pdf)
    validez(pdf)
  end

  def titulo_del_archivo = TITULOS.fetch(tipo).tr("\n", " ")

  # ⚠️ Método y no `@tipo`: con una sección entera en el mismo PDF, el tipo es
  # el del documento que se está dibujando AHORA. Ver `UnDocumentoPorAlumno`.
  def tipo = @d["tipo"].to_sym

  # ⚠️ El logo del ministerio arriba a la izquierda y el ESCUDO centrado sobre el
  # título, que es como vienen los dos formatos oficiales.
  def membrete(pdf)
    arriba = pdf.cursor
    con_logo = dibujar_emblema(pdf, :ministerio, ancho: 72, alto: 40, en: [ 0, arriba ])

    pdf.move_cursor_to arriba
    pdf.indent(con_logo ? 82 : 0) do
      pdf.text "Ministerio del Poder Popular para la Educación", size: 7
      pdf.text "Despacho del Viceministerio de Educación", size: 6.5, color: "666666"
      pdf.text "Dirección General de Registro y Control Académico", size: 6.5, color: "666666"
    end

    pdf.move_cursor_to arriba - 46
    pdf.move_down 14
  end

  def titulo(pdf)
    dibujar_emblema(pdf, :escudo, ancho: 62, alto: 58, posicion: :center)
    pdf.move_down 10

    pdf.text TITULOS.fetch(tipo), size: 15, style: :bold, align: :center, leading: 3
    pdf.move_down 26
  end

  # ── el párrafo ────────────────────────────────────────────────────────────

  # ⚠️ `inline_format` para poder poner en negrita lo que el formato pone en
  # negrita: el grado, el literal, el año escolar y a dónde promueve. Es lo que
  # alguien busca cuando lee el papel en diez segundos.
  def cuerpo(pdf)
    e = @d["estudiante"]
    p_ = @d["plantel"]

    pdf.text <<~TEXTO.squish, size: 11, align: :justify, leading: 7, inline_format: true
      Quien suscribe #{linea(@d.dig('firmante', 'nombre'), 46)} titular de la Cédula de
      Identidad N° #{linea(@d.dig('firmante', 'documento'), 16)} en su condición de
      Director(a) de #{linea(p_['nombre'], 46)} ubicado en el municipio
      #{linea(p_['municipio'], 22)} de la parroquia #{linea(p_['parroquia'], 22)}
      adscrito a la Zona Educativa del estado <b>#{texto(p_['entidad_federal'].to_s.upcase)}</b>,
      certifica por medio de la presente que el (la) estudiante
      #{linea(e['nombre'], 46)} titular de Cédula Escolar, Cédula de Identidad N° o
      Pasaporte N° #{linea(e['identificador'], 20)}, nacido (a) en:
      #{linea(e['lugar_de_nacimiento'], 26)} en fecha: #{linea(e['fecha_de_nacimiento'], 22)},
      cursó el <b>#{texto(@d['grado'])}</b> correspondiéndole el literal:
      <b>#{linea(@d['literal'], 6)}</b> durante el período escolar
      <b>#{texto(@d['periodo'])}</b>, siendo promovido(a) <b>#{texto(@d['promovido_a'])}</b>,
      previo cumplimiento a los requisitos establecidos en la Normativa Legal vigente.
    TEXTO
  end

  def expedicion(pdf)
    pdf.move_down 22
    hoy = Date.current

    pdf.text <<~TEXTO.squish, size: 11, align: :justify, leading: 7, inline_format: true
      Constancia que se expide en #{linea(@d['expedida_en'], 26)}, a los
      <b>#{hoy.day}</b> días del mes de <b>#{I18n.t('date.month_names')[hoy.month].upcase}</b>
      de #{hoy.year}.
    TEXTO
  end

  # ── el cuadro de validez ──────────────────────────────────────────────────

  # ⚠️ Dos columnas, y la diferencia entre ellas no es cosmética:
  #
  #     PLANTEL          → validez a nivel NACIONAL
  #     ZONA EDUCATIVA   → validez a nivel INTERNACIONAL
  #
  # La segunda va en blanco porque la llena la zona educativa cuando el papel
  # llega a su ventanilla. Un colegio que necesite el documento para un trámite
  # afuera tiene que pasar por ahí, y el cuadro vacío es lo que se lo recuerda.
  def validez(pdf)
    pdf.move_down 40

    filas = [
      [ "PLANTEL\nPARA VALIDEZ A NIVEL NACIONAL", "ZONA EDUCATIVA\nPARA VALIDEZ A NIVEL INTERNACIONAL" ],
      [ "DIRECTOR(A)", "DIRECTOR(A)" ],
      [ "Nombre y Apellido:  #{texto(@d.dig('firmante', 'nombre')).upcase}", "Nombre y Apellido:" ],
      [ "Número de C.I.:  #{texto(@d.dig('firmante', 'documento'))}", "Número de C.I.:" ],
      [ "Firma y Sello:", "Firma y Sello:" ]
    ]

    ancho = pdf.bounds.width * 0.78
    pdf.table(filas, position: :center, width: ancho, header: true,
                     cell_style: { size: 7.5, padding: [ 3, 5 ], border_color: "666666" }) do
      row(0).font_style = :bold
      row(0).align = :center
      row(0).background_color = "F2F2F2"
      row(4).height = 54
    end
  end

  # ── el andamiaje ──────────────────────────────────────────────────────────

  # Un valor, o una línea para llenar a mano si no lo tenemos. Es lo que hace el
  # papel oficial, y evita el peor resultado posible: imprimir un dato en blanco
  # sin que se note que falta.
  def linea(valor, largo)
    valor.present? ? "<b>#{texto(valor)}</b>" : "_" * largo
  end
end
