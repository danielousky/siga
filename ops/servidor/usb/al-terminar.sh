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

# La ficha del hardware, para leerla antes de confiarle nada.
{ date; echo; lscpu 2>/dev/null || cat /proc/cpuinfo; echo; free -m; echo; \
  for b in /sys/block/sd* /sys/block/hd* /sys/block/nvme*; do \
    [ -e "$b" ] && echo "$(basename "$b") $(( $(cat "$b/size") / 2097152 )) GB rotacional=$(cat "$b/queue/rotational")"; \
  done; } > /target/root/hardware.txt 2>&1 || true
