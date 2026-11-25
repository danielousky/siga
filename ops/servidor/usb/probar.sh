#!/usr/bin/env bash
# Prueba el ISO en una PC vieja de mentira (QEMU, x86 emulado), antes de que
# Daniel lo use en la de verdad.
#
#   ops/servidor/usb/probar.sh arrancar   # enciende la PC y deja el menú a la vista
#   ops/servidor/usb/probar.sh tecla down # mueve el menú (down, up, ret…)
#   ops/servidor/usb/probar.sh foto       # captura la pantalla en $PRUEBA/pantalla.png
#   ops/servidor/usb/probar.sh entrar     # arranca lo instalado, con SSH en el 2222
#   ops/servidor/usb/probar.sh entrar-otra  # lo mismo, sin el controlador USB: la
#                                         # tarjeta de red cambia de ranura PCI, y la
#                                         # red tiene que levantar igual (eth0)
#
# La PC de mentira tiene lo que hace difícil elegir el disco:
#
#   disco IDE de 20 GB          el interno: aquí TIENE que instalar
#   el ISO en un pendrive       arranca desde ahí, como en la casa
#   un pendrive de 32 GB        MÁS GRANDE que el disco, y anunciado como disco
#                               fijo (removable=off): si elegir-disco.sh mirara
#                               solo el tamaño, borraría este
#
# BIOS clásico (SeaBIOS), una tarjeta de red Intel e1000 y un procesador x86-64
# básico (qemu64), como una torre de hace quince años.
set -euo pipefail

PRUEBA="${PRUEBA:-/Volumes/Personal Info/Documentos/Desarrollo/SIGA/servidor-casa/prueba-qemu}"
ISO="${ISO:-$PRUEBA/../siga-casa.iso}"
MONITOR=/tmp/siga-qemu.sock
mkdir -p "$PRUEBA"

monitor() { printf '%s\n' "$*" | nc -U -w 2 "$MONITOR" >/dev/null; }

case "${1:-}" in
  arrancar)
    [ -f "$PRUEBA/disco.qcow2" ] || qemu-img create -q -f qcow2 "$PRUEBA/disco.qcow2" 20G
    [ -f "$PRUEBA/pendrive-grande.img" ] || mkfile -n 32g "$PRUEBA/pendrive-grande.img"
    rm -f "$MONITOR"
    qemu-system-x86_64 -accel tcg,thread=multi -cpu qemu64 -smp 2 -m 2048 \
      -drive file="$PRUEBA/disco.qcow2",if=ide,index=0 \
      -device qemu-xhci,id=xhci \
      -drive if=none,id=iso,file="$ISO",format=raw,readonly=on \
      -device usb-storage,bus=xhci.0,drive=iso,bootindex=0 \
      -drive if=none,id=pendrive,file="$PRUEBA/pendrive-grande.img",format=raw \
      -device usb-storage,bus=xhci.0,drive=pendrive,removable=off \
      -netdev user,id=red -device e1000,netdev=red \
      -vga std -display none -no-reboot \
      -monitor unix:"$MONITOR",server,nowait \
      > "$PRUEBA/qemu.log" 2>&1 &
    echo "encendida (pid $!); el menú sale en unos segundos"
    ;;
  tecla) monitor "sendkey ${2:?¿qué tecla?}" ;;
  foto)
    # A /tmp primero: el monitor de QEMU corta la ruta en el primer espacio.
    monitor "screendump /tmp/siga-pantalla.ppm"
    sleep 1
    sips -s format png /tmp/siga-pantalla.ppm --out "$PRUEBA/pantalla.png" >/dev/null
    echo "$PRUEBA/pantalla.png"
    ;;
  entrar|entrar-otra)
    rm -f "$MONITOR"
    usb=(-device "qemu-xhci,id=xhci")
    # La bash de macOS (3.2) no expande un arreglo vacío con `set -u`: de ahí
    # la forma ${usb[@]+…} de abajo.
    [ "$1" = entrar-otra ] && usb=()
    qemu-system-x86_64 -accel tcg,thread=multi -cpu qemu64 -smp 2 -m 2048 \
      -drive file="$PRUEBA/disco.qcow2",if=ide,index=0 \
      ${usb[@]+"${usb[@]}"} \
      -netdev user,id=red,hostfwd=tcp:127.0.0.1:2222-:22 -device e1000,netdev=red \
      -vga std -display none \
      -monitor unix:"$MONITOR",server,nowait \
      > "$PRUEBA/qemu-entrar.log" 2>&1 &
    echo "arrancando lo instalado (pid $!): ssh -p 2222 -i ~/.ssh/siga_deploy daniel@127.0.0.1"
    ;;
  *) sed -n '2,8p' "$0"; exit 1 ;;
esac
