#!/usr/bin/env bash
# Mete la máquina en el Tailscale de Daniel, para administrarla desde fuera de
# la casa (tanda 6 del plan).
#
#   ssh -t siga-casa 'sudo siga-ops/tailscale.sh'
#
# Imprime un enlace de login.tailscale.com: lo abre Daniel, con su cuenta, y
# la máquina queda en su red como `siga-casa`. Desde ahí `ssh siga-casa`
# funciona desde cualquier lado, sin abrir el 22 a internet: montar.sh ya deja
# entrar el SSH por la interfaz tailscale0.
#
# ⚠️ En la Mac, ProtonVPN y Tailscale juntos pueden pelearse. Desde la casa no
# hace falta Tailscale: la red local llega igual.
set -euo pipefail

[ "$(id -u)" = 0 ] || { echo "✗ Corre como root (sudo)" >&2; exit 1; }
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --hostname=siga-casa
tailscale ip -4 | sed 's/^/✓ en Tailscale: /'
