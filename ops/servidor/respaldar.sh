#!/bin/bash
# El respaldo de cada noche: la base de producción y sus adjuntos.
#
# Es el de Contabo (/root/respaldar-siga.sh, del 18 de agosto de 2026), con el
# destino y la retención de la casa. Lo instala montar.sh en
# /usr/local/sbin/respaldar-siga, y lo corre el cron a las 3:30.
#
# El volcado de la base NO incluye los archivos subidos (escudos, fotos,
# comprobantes): viven en el volumen. Por eso son dos archivos y no uno.
#
# Verifica lo que escribe. Un respaldo de 0 bytes que nadie mira es peor que no
# tener respaldo, porque da una seguridad que no existe.
set -euo pipefail

DEST=/var/backups/siga
LOG=$DEST/respaldos.log
FECHA=$(date +%F-%H%M)
# 14 y no 30: aquí el disco es viejo, y la Mac guarda su propia copia.
RETENCION_DIAS=14
mkdir -p "$DEST"

anotar() { echo "$(date -Is) $*" >> "$LOG"; }
fallar() { anotar "ERROR $*"; exit 1; }

# 1 · Base de datos
DB=$DEST/siga_db-$FECHA.dump
dokku postgres:export siga-db > "$DB" 2>/dev/null || fallar "postgres:export falló"
[ -s "$DB" ] || fallar "el volcado quedó vacío"
head -c 5 "$DB" | grep -q PGDMP || fallar "el volcado no es un dump válido de PostgreSQL"

# 2 · Adjuntos
ADJ=$DEST/adjuntos-$FECHA.tgz
tar czf "$ADJ" -C /var/lib/dokku/data/storage siga-storage || fallar "tar de adjuntos falló"
[ -s "$ADJ" ] || fallar "el tar de adjuntos quedó vacío"

# 3 · Retención
find "$DEST" -maxdepth 1 -name 'siga_db-*.dump' -mtime +$RETENCION_DIAS -delete
find "$DEST" -maxdepth 1 -name 'adjuntos-*.tgz' -mtime +$RETENCION_DIAS -delete

anotar "OK  base=$(du -h "$DB" | cut -f1)  adjuntos=$(du -h "$ADJ" | cut -f1)  copias=$(ls -1 "$DEST"/siga_db-*.dump | wc -l)"
