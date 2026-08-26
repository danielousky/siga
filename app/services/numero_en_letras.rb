# La calificación escrita con letras (MOR-99).
#
# ⚠️ No es el literal A–E. La forma 31059 tiene DOS casillas por calificación:
#
#     CALIFICACIÓN
#     Nº  │ Letras
#     ────┼──────────
#     11  │ ONCE
#     19  │ DIECINUEVE
#
# Es el mismo número escrito de las dos maneras, que es como se protegen los
# documentos oficiales contra la adulteración: cambiarle un trazo al «11» para
# volverlo «17» exige cambiar también «ONCE» por «DIECISIETE», y ahí se nota.
#
# Solo hace falta del 1 al 20 —la escala del Artículo 108— así que va la lista
# completa y no un algoritmo: veinte palabras que no cambian nunca, contra un
# generador que hay que probar.
module NumeroEnLetras
  module_function

  DEL_1_AL_20 = {
    1 => "UNO", 2 => "DOS", 3 => "TRES", 4 => "CUATRO", 5 => "CINCO",
    6 => "SEIS", 7 => "SIETE", 8 => "OCHO", 9 => "NUEVE", 10 => "DIEZ",
    11 => "ONCE", 12 => "DOCE", 13 => "TRECE", 14 => "CATORCE", 15 => "QUINCE",
    16 => "DIECISÉIS", 17 => "DIECISIETE", 18 => "DIECIOCHO", 19 => "DIECINUEVE",
    20 => "VEINTE"
  }.freeze

  def para(numero) = DEL_1_AL_20[numero.to_i]
end
