#!/bin/bash
# Las PNG crudas pesan ~40 MB; el artifact tiene un tope de 16 MB y las imágenes
# viajan en base64 (que abulta un tercio más). 980 px de ancho es el ancho real
# de la hoja del manual, así que no se pierde nada visible.
set -e
cd "$(dirname "$0")"
mkdir -p opt
for f in png/*.png; do
  sips -Z 980 -s format jpeg -s formatOptions 62 "$f" \
       --out "opt/$(basename "${f%.png}").jpg" > /dev/null
done
du -sh opt
