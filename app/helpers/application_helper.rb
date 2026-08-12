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
end
