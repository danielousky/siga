#!/bin/sh
# Lo último de la instalación, con el sistema nuevo montado en /target.
set -e
install -d -m 700 /target/home/daniel/.ssh
cp /cdrom/preseed/authorized_keys /target/home/daniel/.ssh/authorized_keys
chmod 600 /target/home/daniel/.ssh/authorized_keys
in-target chown -R daniel:daniel /home/daniel/.ssh

# El montaje corre desatendido, y sudo con clave lo detendría a preguntar.
echo 'daniel ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/daniel
chmod 440 /target/etc/sudoers.d/daniel

# SSH solo con llave: la clave de daniel sirve en la consola, y nada más.
printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin no\n' \
  > /target/etc/ssh/sshd_config.d/siga.conf

# La ficha del hardware, para leerla antes de confiarle nada (el instalador no
# trae lscpu: se lee de /proc).
{ date
  echo "procesador  $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
  echo "núcleos     $(grep -c '^processor' /proc/cpuinfo)"
  echo "memoria     $(awk '/^MemTotal/ {printf "%.1f GB", $2 / 1048576}' /proc/meminfo)"
  for b in /sys/block/sd* /sys/block/hd* /sys/block/nvme*; do
    [ -e "$b" ] || continue
    giro=$(cat "$b/queue/rotational")
    echo "disco       $(basename "$b") · $(( $(cat "$b/size") / 2097152 )) GB · $([ "$giro" = 1 ] && echo 'de platos' || echo 'sólido')"
  done
} > /target/root/hardware.txt 2>&1 || true

# La red no depende de dónde esté la tarjeta. Debian le pone a la tarjeta un
# nombre según su ranura (ens3, enp0s4…) y ata la red a ESE nombre: si un día se
# agrega o se mueve una tarjeta, el nombre cambia y la máquina arranca sin red,
# sin monitor ni teclado que lo digan. La prueba en QEMU lo encontró: con otra
# ranura PCI, la máquina instalada quedó muda. Con net.ifnames=0 la tarjeta es
# siempre eth0 (y eth1 si hubiera dos: la que tenga el cable toma la IP).
sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"$/GRUB_CMDLINE_LINUX="\1 net.ifnames=0 biosdevname=0"/' /target/etc/default/grub
in-target update-grub
cat > /target/etc/network/interfaces <<'RED'
# La escribió el instalador de SIGA (ops/servidor/usb/al-terminar.sh).
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug eth1
iface eth1 inet dhcp
RED
