#!/usr/bin/env bash
# Monta la máquina de SIGA, o revisa que siga montada: Docker, Dokku, las dos
# apps y sus bases. Se puede correr cuantas veces haga falta; lo que ya está se
# deja como está.
#
#   rsync -a ops/servidor/ siga-casa:siga-ops/
#   ssh siga-casa 'sudo siga-ops/montar.sh'
#
# Copia lo que tenía Contabo el 29 de octubre de 2026: Dokku 0.38, el plugin
# de postgres 1.48.0, el de letsencrypt 0.25.1 y PostgreSQL 18.4. Lo que NO
# hace, a propósito:
#
#   los datos         son de restaurar.sh: una base vacía no se confunde con una llena
#   las variables     son de variables.sh, que las copia de Contabo sin mostrarlas
#   los certificados  Let's Encrypt necesita el dominio apuntando aquí, y eso es el
#                     cambio (tanda 5), no el montaje
#
# ⚠️ No guarda ni imprime un solo secreto. La clave de `siga_app` nace aquí y va
# directo a DATABASE_URL, como hacía `rotar.sh` en Contabo.
set -euo pipefail

DOKKU_TAG="${DOKKU_TAG:-v0.38.32}"
PLUGIN_POSTGRES="${PLUGIN_POSTGRES:-1.48.0}"
PLUGIN_LETSENCRYPT="${PLUGIN_LETSENCRYPT:-0.25.1}"
IMAGEN_POSTGRES="${IMAGEN_POSTGRES:-18.4}"
RED_DE_LA_CASA="${RED_DE_LA_CASA:-192.168.10.0/24}"
ADMIN="${SUDO_USER:-daniel}"

APPS=(siga siga-demo)
declare -A DOMINIOS=(
  [siga]="sigaeducando.com www.sigaeducando.com"
  [siga-demo]="demo.sigaeducando.com"
)

paso() { printf '\n── %s\n' "$*"; }
listo() { printf '   ✓ %s\n' "$*"; }
falla() { printf '   ✗ %s\n' "$*" >&2; exit 1; }

# ── 0 · Dónde estamos ─────────────────────────────────────────────────────────
paso "La máquina"
[ "$(id -u)" = 0 ] || falla "Corre como root: sudo $0"
. /etc/os-release
[ "$ID" = debian ] || [ "$ID" = ubuntu ] || falla "Esto es $PRETTY_NAME; Dokku pide Debian 11+ o Ubuntu 22.04+"
arquitectura=$(dpkg --print-architecture)
case "$arquitectura" in
  amd64|arm64) ;;
  # Docker no publica paquetes de 32 bits, y Dokku no corre sin Docker.
  *) falla "La máquina es $arquitectura: Dokku pide 64 bits (amd64 o arm64)" ;;
esac
listo "$PRETTY_NAME · $arquitectura · $(nproc) núcleos · $(free -g | awk '/^Mem:/{print $2}') GB"

# ── 1 · Paquetes ──────────────────────────────────────────────────────────────
paso "Paquetes"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# smartmontools, lm-sensors y memtester son para revisar un hardware de quince
# años antes de confiarle nada (tanda 4); avahi la anuncia en la red como
# `siga-casa.local`, para encontrarla sin saber su IP.
apt-get install -y -qq curl ca-certificates gnupg jq rsync ufw unattended-upgrades \
  smartmontools lm-sensors memtester avahi-daemon >/dev/null
listo "instalados"

# ── 2 · Hora y memoria ────────────────────────────────────────────────────────
paso "Hora y memoria"
# La app calcula «hoy» en hora de Venezuela por su cuenta; esto es para que los
# registros y el cron del respaldo hablen la misma hora que Daniel.
timedatectl set-timezone America/Caracas
# Compilar la imagen pide más de lo que una máquina vieja tiene libre: sin swap,
# el build muere a mitad con un «Killed» que no dice por qué.
swap=$(swapon --show=SIZE --bytes --noheadings | awk '{s += $1} END {print s + 0}')
if [ "$swap" -lt $((2 * 1024 ** 3)) ] && [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile
  mkswap -q /swapfile && swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  listo "swap de 4 GB"
else
  listo "swap: $((swap / 1024 ** 2)) MB"
fi

# ── 3 · Dokku ─────────────────────────────────────────────────────────────────
paso "Dokku $DOKKU_TAG"
if command -v dokku >/dev/null && [ "$(dokku version | awk '{print $3}')" = "${DOKKU_TAG#v}" ]; then
  listo "ya estaba"
else
  # Las preguntas del paquete, contestadas antes de que las haga: una
  # instalación que se detiene a preguntar no es desatendida.
  debconf-set-selections <<'DEBCONF'
dokku dokku/web_config boolean false
dokku dokku/vhost_enable boolean true
dokku dokku/skip_key_file boolean true
DEBCONF
  echo "dokku dokku/hostname string $(hostname)" | debconf-set-selections
  curl -fsSL "https://raw.githubusercontent.com/dokku/dokku/$DOKKU_TAG/bootstrap.sh" -o /tmp/dokku-bootstrap.sh
  DOKKU_TAG="$DOKKU_TAG" bash /tmp/dokku-bootstrap.sh
  listo "$(dokku version)"
fi

instalar_plugin() { # nombre repositorio versión
  if dokku plugin:installed "$1"; then
    listo "plugin $1 ya estaba"
  else
    dokku plugin:install "$2" --committish "$3" --name "$1"
    listo "plugin $1 $3"
  fi
}
instalar_plugin postgres https://github.com/dokku/dokku-postgres.git "$PLUGIN_POSTGRES"
instalar_plugin letsencrypt https://github.com/dokku/dokku-letsencrypt.git "$PLUGIN_LETSENCRYPT"

# La llave que recibe `git push` es la misma que entra por SSH: la que puso el
# instalador para el administrador.
# La carpeta se le pregunta al sistema: no siempre es /home/<usuario> (en la VM
# del ensayo es /home/<usuario>.guest).
llaves="$(getent passwd "$ADMIN" | cut -d: -f6)/.ssh/authorized_keys"
if dokku ssh-keys:list 2>/dev/null | grep -q 'NAME="daniel"'; then
  listo "la llave de daniel ya recibe git push"
elif [ -s "$llaves" ]; then
  head -1 "$llaves" | dokku ssh-keys:add daniel >/dev/null
  listo "la llave de $llaves recibe git push"
else
  falla "No hay llave en $llaves para dársela a Dokku"
fi

# ── 4 · Las apps y sus bases ──────────────────────────────────────────────────
# ⚠️ `postgres:link` deja DATABASE_URL con el superusuario `postgres`, que se
# salta el RLS antes de mirarlo (references/SERVIDOR-PRODUCCION.md § 6). Por eso
# va seguido de `rol_sin_privilegios`, y el `release:` del Procfile corre
# `rls:verificar`: si esto quedara mal, el despliegue aborta.
rol_sin_privilegios() { # servicio app
  local servicio=$1 app=$2 base=${1//-/_} contenedor="dokku.postgres.$1"
  if [[ "$(dokku config:get "$app" DATABASE_URL || true)" == postgres://siga_app:* ]]; then
    listo "$app ya entra como siga_app"
    return
  fi
  local clave ip
  clave=$(openssl rand -hex 24)
  # Por stdin y no por `-c`: así la clave no queda en la lista de procesos.
  docker exec -i "$contenedor" psql -q -U postgres -d "$base" -v ON_ERROR_STOP=1 >/dev/null <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'siga_app') THEN
    CREATE ROLE siga_app LOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END \$\$;
ALTER ROLE siga_app PASSWORD '$clave';
ALTER DATABASE $base OWNER TO siga_app;
SQL
  # Se prueba por la RED, como entra la app: en el loopback del contenedor
  # pg_hba dice `trust` y no pregunta clave. Esa prueba ya mintió una vez.
  ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$contenedor" | awk '{print $1}')
  docker exec -e PGPASSWORD="$clave" "$contenedor" psql -h "$ip" -U siga_app -d "$base" -tAc 'select 1' >/dev/null \
    || falla "siga_app no entra a $base por la red"
  dokku config:set --no-restart "$app" \
    DATABASE_URL="postgres://siga_app:$clave@dokku-postgres-$servicio:5432/$base" >/dev/null
  listo "$app entra como siga_app (clave nueva, sin imprimir)"
}

for app in "${APPS[@]}"; do
  paso "La app $app"
  dokku apps:exists "$app" 2>/dev/null || dokku apps:create "$app" >/dev/null
  dokku git:set "$app" deploy-branch main >/dev/null
  # ⚠️ Dokku arranca SOLO el `web`: los demás procesos del Procfile nacen en 0.
  # Sin el worker, Solid Queue no corre y nada lo dice: ni los promedios, ni la
  # escalera del cobro, ni la siembra de cada noche. En Contabo se subió a mano
  # y no quedó anotado en ningún lado; lo encontró el ensayo.
  dokku ps:scale --skip-deploy "$app" web=1 worker=1 >/dev/null
  # shellcheck disable=SC2086  # los dominios van separados, a propósito
  dokku domains:set "$app" ${DOMINIOS[$app]} >/dev/null
  # El 443 lo agrega Let's Encrypt en el cambio, cuando haya certificado.
  dokku ports:report "$app" --ports-map | grep -q 'http:80:3000' || dokku ports:set "$app" http:80:3000 >/dev/null
  # HSTS lo emite SOLO Rails: el de nginx trae 182 días e includeSubdomains, y
  # dejaría inaccesible el subdominio de un colegio sin certificado propio.
  dokku nginx:set "$app" hsts false >/dev/null
  # Contabo se quedó hasta el 4 de noviembre de 2026 con el 1 MB de fábrica, y
  # la app acepta 2 MB por foto o escudo, y el comprobante del pago tal como sale
  # del teléfono (3–4 MB, que EncogeElVoucher achica después). Con 1 MB, nginx
  # los rechazaba con un 413 antes de que la app pudiera explicar nada. Daniel
  # lo subió a 50 MB, allá y aquí: el tope de cada archivo lo pone la app.
  dokku nginx:set "$app" client-max-body-size 50m >/dev/null
  listo "dominios: ${DOMINIOS[$app]} · puerto 80 · subidas de hasta 50 MB"

  # Los adjuntos viven fuera del contenedor, o se irían con cada despliegue. El
  # contenedor corre como uid 1000 y Dokku crea el directorio como 32767.
  volumen="/var/lib/dokku/data/storage/$app-storage"
  # El directorio se crea a mano: `storage:ensure-directory` quedó en desuso en
  # 0.38, y `storage:create` registra «entradas» con nombre que Contabo no usa.
  install -d -m 755 "$volumen"
  chown -R 1000:1000 "$volumen"
  dokku storage:report "$app" --storage-deploy-mounts | grep -q ":/rails/storage" \
    || dokku storage:mount "$app" "$volumen:/rails/storage" >/dev/null
  listo "adjuntos en $volumen"

  servicio="$app-db"
  if dokku postgres:exists "$servicio" 2>/dev/null; then
    listo "base $servicio ya estaba"
  else
    dokku postgres:create "$servicio" --image-version "$IMAGEN_POSTGRES" >/dev/null
    listo "base $servicio (PostgreSQL $IMAGEN_POSTGRES)"
  fi
  dokku postgres:linked "$servicio" "$app" 2>/dev/null \
    || dokku postgres:link "$servicio" "$app" --no-restart >/dev/null
  rol_sin_privilegios "$servicio" "$app"
  # `postgres:link` deja ADEMÁS la URL del superusuario en DOKKU_POSTGRES_<COLOR>_URL.
  # La app no la lee, pero es la llave maestra de la base en el entorno de la
  # app: la ve cualquier `dokku run` y cualquier página que vuelque ENV. En
  # Contabo no está; aquí tampoco.
  for sobra in $(dokku config:keys "$app" | grep -E '^DOKKU_POSTGRES_[A-Z]+_URL$' || true); do
    dokku config:unset --no-restart "$app" "$sobra" >/dev/null
    listo "$app: fuera $sobra (la URL del superusuario)"
  done
done

# ── 5 · La puerta de afuera ───────────────────────────────────────────────────
paso "Firewall"
# A internet solo se abren el 80 y el 443. El SSH, nunca: entra desde la red de
# la casa, desde Tailscale, y desde donde se esté corriendo esto (así este
# mismo script no deja afuera a quien lo corre, sea la casa o el ensayo).
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw allow from "$RED_DE_LA_CASA" to any port 22 proto tcp >/dev/null
ufw allow in on tailscale0 to any port 22 proto tcp >/dev/null
# Quien está conectado por SSH ahora mismo se pregunta a `ss`: con sudo no llega
# SSH_CLIENT. La VM del ensayo entra por vsock, que no es TCP ni pasa por aquí.
clientes=$(ss -Htn state established '( sport = :22 )' | awk '{print $4}' \
  | sed -E 's/:[0-9]+$//' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u || true)
for ip in $clientes; do
  ufw allow from "$ip" to any port 22 proto tcp >/dev/null
done
ufw --force enable >/dev/null
listo "abiertos: 80 y 443 · SSH: $RED_DE_LA_CASA, Tailscale${clientes:+ y $(echo $clientes)}"

# ── 6 · Que se cuide sola ─────────────────────────────────────────────────────
paso "Actualizaciones y vigilante"
# Solo las de seguridad de Debian, y sin reiniciar: un reinicio a las 4 a. m.
# cortaría la siembra de la muestra.
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'APT'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT
listo "actualizaciones de seguridad automáticas"
# Si el kernel se cuelga, el chip vigilante de la tarjeta madre la reinicia. Una
# máquina sin monitor ni teclado no tiene a nadie más que lo haga.
if [ -e /dev/watchdog ]; then
  mkdir -p /etc/systemd/system.conf.d
  printf '[Manager]\nRuntimeWatchdogSec=60s\n' > /etc/systemd/system.conf.d/siga-vigilante.conf
  systemctl daemon-reexec
  listo "vigilante de hardware: 60 s"
else
  listo "sin vigilante de hardware (esta máquina no trae uno)"
fi

# ── 7 · El respaldo de cada noche ─────────────────────────────────────────────
paso "Respaldo"
dir_scripts=$(cd "$(dirname "$0")" && pwd)
install -m 700 "$dir_scripts/respaldar.sh" /usr/local/sbin/respaldar-siga
# Los respaldos tienen notas de menores: los lee root, y el administrador para
# bajarlos a la Mac.
install -d -m 750 -g "$ADMIN" /var/backups/siga
cat > /etc/cron.d/siga-respaldo <<'CRON'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
30 3 * * * root /usr/local/sbin/respaldar-siga
CRON
listo "cada noche a las 3:30, en /var/backups/siga"

# ── 8 · Cómo quedó ────────────────────────────────────────────────────────────
paso "Cómo quedó"
for app in "${APPS[@]}"; do
  servicio="$app-db"
  marcas=$(docker exec "dokku.postgres.$servicio" psql -U postgres -tAc \
    "SELECT rolsuper || '|' || rolbypassrls FROM pg_roles WHERE rolname = 'siga_app'")
  [ "$marcas" = "false|false" ] || falla "$app: siga_app es superusuario o salta el RLS ($marcas)"
  listo "$app · $servicio · siga_app sin SUPERUSER ni BYPASSRLS"
done
echo
echo "Falta, en este orden:"
echo "  1 · los datos       restaurar.sh siga < volcado   (y siga-demo)"
echo "  2 · las variables   variables.sh, copiadas de Contabo"
echo "  3 · el código       git push dokku-casa main      (el release corre rls:verificar)"
