# La escala literal A–E de educación primaria (MOR-129).
#
# ## Es un mapa de presentación, no una escala aparte
#
# Lo que se guarda sigue siendo el entero del 1 al 20 del Artículo 108. El
# literal se calcula al mostrarlo, y por eso este archivo no toca la base, ni
# `GradeCalculator`, ni una sola validación.
#
# Esa forma no la inventamos: es como funcionaba **Arcada**, el sistema que usaba
# Cyndi en La Consolación. En sus palabras: *"nosotros subíamos las notas
# cuantitativas… la niña sacó 19, por eso tiene PC. Al momento de subir la nota
# yo le tenía que poner 19, pero a los representantes se les reflejaba era PC"*.
#
#     DOCENTE  ──19──►  BASE (1–20)  ──19──►  REPRESENTANTE ve "A (19)"
#     ya existía         ya existía            ← lo único que faltaba
#
# ## Los cortes
#
# Los dio Cyndi, con 19 años de aula. Fijate que **el corte de aprobación cae en
# 10**, igual que en media general: no son dos sistemas distintos, es el mismo
# umbral con otra etiqueta.
#
# ## Qué NO cubre
#
# El literal es **la nota final del año escolar** — *"los literales son la nota
# final del año escolar, ABCDE"*. Durante los lapsos primaria no evalúa con
# letras sino con competencias e indicadores y una rúbrica de cinco niveles
# (PC/PA/PI/PD/NP). Eso es `MOR-136`, y está aparte a propósito: las notas de
# lapso se siguen mostrando en número hasta que exista.
class EscalaLiteral
  # De mayor a menor. El orden importa: se devuelve el primero que abarca.
  RANGOS = [
    ["A", 19..20],
    ["B", 17..18],
    ["C", 14..16],
    ["D", 10..13],
    ["E", 1..9]
  ].freeze

  # `E` es reprobado: *"E es reprobado, todo el que tiene que estar reprobado,
  # es decir, por debajo de 10"*.
  REPROBADO = "E"

  # El literal que le toca a una nota, o `nil` si no hay nota.
  #
  # Sin nota **no es cero** y tampoco es E: es que todavía no hay nada que
  # calificar. Confundirlos reprueba a una sección entera a mitad de lapso.
  def self.para(nota)
    return nil if nota.blank?

    entero = nota.to_i
    RANGOS.each { |letra, rango| return letra if rango.cover?(entero) }

    # Fuera de 1–20 no debería llegar nada: lo garantizan cinco validaciones y
    # cinco CHECK. Si llega, devolver algo inventado sería peor que no devolver.
    nil
  end

  # Cómo se escribe una calificación según la escala de su grado.
  #
  #     mostrar(19, escala: :numerica)  # => "19"
  #     mostrar(19, escala: :literal)   # => "A (19)"
  #
  # Las dos cosas juntas, y no es redundancia: el literal porque es lo que exige
  # el papel oficial —*"correspondiéndole el literal: ___"*—, y el número porque
  # es lo que la familia entiende. Cyndi, después de 19 años evaluando de forma
  # cualitativa: *"los papás cuando van a retirar una boleta preguntan '¿y
  # cuánto, profe?'"*. La norma y la gente no coinciden hace dos décadas.
  def self.mostrar(nota, escala:)
    return nil if nota.blank?

    entero = nota.to_i
    return entero.to_s unless escala.to_s == "literal"

    letra = para(entero)
    letra ? "#{letra} (#{entero})" : entero.to_s
  end

  def self.aprobado?(nota)
    nota.present? && nota.to_i >= 10
  end
end
