# Emitir documentos en segundo plano

> **Estado:** **cerrado sin construir** — 5 de octubre de 2026
> **PR:** — (no hay código)

---

## 0 · Qué se decidió

```
   1 oct   una sección: 26 s   ──►   «tabla a mano + segundo plano»
   5 oct   una sección:  2 s   ──►   «dejarlo como está»
```

Daniel, con los números de hoy delante y tres opciones —medir primero,
construirlo, o dejarlo—, eligió **dejarlo como está**. La emisión sigue en
línea: se pide el documento y baja el archivo.

**Se reabre si un colegio se queja de la espera.** Ese día lo primero es el
camino A de § 5 —medir cuánto tarda de verdad en producción—, que cuesta medio
día y dice si hace falta el B.

Lo que sigue queda como estaba al discutirlo: es el registro de qué se evaluó y
por qué no se hizo, para no investigarlo otra vez desde cero.

---

## 1 · El problema

Daniel, 1 de octubre de 2026, emitiendo los boletines de 4to Grado A:

> *«La generación de documentos tarda mucho, debemos encontrar una forma de
> hacerlo en streaming… en producción seguro explota con error por time.»*

Tenía razón ese día: eran **26 segundos** para 21 alumnos, y Dokku corta una
petición a los 60. Entre las tres salidas que se le propusieron eligió la más
completa: reescribir la tabla **y además** emitir en segundo plano.

⚠️ **Desde entonces el problema cambió de tamaño**, y este spec existe para que
la segunda mitad se decida con los números de hoy y no con los de ese día:

```
   UNA SECCIÓN ENTERA, EN LOCAL          1 OCT        5 OCT
   ────────────────────────────          ─────        ─────
   primaria con su plan · 21 alumnos     26,3 s       2,2 s
   Media, de lapso · 22 alumnos           3,6 s       1,7 s
   Media, anual · 22 alumnos              2,8 s       1,1 s
   certificados · 20 alumnos                           0,8 s
   31059 · 22 alumnos                                  2,4 s
```

El caso peor que existe hoy —una sección de cuarenta alumnos de primaria con
todo su plan— son unos **4 segundos**.

**Lo que NO se sabe:** cuánto más lento es el servidor que la máquina de Daniel.
Con un factor de tres, el caso peor serían 12 segundos: lejos de los 60, pero
una espera larga mirando un botón que no dice nada.

## 2 · Qué NO entra

```
   ENTRA                               NO ENTRA
   ─────                               ────────
   boletines, constancias y            «emitir todo el colegio de una vez»:
   certificados por sección            no existe, y sería otro spec
   saber cuánto tarda en producción    enviar los PDF por correo a la familia
                                       el cierre del lapso: guarda los boletines
                                       y encola los correos; ya tarda 1,3 s
```

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Se construye la emisión en segundo plano ahora? | **No: se deja como está.** Se reabre si un colegio se queja de la espera | Daniel, 5 oct. |
| 2 | Si se hace: ¿siempre, o solo «toda la sección»? | sin decidir — propuesta: solo la sección; un alumno sale en el acto | — |
| 3 | Si se hace: ¿cuánto se guarda el archivo? | sin decidir — propuesta: 24 horas, y se borra solo | — |
| 4 | Si se hace: ¿qué pasa con el worker caído? | sin decidir — propuesta: a los 30 s la pantalla ofrece emitir en el acto | — |

## 4 · El dominio

- **Dokku corta la petición a los 60 segundos** (`proxy-read-timeout`, que el
  repo no cambia). Es el único límite duro.
- **El worker no es opcional pero se cae** (`CLAUDE.md § 4`): `/salud` avisa
  cuando la cola no avanza, y hoy nadie lo mira. Todo lo que pase a depender del
  worker hereda ese riesgo — con la emisión en el acto, un worker caído no le
  impide a la secretaria sacar un boletín.
- **Un colegio con la suscripción vencida sigue emitiendo** (`§ 7`), y el plan
  gratuito no. Las dos listas de `RespetaLaSuscripcion` son por controlador y
  acción: una puerta nueva hay que anotarla en las dos, como pasó con los
  certificados.
- ⚠️ **El colegio de un job viaja en su carga** (`CarriesSchool`). Un job que
  dibuja documentos sin colegio fijado no ve ni una fila.

## 5 · Cómo se ve

⚠️ Ninguno de los dos se eligió (§ 0). Quedan descritos por si se reabre.

**Camino A — medir primero (lo que se recomendó).** No se construye nada que
dependa del worker. Dos cosas chicas:

```
   [ Emitir y descargar ]   ──clic──►   [ Preparando el PDF… ]   (apagado)
                                         vuelve solo cuando baja el archivo

   Registro de actividad
   Ramón Díaz emitió 21 boletines de 4to Grado – A (1er Lapso)   ·   2,4 s
```

Con el tiempo de cada emisión anotado, en dos semanas de uso real se sabe si
algún colegio se acerca siquiera a los diez segundos. Si ninguno, este spec se
cierra como «no hizo falta».

**Camino B — segundo plano.** Solo para «toda la sección»:

```
   [ Emitir y descargar ]
            │
            ▼
   Preparando 21 boletines de 4to Grado – A…
   ░░░░░░░░░░░░░░░░░░░░   (la pantalla pregunta cada 2 s)
            │
            ▼
   ✓ Listos · [ Descargar el PDF ]        se guarda 24 horas

   Si pasan 30 s sin respuesta:
   «Está tardando más de lo normal» · [ Emitirlos ahora, sin esperar ]
```

Piezas: una tabla `emisiones` (con su política de RLS), un job que dibuja y
adjunta el archivo, la pantalla de espera, y otro job diario que borra los
archivos viejos. Uno o dos días de trabajo, con sus tests.

## 6 · Criterios de aceptación, si se reabre

Camino A:

- [ ] Al enviar el formulario el botón se apaga y dice «Preparando el PDF…», y
      vuelve a estar disponible cuando la descarga empieza.
- [ ] Cada emisión de boletines, constancias y certificados deja en la
      auditoría cuántos segundos tardó.
- [ ] Sin JavaScript el formulario sigue emitiendo.

Camino B, además:

- [ ] «Toda la sección» crea una emisión y lleva a la pantalla de espera; un
      alumno solo se descarga en el acto.
- [ ] La emisión de otro colegio da 404.
- [ ] Con el worker detenido, a los 30 segundos se puede emitir en el acto.
- [ ] El archivo se borra a las 24 horas; la fila de quién emitió qué, no.
- [ ] Vencida emite; el plan gratuito no.

## 7 · Lo que se puede romper

- **Camino A:** un botón que se apaga y no vuelve. La descarga de un archivo no
  dispara ningún evento en la página, así que «volver» tiene que resolverse sin
  esperar uno — o la secretaria queda con el botón muerto y recarga.
- **Camino B:** el worker caído deja de ser «los promedios quedan viejos» y pasa
  a ser «no se pueden emitir boletines», el día de la entrega. La salida de los
  30 segundos es lo que lo hace tolerable, y es lo primero que hay que probar.
- **Camino B:** los archivos guardados son documentos con notas de menores. Hoy
  no existe ninguno en disco: se dibujan y se entregan.

## 8 · Cómo se verifica

`bin/ci`, y para el camino B un test de sistema con el worker detenido — es el
único caso que un test de integración no puede ver.
