#!/usr/bin/env bash
# Arma el ISO que instala la máquina de SIGA sin hacer preguntas (en la Mac).
#
#   ops/servidor/hacer-el-usb.sh
#
# Baja el netinst de Debian 13 (amd64) y verifica su firma. Le mete el preseed
# de usb/ y le agrega al menú una entrada, «Instalar SIGA - BORRA EL DISCO», que
# no viene marcada: hay que elegirla. Las demás entradas de Debian quedan como
# estaban.
#
# Deja en $DESTINO:
#   siga-casa.iso   lo que se graba en el pendrive (el comando lo imprime al final)
#   iso/            el original de Debian, para no bajarlo dos veces
#
# ⚠️ La clave de consola de `daniel` nace aquí, al azar. En el ISO va solo su
# resumen; la clave en limpio queda en references/, que no se sube. El SSH no
# la acepta: entra solo con la llave de la Mac (~/.ssh/siga_deploy.pub).
set -euo pipefail

DESTINO="${DESTINO:-/Volumes/Personal Info/Documentos/Desarrollo/SIGA/servidor-casa}"
LLAVE="${LLAVE:-$HOME/.ssh/siga_deploy.pub}"
ESPEJO=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
# La llave con que Debian firma sus imágenes («Debian CD signing key»).
FIRMA_DEBIAN=DF9B9C49EAA9298432589D76DA87E80D6294BE9B

aqui=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$(git -C "$aqui" rev-parse --git-common-dir)/.." && pwd)
REFERENCIAS="${REFERENCIAS:-$repo/references}"

falla() { echo "✗ $*" >&2; exit 1; }
command -v xorriso >/dev/null || falla "Falta xorriso: brew install xorriso"
OPENSSL=/opt/homebrew/opt/openssl@3/bin/openssl
[ -x "$OPENSSL" ] || falla "Falta OpenSSL 3 (el de macOS no sabe hacer el resumen SHA-512): brew install openssl@3"
[ -s "$LLAVE" ] || falla "No está la llave $LLAVE"

# ── 1 · El original de Debian, verificado ────────────────────────────────────
mkdir -p "$DESTINO/iso"
cd "$DESTINO/iso"
curl -fsSL -O "$ESPEJO/SHA256SUMS" -O "$ESPEJO/SHA256SUMS.sign"
if ! gpg --batch --list-keys "$FIRMA_DEBIAN" >/dev/null 2>&1; then
  gpg --batch --keyserver hkps://keyring.debian.org --recv-keys "$FIRMA_DEBIAN" >/dev/null 2>&1 \
    || falla "No pude traer la llave de Debian para verificar el ISO"
fi
gpg --batch --status-fd 1 --verify SHA256SUMS.sign SHA256SUMS 2>/dev/null | grep -q "VALIDSIG $FIRMA_DEBIAN" \
  || falla "SHA256SUMS no está firmado por Debian"
original=$(grep -E ' debian-[0-9.]+-amd64-netinst\.iso$' SHA256SUMS | awk '{print $2}')
[ -n "$original" ] || falla "No encontré el netinst en SHA256SUMS"
# cdimage redirige las imágenes a un espejo: sin -L se guarda la página del 302.
[ -f "$original" ] || curl -fSL --progress-bar -O "$ESPEJO/$original"
grep " $original\$" SHA256SUMS | shasum -a 256 -c --quiet - || falla "$original no coincide con su suma: bórralo y vuelve a correr"
echo "✓ $original, firmado por Debian"

# ── 2 · El preseed, la llave y la clave ──────────────────────────────────────
trabajo=$(mktemp -d)
trap 'rm -rf "$trabajo"' EXIT
mkdir -p "$trabajo/preseed"
cp "$aqui/usb/elegir-disco.sh" "$aqui/usb/al-terminar.sh" "$trabajo/preseed/"
cp "$LLAVE" "$trabajo/preseed/authorized_keys"

# Sin `tr < /dev/urandom | head`: con pipefail, `tr` muere de SIGPIPE y el
# script se corta ahí, sin decir nada (código 141).
clave=$("$OPENSSL" rand -hex 8)
resumen=$(printf '%s' "$clave" | "$OPENSSL" passwd -6 -stdin)
sed "s|@CLAVE@|$resumen|" "$aqui/usb/siga.cfg" > "$trabajo/preseed/siga.cfg"
mkdir -p "$REFERENCIAS"
umask 077
cat > "$REFERENCIAS/maquina-de-la-casa.txt" <<NOTA
La máquina de la casa (siga-casa) — clave de consola de «daniel»
Generada el $(date '+%d/%m/%Y %H:%M') por ops/servidor/hacer-el-usb.sh.

  $clave

Sirve SOLO en la consola, con teclado y monitor: el SSH no acepta claves,
entra con la llave ~/.ssh/siga_deploy. Si se arma otro USB, esta clave cambia.
NOTA
echo "✓ clave de consola en $REFERENCIAS/maquina-de-la-casa.txt (no se sube)"

# ── 3 · La entrada del menú, para BIOS viejo y para UEFI ─────────────────────
linea="auto=true priority=critical preseed/file=/cdrom/preseed/siga.cfg locale=es_VE.UTF-8 keymap=latam hostname=siga-casa domain="
xorriso -osirrox on -indev "$original" \
  -extract /isolinux/txt.cfg "$trabajo/txt.cfg" \
  -extract /isolinux/spkgtk.cfg "$trabajo/spkgtk.cfg" \
  -extract /boot/grub/grub.cfg "$trabajo/grub.cfg" >/dev/null 2>&1
chmod u+w "$trabajo/txt.cfg" "$trabajo/spkgtk.cfg" "$trabajo/grub.cfg"
# En BIOS, si nadie toca una tecla en 30 s, Debian arranca solo la instalación
# con voz (para quien no ve la pantalla). No borra nada, pero frente a una
# máquina vieja buscando las flechas, confunde: el menú espera sin límite.
grep -q '^timeout 300$' "$trabajo/spkgtk.cfg" || falla "spkgtk.cfg cambió: revisar la cuenta regresiva de la voz"
sed -i '' 's/^timeout 300$/timeout 0/' "$trabajo/spkgtk.cfg"
cat >> "$trabajo/txt.cfg" <<ISOLINUX
label siga
	menu label Instalar SIGA - BORRA EL DISCO
	kernel /install.amd/vmlinuz
	append $linea vga=788 initrd=/install.amd/initrd.gz --- quiet
ISOLINUX
cat >> "$trabajo/grub.cfg" <<GRUB

menuentry 'Instalar SIGA - BORRA EL DISCO' {
    set background_color=black
    linux    /install.amd/vmlinuz $linea vga=788 --- quiet
    initrd   /install.amd/initrd.gz
}
GRUB

# ── 4 · El ISO nuevo, con el arranque del original ───────────────────────────
rm -f "$DESTINO/siga-casa.iso"
xorriso -indev "$original" -outdev "$DESTINO/siga-casa.iso" \
  -map "$trabajo/preseed" /preseed \
  -map "$trabajo/txt.cfg" /isolinux/txt.cfg \
  -map "$trabajo/spkgtk.cfg" /isolinux/spkgtk.cfg \
  -map "$trabajo/grub.cfg" /boot/grub/grub.cfg \
  -boot_image any replay >/dev/null 2>&1
echo "✓ $DESTINO/siga-casa.iso ($(du -h "$DESTINO/siga-casa.iso" | cut -f1))"
cat <<'SIGUE'

Para grabarlo (⚠️ borra el pendrive): el disco del pendrive se ve con
`diskutil list external`. Con su número (N):
  diskutil unmountDisk /dev/diskN
  sudo dd if="…/siga-casa.iso" of=/dev/rdiskN bs=4m status=progress
SIGUE
