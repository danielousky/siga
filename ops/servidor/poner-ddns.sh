#!/usr/bin/env bash
# Hace que el dominio siga a la IP de la casa (en la máquina, en el cambio).
#
#   ssh -t siga-casa 'sudo siga-ops/poner-ddns.sh'
#
# Inter da IP pública, pero no fija: puede cambiar con un apagón. ddclient le
# pregunta a Namecheap cada 5 minutos cuál es la IP de la casa y, si cambió,
# reescribe `@`, `www` y `*`. Con el TTL de esos registros en 1 minuto, un
# cambio de IP se nota unos pocos minutos.
#
# ⚠️ La clave del DDNS se escribe aquí, escondida (`read -s`): no pasa por la
# conversación ni por el historial. Sale de Namecheap → Domain List →
# sigaeducando.com → Advanced DNS → Dynamic DNS.
#
# ⚠️ Correrlo APUNTA EL DOMINIO A LA CASA en menos de 5 minutos. Va en la
# tanda 5, de noche, con Contabo detenido.
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "✗ Corre como root (sudo)" >&2; exit 1; }
[ -t 0 ] || { echo "✗ Hace falta una terminal para escribir la clave: ssh -t …" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq ddclient >/dev/null

read -r -s -p "Clave de Dynamic DNS de Namecheap: " clave; echo
[ -n "$clave" ] || { echo "✗ Clave vacía" >&2; exit 1; }

umask 077
cat > /etc/ddclient.conf <<CONF
# La escribió ops/servidor/poner-ddns.sh. Tiene la clave del DDNS: solo root la lee.
daemon=300
syslog=yes
ssl=yes
use=web, web=dynamicdns.park-your-domain.com/getip
protocol=namecheap
server=dynamicdns.park-your-domain.com
login=sigaeducando.com
password='$clave'
@, www, *
CONF
unset clave
systemctl enable --now ddclient >/dev/null 2>&1 || true
systemctl restart ddclient
sleep 5
ddclient -query 2>/dev/null | tail -2 || true
echo "✓ ddclient corre cada 5 min · se mira con: sudo journalctl -u ddclient -n 20"
