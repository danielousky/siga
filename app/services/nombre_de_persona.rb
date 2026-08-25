# Parte "DE LA CRUZ MARÍN JOSÉ LUIS" en apellidos y nombres (MOR-126).
#
# Una planilla de colegio trae el nombre en UNA celda. El modelo lo necesita en
# tres campos, porque el SAIME verifica el PRIMER apellido contra la partida de
# nacimiento (`MOR-138`).
#
# ## Esto ADIVINA, y lo dice
#
# No hay forma de saber con certeza dónde termina el apellido de alguien. Lo que
# sí se puede es acertar casi siempre y **avisar cuándo no está seguro**, para
# que la previsualización pida corregir esas filas a mano en vez de cargarlas
# mal en silencio. Por eso `#seguro?` existe y no es decoración.
#
# ## El orden lo dice el encabezado
#
#     "APELLIDOS Y NOMBRES"   →  DE LA CRUZ | MARÍN | JOSÉ LUIS
#     "NOMBRES Y APELLIDOS"   →  JOSÉ LUIS  | DE LA CRUZ | MARÍN
#
# Es la misma celda con el mismo contenido y dos lecturas opuestas. Adivinarlo
# por el contenido es imposible; leerlo del título de la columna acierta.
class NombreDePersona
  # Partículas que se PEGAN a la palabra siguiente: "DE LA CRUZ" es un apellido,
  # no tres. Sin esto, cinco palabras se parten como si fueran dos apellidos
  # sueltos y un nombre, y la persona queda con el apellido "LA".
  PARTICULAS = %w[de del la las los san santa santo mac mc van von da das dos e y].freeze

  # Cuántas unidades de apellido se toman cuando hay de sobra. Dos es la norma
  # venezolana: paterno y materno.
  APELLIDOS = 2

  attr_reader :first_name, :last_name, :second_last_name, :motivo

  def self.apellidos_primero?(encabezado)
    texto = encabezado.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase

    return true  if texto.match?(/apellidos?.*nombres?/)
    return false if texto.match?(/nombres?.*apellidos?/)

    # Sin pistas, la convención de las planillas del MPPE: apellidos primero.
    true
  end

  def initialize(texto, apellidos_primero: true)
    @texto = texto.to_s.strip.gsub(/\s+/, " ")
    @apellidos_primero = apellidos_primero
    @motivo = nil

    partir
  end

  # ⚠️ `false` no significa que esté mal: significa que no se puede afirmar que
  # esté bien. La previsualización marca estas filas para que alguien las mire.
  def seguro? = @motivo.nil?

  def vacio? = @texto.empty?

  def to_h
    { first_name: first_name, last_name: last_name, second_last_name: second_last_name }
  end

  private

  def partir
    return marcar("La celda del nombre está vacía") if @texto.empty?

    unidades = agrupar(@texto.split(" "))

    case unidades.size
    when 1
      # Una sola palabra: no hay cómo saber si es nombre o apellido.
      @first_name = unidades.first
      marcar("Solo hay una palabra: no se sabe si es nombre o apellido")
    when 2
      uno, otro = unidades
      @apellidos_primero ? asignar(nombres: otro, apellidos: [ uno ]) : asignar(nombres: uno, apellidos: [ otro ])
    else
      repartir(unidades)
    end
  end

  def repartir(unidades)
    if @apellidos_primero
      apellidos = unidades.first(APELLIDOS)
      nombres   = unidades.drop(APELLIDOS)
    else
      apellidos = unidades.last(APELLIDOS)
      nombres   = unidades.first(unidades.size - APELLIDOS)
    end

    asignar(nombres: nombres.join(" "), apellidos: apellidos)

    # Cinco unidades o más es donde la convención deja de alcanzar: puede ser
    # una persona con tres nombres, o con un apellido compuesto que no empieza
    # por partícula ("PÉREZ DE LEÓN"). No se rechaza — se señala.
    marcar("Son #{unidades.size} palabras: revise dónde termina el apellido") if unidades.size >= 5
  end

  def asignar(nombres:, apellidos:)
    @first_name       = nombres.presence
    @last_name        = apellidos[0].presence
    @second_last_name = apellidos[1].presence
  end

  # Pega cada partícula a lo que le sigue: ["DE", "LA", "CRUZ", "MARÍN"] queda
  # como ["DE LA CRUZ", "MARÍN"].
  #
  # Una partícula al final no pega nada y se queda sola: "PÉREZ DE" es un dato
  # cortado, y dejarlo visible es mejor que esconderlo.
  def agrupar(palabras)
    palabras.each_with_object([]) do |palabra, unidades|
      if unidades.any? && particula?(unidades.last)
        unidades[-1] = "#{unidades.last} #{palabra}"
      else
        unidades << palabra
      end
    end
  end

  def particula?(unidad)
    ultima = unidad.split(" ").last.to_s
    PARTICULAS.include?(ultima.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase)
  end

  def marcar(motivo)
    @motivo ||= motivo
  end
end
