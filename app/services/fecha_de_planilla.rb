# Lee una fecha de una celda de planilla, en formato venezolano (MOR-126).
#
# **Día/mes/año.** Confirmado como decisión, no deducido: es lo que escribe una
# secretaria venezolana y lo que produce un Excel en español.
#
# ## El peligro silencioso
#
# `03/12/2014` es una fecha válida leída como día/mes (3 de diciembre) Y leída
# como mes/día (12 de marzo). Las dos parsean. Ninguna falla. Si la planilla
# salió de un Excel en inglés, **todas las fechas donde día y mes son ≤ 12
# quedan cambiadas y nadie se entera** — el alumno nace en un mes equivocado y
# eso viaja a la planilla del MPPE.
#
# No se puede resolver mirando el dato. Sí se puede CONTAR: `#ambigua?` marca
# esas celdas para que la previsualización diga "47 fechas podrían leerse al
# revés, confirme que su planilla usa día/mes". Con `22/11/2014` no hay duda
# —no hay mes 22— y por eso basta con que UNA fecha del archivo sea inequívoca
# para saber en qué formato está todo.
class FechaDePlanilla
  # Excel guarda las fechas como días desde el 30/12/1899. roo casi siempre las
  # convierte, pero un CSV exportado a mano puede traer el número pelado.
  EPOCA_DE_EXCEL = Date.new(1899, 12, 30)

  # Acotado a propósito: 10.000 es 1927 y 60.000 es 2064. Sin este rango, un
  # año suelto como `2014` se leería como número de serie y daría 1905.
  SERIE = (10_000..60_000).freeze

  SEPARADORES = %r{[/\-.]}

  attr_reader :fecha, :motivo

  def initialize(valor)
    @crudo = valor
    @motivo = nil

    @fecha = interpretar
  end

  def vacia? = @crudo.to_s.strip.empty?
  def valida? = @fecha.present?

  # ⚠️ Verdadero cuando la misma celda se leería distinto en un Excel en inglés.
  # No es un error: es una celda sobre la que hay que preguntar.
  def ambigua? = @ambigua.present?

  def to_s = @fecha&.strftime("%d/%m/%Y").to_s

  private

  def interpretar
    return marcar(nil) if vacia?

    case @crudo
    when Date, DateTime then @crudo.to_date
    when Time           then @crudo.to_date
    when Numeric        then de_serie(@crudo)
    else                     de_texto(@crudo.to_s.strip)
    end
  end

  def de_serie(numero)
    entero = numero.to_i
    return marcar("«#{numero}» no parece una fecha") unless SERIE.cover?(entero)

    EPOCA_DE_EXCEL + entero
  end

  def de_texto(texto)
    return de_serie(texto.to_i) if texto.match?(/\A\d+\z/)
    return iso(texto) if texto.match?(/\A\d{4}#{SEPARADORES}\d{1,2}#{SEPARADORES}\d{1,2}/o)

    partes = texto.split(SEPARADORES).map(&:strip)
    return marcar("«#{texto}» no parece una fecha") unless partes.size == 3

    dia, mes, anio = partes.map(&:to_i)
    @ambigua = true if dia <= 12 && mes <= 12 && dia != mes

    armar(anio_completo(anio, partes.last), mes, dia, texto)
  end

  def iso(texto)
    anio, mes, dia = texto.split(SEPARADORES).first(3).map(&:to_i)
    armar(anio, mes, dia, texto)
  end

  def armar(anio, mes, dia, texto)
    Date.new(anio, mes, dia)
  rescue Date::Error
    marcar("«#{texto}» no es una fecha que exista")
  end

  # `12/03/14` es 2014, no 1914. La bisagra: si el año de dos dígitos cayera en
  # el futuro, es del siglo pasado — que es lo que corresponde para la fecha de
  # nacimiento de un profesor nacido en el 80.
  def anio_completo(anio, escrito)
    return anio if escrito.length > 2

    siglo = anio + 2000
    siglo > Date.current.year ? anio + 1900 : siglo
  end

  def marcar(motivo)
    @motivo = motivo
    nil
  end
end
