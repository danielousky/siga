# Las marcas de una planilla que se guarda sola.
#
# ⚠️ Viven acá y no en cada vista ni en cada controlador de Stimulus porque las
# tres planillas —notas, informes descriptivos y Educación Inicial— decían lo
# mismo de tres maneras, y el mismo profesor las cruza en la misma tarde.
module PlanillaHelper
  # ⚠️ Un SÍMBOLO y no una palabra. La marca va pegada a un campo, repetida
  # treinta veces en vertical: «guardado» escrito treinta veces es una columna
  # de texto que compite con los nombres. Y el nombre del estado igual se lee,
  # en el tooltip.
  MARCAS = {
    "guardando" => "…",
    "guardado"  => "✓",
    "vacio"     => "—",
    "sin_red"   => "⟳",
    "rechazado" => "!"
  }.freeze

  # Y qué dice cada una al apuntarla. `data-tooltip` y nunca `title` (MOR-173).
  AVISOS = {
    "guardando" => "Guardando…",
    "guardado"  => "Guardado",
    "vacio"     => "Sin llenar",
    "sin_red"   => "Sin conexión: queda pendiente y se reintenta solo",
    "rechazado" => "No se pudo guardar"
  }.freeze
end
