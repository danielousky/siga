#!/usr/bin/env bash
# Copia las variables de una app de Contabo a esta máquina, sin que pasen por la
# pantalla, por un archivo ni por la conversación:
#
#   ssh siga-deploy config:export --format json siga \
#     | ssh siga-casa 'sudo siga-ops/variables.sh siga'
#
# No se copian:
#   DATABASE_URL      la de aquí apunta a la base de aquí, y la puso montar.sh
#   GIT_REV, DOKKU_*  las pone Dokku en cada despliegue
#
# ENSAYO=1 deja afuera además el correo (SMTP_*, SIGA_AVISOS_EMAIL), porque un
# ensayo no le escribe a nadie, y SECRET_KEY_BASE, que se genera nueva: la de
# producción no tiene nada que hacer en una VM.
set -euo pipefail

app=${1:?uso: … | variables.sh <app>}
[ "$(id -u)" = 0 ] || { echo "✗ Corre como root" >&2; exit 1; }
dokku apps:exists "$app" 2>/dev/null || { echo "✗ No existe la app $app: primero montar.sh" >&2; exit 1; }

fuera='^(DATABASE_URL|GIT_REV|DOKKU_.*)$'
[ "${ENSAYO:-}" = 1 ] && fuera='^(DATABASE_URL|GIT_REV|DOKKU_.*|SMTP_.*|SIGA_AVISOS_EMAIL|SECRET_KEY_BASE)$'

# En base64 de punta a punta: un valor con espacios, comillas o un `$` llega
# como salió, y `config:set --encoded` lo descifra allá.
mapfile -t pares < <(jq -r --arg fuera "$fuera" \
  'to_entries[] | select(.key | test($fuera) | not) | "\(.key)=\(.value | @base64)"')
[ "${#pares[@]}" -gt 0 ] || { echo "✗ No llegó ninguna variable" >&2; exit 1; }
[ "${ENSAYO:-}" = 1 ] && pares+=("SECRET_KEY_BASE=$(openssl rand -hex 64 | tr -d '\n' | base64 | tr -d '\n')")

dokku config:set --no-restart --encoded "$app" "${pares[@]}" >/dev/null
echo "✓ $app: ${#pares[@]} variables — $(printf '%s\n' "${pares[@]}" | cut -d= -f1 | tr '\n' ' ')"
