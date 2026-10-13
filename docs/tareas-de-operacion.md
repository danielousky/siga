# Las tareas de operación

Lo que se puede hacer contra producción sin abrir una consola, y cómo.

```
   ssh dokku@siga-deploy run siga bin/rails <tarea>
```

⚠️ **`bin/rails runner` NO sirve por esta vía.** La orden pasa por dos shells y
el segundo se come las comillas, los `;` y los bloques: se pierden quince
minutos peleando con el escape justo cuando alguien está esperando afuera. Y
peor: **su salida no vuelve** — el comando corre y no se ve nada. Las tareas
`rake` sí devuelven su texto. Por eso todo lo de acá es una tarea.

---

## Soporte · el día a día

### Alguien no puede entrar

```bash
bin/rails soporte:acceso CORREO=alguien@dominio.com
```

Devuelve un enlace de un solo uso: la persona elige su contraseña ahí. **Dura 6
horas.** Sirve para cualquiera que tenga un rol —equipo de SIGA, dirección,
profesor, representante, y también el alumno que tenga correo.

⚠️ **Nadie llega a saber la contraseña, ni siquiera quien corre la tarea.** Eso
es a propósito: una clave que viaja por WhatsApp es una clave que se queda ahí.

⚠️ Generar un código nuevo **invalida el anterior** si no se había usado.

### Ver qué cuentas tiene un colegio

```bash
bin/rails soporte:cuentas               # los dos últimos colegios creados
bin/rails soporte:cuentas COLEGIO=10    # uno en particular
```

Solo LEE. Dice quién puede entrar, con qué rol y si tiene contraseña puesta.

⚠️ Es la manera correcta de mirar producción. En una consola, `Admin.count`
devuelve **0** aunque haya administradores: el aislamiento por colegio (RLS)
sin `Current.school` no devuelve todas las filas — devuelve **cero**, que es el
modo correcto de fallar. Esta tarea usa `sin_aislamiento`.

### Cambiarle el rol a un administrador

```bash
bin/rails soporte:rol CORREO=alguien@colegio.edu ROL=director
```

Los roles: `desarrollador · director · asistente · coordinador · secretaria ·
finanzas`. Dice en qué colegio lo cambió — una persona puede administrar dos.

### Quitarle a alguien un rol que no debería tener

```bash
bin/rails soporte:quitar_rol ROL=representative USUARIO=630 COLEGIO=5
```

Pide los tres datos explícitos y no adivina ninguno: una tarea de soporte que
borra «por el último» es la que un día borra el que no era.

### Dar de alta a alguien del equipo de SIGA

```bash
bin/rails soporte:equipo CORREO=… NOMBRE=… APELLIDO=… [ROL=fundador]
```

`fundador` ve todo; `operaciones`, la gestión comercial. Devuelve el enlace de
activación en la misma corrida.

---

## La prueba de campo · un colegio limpio para que alguien lo use

```bash
bin/rails prueba:campo          # lo monta: 1 sección, 10 alumnos, 1 maestra
bin/rails prueba:activar_plan   # si ya existe y no puede calificar
bin/rails prueba:borrar         # se lo lleva entero
```

⚠️ **Llega VACÍO a propósito.** No hay plan, ni evaluaciones, ni notas: quien
prueba tiene que hacer la vuelta completa. La demo, en cambio, tiene el trabajo
ya hecho — sirve para MOSTRAR, no para que alguien pruebe planificar.

⚠️ Y lleva marca: correos `@prueba.test` y cédulas `PRUEBA001`. Por eso
`prueba:borrar` es confiable.

---

## La muestra · el colegio que se enseña

`https://demo.sigaeducando.com` es **otra app** del mismo servidor, con su
propia base. No es producción y no comparte nada con ella.

```
   PRODUCCIÓN                          LA MUESTRA
   app   siga        remoto dokku      app   siga-demo      remoto dokku-demo
   base  siga-db                       base  siga-demo-db
   sigaeducando.com                    demo.sigaeducando.com   SIGA_MUESTRA=1
```

⚠️ **El nombre de la app va en cada orden.** `run siga …` es producción;
`run siga-demo …` es la muestra. Las tareas de abajo se niegan en producción,
pero el resto de este archivo no.

```bash
# Qué hay y si las puertas abren, sin tocar nada
ssh siga-deploy run siga-demo bin/rails muestra:estado

# Restablecerla AHORA (lo hace sola cada noche, a las 4:00 a. m.)
ssh siga-deploy run siga-demo bin/rails muestra:restablecer

# Subirle código nuevo
git push dokku-demo <rama>:main
```

`muestra:restablecer` **borra la base entera y la vuelve a sembrar**. Se niega
si la instancia no se declaró muestra, y se niega si en la base hay un colegio
que no sea de la muestra. Borrar y sembrar van en una sola transacción: si la
siembra falla, queda como estaba.

⚠️ **En el servidor tarda unos catorce minutos** (en una portátil, tres), y no
dice nada hasta que termina. Mientras corre, quien ya está adentro sigue viendo
los datos de antes; pero quien intente ENTRAR se queda esperando, porque entrar
escribe en una fila que la siembra tiene tomada. De noche no importa. De día,
hay que avisarle a quien la esté enseñando.

**Lo que falta ponerle, y solo sabe Daniel:**

```bash
# El WhatsApp de SIGA: sin él, la muestra no dibuja el botón. Ahí nadie entra
# a /siga, así que sale de la variable —vale mientras no haya fila en `setup`—.
# config:set reinicia la app: no hace falta resembrar (desde la 1.18.1).
ssh siga-deploy config:set siga-demo SIGA_WHATSAPP=0414XXXXXXX

# Para entrar a /siga DENTRO de la muestra (por defecto, nadie puede)
ssh siga-deploy config:set siga-demo SIGA_SEED_STAFF_PASSWORD=<una-clave>
ssh siga-deploy run siga-demo bin/rails muestra:restablecer
```

**Y producción tiene que saber dónde vive la muestra**, o su portada no dibuja
el botón «Vea un colegio funcionando». Es un ajuste, no una variable: se
escribe en el `/siga/ajustes` de producción, en «El colegio de muestra»:

```
   https://demo.sigaeducando.com
```

Hasta la 1.18.1 era la variable `SIGA_MUESTRA_URL`, que ya no se lee: si una
instancia la tenía puesta, la migración pasó su valor a la tabla `setup`.

⚠️ **No copiarle las variables de producción «para que llegue el correo».** La
muestra no manda correo a propósito: quien la visita puede escribir cualquier
dirección en una ficha y tocar «Enviar».

**En local**, sin tocar la base de desarrollo:

```bash
SIGA_DB_NAME=siga_muestra bin/rails db:create
psql -d siga_muestra -f db/structure.sql
SIGA_MUESTRA=1 SIGA_DB_NAME=siga_muestra bin/rails muestra:restablecer
SIGA_MUESTRA=1 SIGA_DB_NAME=siga_muestra bin/rails server -p 3100
```

## La demo · mirar y limpiar

```bash
bin/rails demo:inventario      # qué hay, sin tocar nada
bin/rails demo:procedencia     # quién creó cada colegio y qué tiene adentro
bin/rails demo:es_solo_demo    # ¿es seguro borrar?
```

### Borrar todo

```bash
bin/rails demo:limpiar
```

⚠️ **Esto vacía la base entera y no se puede deshacer.** Exige tres cosas:

```
   SIGA_ENTORNO_DEMO=1           la puerta fuera de desarrollo
   SIGA_RESPALDO_VERIFICADO=1    lo dices tú, después de respaldar DE VERDAD
   SIGA_BORRAR_TAMBIEN=…         los DEA de los colegios que no son demo
```

⚠️ **`SIGA_BORRAR_TAMBIEN` va por CÓDIGO DEA, no por nombre.** Con el nombre
dice «NO EXISTE ningún colegio con ese código» y aborta — que es lo correcto,
pero se lee como un error de otra cosa.

⚠️ **Las variables no se pueden pasar en la misma línea del `run`**: el `env`
del contenedor parte el valor en el primer espacio. Se ponen como config del
app, se corre, y **se quitan inmediatamente**:

```bash
ssh dokku@siga-deploy config:set --no-restart siga SIGA_ENTORNO_DEMO=1 …
ssh dokku@siga-deploy run siga bin/rails demo:limpiar
ssh dokku@siga-deploy config:unset --no-restart siga SIGA_ENTORNO_DEMO …
```

Dejar `SIGA_ENTORNO_DEMO=1` puesto es dejar abierta la puerta que impide
sembrar datos de prueba en la base de un colegio real.

⚠️ **Se lleva también `planteles_oficiales`**, que no es de ningún colegio: hay
que resembrarlo o el registro se queda sin sugerencias y `/colegios` sale vacío.

```bash
bin/rails catalogo:planteles
```

### Respaldar antes

```bash
ssh dokku@siga-deploy postgres:export siga-db > respaldo-$(date +%Y%m%d).dump
pg_restore -l respaldo-….dump | grep -c 'TABLE DATA'   # comprobarlo
```

⚠️ Un respaldo que no se abrió no es un respaldo.

---

## Las notas

```bash
bin/rails notas:recalcular     # repara promedios viejos; es idempotente
```

Hace falta cuando el worker estuvo caído: los promedios se recalculan por job, y
sin worker la cola se acumula.

---

## Cobrar · no es una tarea: es una pantalla

Desde la 1.15.0 un colegio pasa de gratis a pagar sin que nadie abra una
terminal (spec `docs/specs/del-registro-al-cobro.md`).

```
   el colegio      Finanzas ▸ Suscripción ▸ Reportar el pago
   SIGA            /siga/cartera   «Pagos por validar»: Validar, o Rechazar con motivo
                   /siga/ajustes   el WhatsApp, la muestra y los cuatro medios
```

⚠️ **Lo primero, en una instalación nueva, es cargar los ajustes.** Sin datos
para pagar, «Suscripción» le dice al colegio que todavía no hay medios
cargados, y sin WhatsApp no aparece el botón en ninguna pantalla.

⚠️ **Validar y cambiar los ajustes es de `fundador`**; `operaciones` los ve.

⚠️ **`demo:limpiar` NO se lleva los ajustes**: son de la plataforma, no de la
demo.

`prueba:activar_plan` sigue existiendo como atajo, y solo para el colegio de
prueba.

### La escalera corre sola

Todos los días a las 8 de la mañana (12 UTC) un trabajo mueve el estado de cada
suscripción y manda el aviso que toque: cinco días antes de vencer, al vencer y
al pasar a solo lectura. Cada uno sale una vez.

```bash
bin/rails suscripciones:estado      # en qué está cada colegio y qué aviso le toca hoy
bin/rails suscripciones:escalera    # correrla a mano: si el worker estuvo caído
```

⚠️ **Los correos los despacha el worker.** Si la cola está parada, la escalera
mueve los estados y anota los avisos, pero no sale nada hasta que arranque.

### Los ajustes, desde la consola

Lo normal es `/siga/ajustes`. Los ajustes sueltos —WhatsApp, dirección de la
muestra, Binance y PayPal— también se cargan desde la terminal, y es la única
manera en la muestra, donde nadie entra a `/siga`:

```bash
bin/rails ajustes:estado                                      # qué vale cada uno, sin tocar nada
AJUSTE=paypal VALOR=pagos@ejemplo.com bin/rails ajustes:poner # pasa por las mismas reglas que la pantalla
AJUSTE=paypal VALOR= bin/rails ajustes:poner                  # lo vacía: deja de ofrecerse
```

En el servidor las variables no van en la línea del `run` (el `env` del
contenedor parte el valor en el primer espacio): se ponen, se corre, y se
quitan.

```bash
ssh siga-deploy config:set --no-restart siga AJUSTE=paypal VALOR=pagos@ejemplo.com
ssh siga-deploy run siga bin/rails ajustes:poner
ssh siga-deploy config:unset --no-restart siga AJUSTE VALOR
```

⚠️ **Los correos de Binance y PayPal no se escriben en el repositorio**: son los
de Daniel. Viven en la base de cada instancia.

---

## Lo que NO tiene tarea todavía

- **Dar una cortesía o un piloto.** Es una suscripción activa a 0 $ con su
  vencimiento, y no hay pantalla que la abra: hoy un colegio se activa solo
  validándole un pago. Mientras tanto, el rodeo sin terminal es entrar al
  colegio desde `/siga/colegios` («Entrar al colegio»), reportar un pago en
  efectivo desde «Suscripción» y validarlo en la Cartera: queda activo un mes,
  con el precio de ese día anotado aunque nadie lo haya cobrado.
- **Deshacer una validación.** Si se validó el pago equivocado, no hay botón.
- **Definir lo que el colegio cobra.** Los conceptos existen en la base y solo
  los crea `pagos:demo`.
