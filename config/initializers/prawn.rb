# Prawn avisa en cada arranque que sus fuentes de fábrica tienen soporte limitado
# de texto internacional. Ya lo sabemos y está resuelto: `ReportCardPdf` translitera
# lo que la fuente no puede representar en vez de dejar que reviente, y el
# comentario de esa clase explica cuándo convendría embeber una TTF completa.
#
# Sin esto, el aviso ensucia los logs y el `bin/smoke`, que trata las líneas raras
# del log como sospechosas.
Prawn::Fonts::AFM.hide_m17n_warning = true
