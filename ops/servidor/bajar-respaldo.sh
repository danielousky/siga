#!/usr/bin/env bash
# Baja a la Mac el respaldo más reciente de la máquina de la casa.
#
#   ops/servidor/bajar-respaldo.sh
#
# Lo corre launchd todos los días (ops/servidor/com.sigaeducando.bajar-respaldo.plist)
# y se puede correr a mano. Si la Mac no está en la casa ni en Tailscale, falla
# sin hacer ruido: lo vuelve a intentar al día siguiente.
#
# Es la copia FUERA de la máquina: si su disco viejo muere, el respaldo de la
# noche muere con él. Aquí van al mismo sitio de siempre, SIGA/respaldos.
set -euo pipefail

DESTINO="${DESTINO:-/Volumes/Personal Info/Documentos/Desarrollo/SIGA/respaldos}"
HOST="${HOST:-siga-casa}"

ultimo=$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST" 'ls -1t /var/backups/siga/siga_db-*.dump 2>/dev/null | head -1')
[ -n "$ultimo" ] || { echo "✗ $HOST no tiene respaldos todavía" >&2; exit 1; }

nombre="siga-casa-$(basename "$ultimo" | sed 's/^siga_db-//')"
if [ -f "$DESTINO/$nombre" ]; then
  echo "· ya estaba: $nombre"
  exit 0
fi
scp -q -o BatchMode=yes "$HOST:$ultimo" "$DESTINO/$nombre.parcial"
head -c 5 "$DESTINO/$nombre.parcial" | grep -q PGDMP || { rm -f "$DESTINO/$nombre.parcial"; echo "✗ lo que bajó no es un volcado" >&2; exit 1; }
mv "$DESTINO/$nombre.parcial" "$DESTINO/$nombre"
echo "✓ $nombre ($(du -h "$DESTINO/$nombre" | cut -f1))"
