#!/bin/bash
# El manual en papel. Chrome imprime el mismo HTML que se publica, así que no
# hay una segunda versión que mantener: los estilos de `@media print` de m1.html
# son los que deciden cómo se ve.
#
# ⚠️ El HTML lleva las 53 capturas en base64 (3,5 MB) y Chrome tarda; --timeout
# le da margen. Sin --no-pdf-header-footer sale con la URL del archivo
# impresa en cada hoja, que en un file:// es una ruta absoluta larguísima.
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
test -x "$CHROME" || { echo "No está Chrome en $CHROME"; exit 1; }

"$CHROME" --headless --disable-gpu --no-pdf-header-footer --timeout=120000 \
  --print-to-pdf="$PWD/manual_de_siga.pdf" \
  "file://$PWD/manual_de_siga.html" 2>/dev/null

ls -lh manual_de_siga.pdf | awk '{print "✓ " $9 " · " $5}'
