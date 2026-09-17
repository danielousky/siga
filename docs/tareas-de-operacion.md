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

## Lo que NO tiene tarea todavía

- **Cambiar el plan de un colegio.** Hoy se hace con `prueba:activar_plan`, que
  solo sirve para el colegio de prueba. Un colegio real que quiera pasar de
  gratis a pago no tiene por dónde.
- **Definir lo que el colegio cobra.** Los conceptos existen en la base y solo
  los crea `pagos:demo`.
