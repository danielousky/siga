# La máquina de SIGA

Todo lo que hace falta para montar el servidor de SIGA en una máquina propia,
y no a mano. Nació para mudar SIGA de Contabo a una máquina de la casa de Daniel
(el plan: https://claude.ai/artifact/KuZRqezfBQCq1zZxn9PoyJ). Sirve igual para
un VPS nuevo el día que haga falta.

```
   EN LA MAC                             EN LA MÁQUINA (root)
   hacer-el-usb.sh   el ISO que instala   montar.sh       Docker, Dokku, las dos apps, sus bases,
                     Debian sin preguntas                 el firewall, el respaldo de cada noche
   bajar-respaldo.sh la copia de cada     restaurar.sh    un volcado en la base de una app, con las
   (+ el .plist)     noche, a SIGA/                       tablas devueltas a siga_app
                     respaldos            variables.sh    las variables de Contabo, sin mostrarlas
                                          respaldar.sh    el de cada noche (lo instala montar.sh)
                                          poner-ddns.sh   el dominio sigue a la IP de la casa
```

## El orden

```
   USB ──► montar.sh ──► restaurar.sh ──► variables.sh ──► git push ──► poner-ddns.sh + certificados
           (el rol       (las tablas,     (las de          (el release   (el cambio: el dominio
           siga_app)     de siga_app)     Contabo)         verifica)     pasa a la casa)
```

⚠️ **El orden no es negociable.** El rol `siga_app` va antes de restaurar, y las
tablas restauradas tienen que quedar de `siga_app`. Si no, `FORCE ROW LEVEL
SECURITY` deja de evaluarse y los colegios se ven entre sí, con todo en verde.
El `release:` del Procfile corre `rls:verificar` y aborta el despliegue si eso
pasa. Ver `references/SERVIDOR-PRODUCCION.md § 10`.

## Los secretos

**Ningún archivo de esta carpeta tiene un secreto, y ningún script imprime
uno.**

```
   la clave de siga_app       nace en la máquina (montar.sh) y va directo a DATABASE_URL
   las variables de Contabo   viajan por un tubo ssh → ssh, en JSON, sin pasar por la pantalla
   la clave del DDNS          la escribe Daniel en la máquina, escondida (read -s)
   la clave de consola        la genera hacer-el-usb.sh; va al ISO solo su resumen, y en
                              limpio a references/maquina-de-la-casa.txt (que no se sube)
```

## Cómo se usa

```bash
# 1 · El USB (en la Mac). Después se graba con dd: el script dice cómo.
ops/servidor/hacer-el-usb.sh

# 2 · La máquina instalada se anuncia sola como siga-casa.local
rsync -a ops/servidor/ daniel@siga-casa.local:siga-ops/
ssh daniel@siga-casa.local 'sudo siga-ops/montar.sh'

# 3 · Los datos y las variables, de Contabo a la casa, sin mostrarse
ssh siga-deploy postgres:export siga-db      | ssh siga-casa 'sudo siga-ops/restaurar.sh siga'
ssh siga-deploy postgres:export siga-demo-db | ssh siga-casa 'sudo siga-ops/restaurar.sh siga-demo'
ssh siga-deploy config:export --format json siga      | ssh siga-casa 'sudo siga-ops/variables.sh siga'
ssh siga-deploy config:export --format json siga-demo | ssh siga-casa 'sudo siga-ops/variables.sh siga-demo'

# 4 · El código
git push dokku-casa main
```

## El ensayo

Antes de tocar la máquina, todo esto corre en una VM de Debian 13 en la Mac
(Lima, arm64, a velocidad nativa). Dokku corre igual en arm64, así que lo que
falla, falla ahí.

```bash
limactl start --name siga-ensayo --cpus 2 --memory 4 --disk 40 --vm-type vz template://debian-13
rsync -a -e "ssh -F ~/.lima/siga-ensayo/ssh.config" ops/servidor/ lima-siga-ensayo:siga-ops/
ssh -F ~/.lima/siga-ensayo/ssh.config lima-siga-ensayo 'sudo siga-ops/montar.sh'
# con ENSAYO=1, variables.sh deja afuera el correo: un ensayo no le escribe a nadie
```

## Lo que se mira

```bash
ssh siga-casa 'sudo tail -5 /var/backups/siga/respaldos.log'   # ¿corrió el respaldo?
ssh siga-casa 'sudo journalctl -u ddclient -n 20'              # ¿la IP de la casa está al día?
ssh siga-casa 'cat /root/hardware.txt'                          # lo que vio el instalador
ssh siga-casa 'sudo smartctl -H /dev/sda'                       # la salud del disco
```
