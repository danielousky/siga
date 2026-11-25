# El cambio: de Contabo a la máquina de la casa

La noche en que el dominio pasa a la casa (tanda 5 del plan). Son unos 30
minutos, con SIGA detenido entre el paso 2 y el 6.

```
   UN DÍA ANTES   TTL de 1 min en @, www y *            (Daniel, en Namecheap)
   ──────────────────────────────────────────────────────────────────────────
   1  la puerta    80 y 443 llegan a la máquina          check-host desde afuera
   2  Contabo      se detiene                            nadie escribe en la base vieja
   3  los datos    la base y los adjuntos, a la casa     restaurar.sh con FORZAR=1
   4  el candado   el certificado vigente, a la casa     cero minutos sin HTTPS
   5  el dominio   ddclient escribe la IP de la casa     (Daniel teclea la clave del DDNS)
   6  verificar    desde afuera, con el certificado      /salud, s_client, HSTS
   7  renovar      Let's Encrypt queda en la casa
   ──────────────────────────────────────────────────────────────────────────
   VUELTA ATRÁS   el DNS a 80.190.77.167 y Contabo se enciende otra vez
```

⚠️ Contabo se queda como estaba hasta que venza el mes: es la vuelta atrás.

## Antes: el TTL

En Namecheap, en Advanced DNS, `@`, `www` y `*` pasan a **1 min**. Con el TTL de
fábrica (30 min), un error en el cambio se arrastra media hora.

## 1 · La puerta

Los dos reenvíos están puestos (el ONT al Dahua y el Dahua a la máquina), y desde
afuera el 80 y el 443 llegan a la máquina. La máquina contesta 444 a cualquier
nombre que no sea suyo, así que basta con que la conexión abra:

```bash
curl -s -H "Accept: application/json" "https://check-host.net/check-tcp?host=<IP de la casa>:443&max_nodes=6"
```

## 2 · Contabo se detiene

```bash
ssh siga-deploy ps:stop siga
ssh siga-deploy ps:stop siga-demo
```

Desde aquí, quien abra SIGA ve un error de Contabo hasta el paso 5.

## 3 · Los datos, a la casa

La casa ya tiene una base de la tanda 4; esta la reemplaza con la de ahora mismo.

```bash
ssh siga-deploy postgres:export siga-db      | ssh siga-casa 'sudo FORZAR=1 siga-ops/restaurar.sh siga'
ssh siga-deploy postgres:export siga-demo-db | ssh siga-casa 'sudo FORZAR=1 siga-ops/restaurar.sh siga-demo'
for v in siga-storage siga-demo-storage; do
  ssh siga "tar czf - -C /var/lib/dokku/data/storage $v" \
    | ssh siga-casa "sudo tar xzf - -C /var/lib/dokku/data/storage && sudo chown -R 1000:1000 /var/lib/dokku/data/storage/$v"
done
ssh siga-casa 'sudo dokku ps:restart siga && sudo dokku ps:restart siga-demo'
```

`restaurar.sh` dice, al terminar, cuántos colegios y personas trae. Tienen que ser
los mismos que en Contabo.

## 4 · El candado

El certificado de Let's Encrypt que tiene Contabo vale hasta enero. Copiado, la
casa sirve HTTPS desde el primer minuto, antes de pedir uno propio.

```bash
for app in siga siga-demo; do
  ssh siga "tar cf - -C /home/dokku/$app/tls server.crt server.key" \
    | ssh siga-casa "sudo dokku certs:add $app"
done
```

## 5 · El dominio

⚠️ Este paso es el que apunta sigaeducando.com a la casa. Lo corre Daniel, porque
pide la clave de Dynamic DNS de Namecheap y la escribe escondida:

```bash
ssh -t siga-casa 'sudo siga-ops/poner-ddns.sh'
dig @dns1.registrar-servers.com +short sigaeducando.com   # hasta que diga la IP de la casa
```

## 6 · Verificar desde afuera

```bash
curl -s https://sigaeducando.com/salud                          # la versión y la revisión de la casa
curl -sI https://sigaeducando.com/ | grep -ci strict-transport  # 1: HSTS lo emite solo Rails
echo | openssl s_client -connect sigaeducando.com:443 -servername sigaeducando.com 2>/dev/null \
  | openssl x509 -noout -issuer -enddate
```

Y check-host contra `https://sigaeducando.com/up` desde seis países. Desde la red
de la casa puede fallar sin que nada esté mal (el «hairpin»): se mira desde afuera,
o con los datos del teléfono.

## 7 · Renovar desde la casa

El correo que usa Contabo para Let's Encrypt se ve con
`ssh siga-deploy letsencrypt:report siga`, y en la casa va el mismo.

```bash
ssh siga-casa 'sudo dokku letsencrypt:set --global email <el de Contabo>'
ssh siga-casa 'sudo dokku letsencrypt:enable siga && sudo dokku letsencrypt:enable siga-demo'
ssh siga-casa 'sudo dokku letsencrypt:cron-job --add'
```

Después, en la Mac, `siga` y `siga-deploy` de `~/.ssh/config` pasan a la máquina,
y los remotos de git no cambian.

## Vuelta atrás

Si algo del 1 al 6 no queda bien:

1. En Namecheap, apagar Dynamic DNS y poner `@`, `www` y `*` en `80.190.77.167`.
2. `ssh siga-deploy ps:start siga && ssh siga-deploy ps:start siga-demo`
3. Con el TTL en 1 min, en unos minutos todo vuelve a Contabo, con los datos de
   antes del paso 2: no se escribió nada en medio.
