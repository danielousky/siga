# Los dos documentos de fin de año de Educación Inicial (MOR-99).
#
# El texto es el de los formatos del MPPE que entregó Daniel el 11 de septiembre
# de 2026 (`DOCs/209_CertificadoEduI`), y se diferencian en una sola frase: si el
# niño continúa a primaria o no.
#
#     CERTIFICACIÓN DE ESTUDIOS DEL NIVEL DE EDUCACIÓN INICIAL
#     cursó el III Grupo  →  «y continuará estudios en el 1ER. GRADO del
#                             Nivel de Educación Primaria»
#     Se emite una vez, al terminar el nivel.
#
#     CONSTANCIA DE PROSECUCIÓN EN EL NIVEL DE EDUCACIÓN INICIAL
#     cursó el I o el II Grupo  →  y ahí termina la frase.
#     Se emite cada año, entre grupos.
#
# ## ⚠️ Acá NO va ningún literal, y es la diferencia con primaria
#
# En Educación Inicial la calificación es un TEXTO —no hay nota, ni escala, ni
# promedio (`docs/specs/educacion-inicial.md`)— y el formato del ministerio lo
# refleja: no tiene casilla para una calificación. Copiar el párrafo de primaria
# y dejarle el hueco del literal habría puesto en un documento oficial una
# casilla que en este nivel no existe.
#
# ## Por qué son prosa con huecos y no una tabla
#
# El formato oficial es un párrafo corrido con líneas para llenar a mano. Lo que
# SIGA tiene va impreso; lo que no —la parroquia si el colegio no la cargó, el
# lugar de nacimiento— queda como línea, que es exactamente lo que hace el papel
# que reparte la zona educativa.
class DocumentoDeInicialPdf
  include DibujaDocumentosOficiales
  include UnDocumentoPorAlumno

  MARGEN = 56

  TITULOS = {
    certificacion: "CERTIFICACIÓN DE ESTUDIOS\nDEL NIVEL DE EDUCACIÓN INICIAL",
    prosecucion: "CONSTANCIA DE PROSECUCIÓN\nEN EL NIVEL DE EDUCACIÓN INICIAL"
  }.freeze

  # Los `datos` vienen de `DocumentoDeInicial`, que decide cuál de los dos es:
  # los de un niño, o la lista de los de una sección. `new` y `render` los pone
  # `UnDocumentoPorAlumno`.

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

  # ⚠️ `inline_format` para poner en negrita lo que el formato resalta: el
  # estado, el grupo, el período y a dónde continúa. Es lo que alguien busca
  # cuando lee el papel en diez segundos.
  def cuerpo(pdf)
    e = @d["estudiante"]
    p_ = @d["plantel"]

    pdf.text <<~TEXTO.squish, size: 11, align: :justify, leading: 7, inline_format: true
      Quien suscribe #{linea(@d.dig('firmante', 'nombre'), 46)} titular de la Cédula de
      Identidad N° #{linea(@d.dig('firmante', 'documento'), 16)} en su condición de
      Director(a) del #{linea(p_['nombre'], 46)}, ubicado en el municipio
      #{linea(p_['municipio'], 22)} de la parroquia #{linea(p_['parroquia'], 22)},
      adscrito a la Zona Educativa del estado <b>#{texto(p_['entidad_federal'].to_s.upcase)}</b>,
      hace constar por medio de la presente que el niño (a)
      #{linea(e['nombre'], 46)}, portador de la Cédula Escolar N°
      #{linea(e['identificador'], 20)}, nacido (a) en #{linea(e['lugar_de_nacimiento'], 24)}
      en fecha #{linea(e['fecha_de_nacimiento'], 22)}, cursó el
      <b>#{texto(@d['grupo'])} Grupo</b> de la Etapa <b>#{texto(@d['etapa'])}</b> del Nivel de
      Educación Inicial durante el período escolar <b>#{texto(@d['periodo'])}</b>#{continuacion}.
    TEXTO
  end

  # ⚠️ La frase que separa a los dos documentos, y es la única diferencia del
  # párrafo: quien termina el III Grupo CONTINÚA a primaria; los otros dos, no.
  def continuacion
    return "" if @d["continua_en"].blank?

    " y continuará estudios en <b>#{texto(@d['continua_en'])}</b>"
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
  #
  # ⚠️ El formato de Inicial cierra con «Certificado válido a nivel nacional e
  # internacional», y ahí está la razón de que el cuadro tenga DOS columnas: la
  # del plantel vale a nivel nacional, la de la zona educativa —que se llena en
  # su ventanilla— es la que le da validez afuera. Se deja en blanco a
  # propósito: es lo que le recuerda al colegio que ese trámite existe.
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
