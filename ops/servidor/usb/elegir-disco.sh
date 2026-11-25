#!/bin/sh
# Elige el disco donde se instala la máquina de SIGA (corre dentro del
# instalador de Debian, con busybox: nada de bash).
#
# Descarta el medio de instalación, lo que cuelga de un USB y lo removible, y se
# queda con el más grande de lo que sobra. Si no queda ninguno, no elige nada y
# el instalador pregunta: mejor una pregunta que borrar el disco equivocado.
medio=$(mount | sed -n 's|^/dev/\([a-z]*\)[0-9]* on /cdrom .*|\1|p')
for d in $(list-devices disk); do
  b=${d#/dev/}
  [ "$b" = "$medio" ] && continue
  readlink -f "/sys/block/$b" | grep -q /usb && continue
  [ "$(cat "/sys/block/$b/removable")" = 1 ] && continue
  echo "$(cat "/sys/block/$b/size") $d"
done | sort -n | tail -1 | cut -d' ' -f2 > /tmp/disco
disco=$(cat /tmp/disco)
if [ -n "$disco" ]; then
  debconf-set partman-auto/disk "$disco"
  debconf-set grub-installer/bootdev "$disco"
  logger -t siga "disco elegido: $disco"
fi
