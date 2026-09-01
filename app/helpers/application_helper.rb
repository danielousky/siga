module ApplicationHelper
  include Pagy::Frontend

  # Los métodos de rol y autorización están definidos en ApplicationController
  # y expuestos a las vistas vía helper_method

  # Plural en español, con las dos formas escritas a mano.
  #
  # `String#pluralize` de Rails usa el inflector INGLÉS, y la app está en español.
  # A veces coincide por casualidad —"alumno" → "alumnos"— y a veces no:
  #
  #     "boletín".pluralize(3)  # => "boletíns"   ✗
  #     "lápiz".pluralize(2)    # => "lápizs"     ✗
  #     "profesor".pluralize(2) # => "profesors"  ✗
  #
  # Que funcione en las palabras terminadas en vocal es lo peligroso: se usa sin
  # pensar, y el día que la palabra termina en consonante o lleva tilde sale un
  # texto roto en pantalla. Acá las dos formas van explícitas.
  #
  #     pluralizar(3, "boletín", "boletines")  # => "boletines"
  #     pluralizar(1, "boletín", "boletines")  # => "boletín"
  def pluralizar(cantidad, singular, plural)
    cantidad == 1 ? singular : plural
  end

  # Lo mismo con el número adelante: "3 boletines", "1 boletín".
  def contar(cantidad, singular, plural)
    "#{cantidad} #{pluralizar(cantidad, singular, plural)}"
  end

  # "15 de septiembre" — día y mes, sin el año.
  #
  # `l(fecha, format: :long)` agrega el año y `:short` abrevia el mes ("15 de
  # sep"). En la barra de contexto el año ya lo dice el nombre del período, así
  # que repetirlo es ruido.
  def dia_y_mes(fecha)
    "#{fecha.day} de #{I18n.t('date.month_names')[fecha.month]}"
  end

  # La calificación del AÑO, escrita según la escala del grado (MOR-129).
  #
  #     nota_del_ano(19, grado)   # media general → "19"
  #     nota_del_ano(19, grado)   # primaria      → "A (19)"
  #
  # Solo para las notas del año. Las de lapso van en número hasta que exista la
  # rúbrica de competencias (`MOR-136`): en primaria el lapso no se evalúa con
  # letras, y ponerle una sería inventarla.
  def nota_del_ano(nota, grado)
    EscalaLiteral.mostrar(nota, escala: grado&.escala) || "—"
  end

  # Cómo se escribe la relación del período con el día de hoy.
  #
  # Importa no mentir acá: en agosto no hay año escolar corriendo, y una barra
  # que dijera "activo" estaría afirmando algo falso sobre el colegio. Es el
  # mismo error que tenía el rótulo anterior, que anunciaba un dato y no lo traía.
  def situacion_del_periodo(periodo)
    case periodo.situacion
    when :en_curso     then "en curso"
    when :por_comenzar then "comienza el #{dia_y_mes(periodo.start_date)}"
    when :finalizado   then "finalizado el #{dia_y_mes(periodo.end_date)}"
    end
  end

  # El año escolar que le tocaría a un colegio hoy, para prellenar el formulario
  # de rescate del importador.
  #
  # En Venezuela va de mediados de septiembre a mediados de julio. Si estamos
  # antes de agosto seguimos dentro del año que empezó el septiembre pasado; de
  # agosto en adelante, el que arranca ahora.
  def ano_escolar_sugerido(hoy = Date.current)
    inicio = hoy.month >= 8 ? hoy.year : hoy.year - 1

    {
      nombre: "#{inicio}-#{inicio + 1}",
      desde: Date.new(inicio, 9, 15),
      hasta: Date.new(inicio + 1, 7, 31)
    }
  end
end
