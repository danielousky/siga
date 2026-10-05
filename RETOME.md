# 🔖 Punto de retome — actualizado 5 de octubre de 2026

## Dónde está cada cosa

```
   PRODUCCIÓN                          1.10.1 · 0b1997a · sin colegios cargados
   origin/main                         0b1997a — lo mismo que producción
   main, en local                      + 1 commit de Daniel sin subir (el logo sin fondo)
   feat/certificados-en-documentos     + 11 commits · 1.11.0 · NADA subido
```

⚠️ **Nada de 1.11.0 salió de esta máquina.** Ni la rama, ni el tag, ni el
despliegue: se sube cuando Daniel lo diga.

## 1.11.0 — qué trae

```
   ① los certificados, en «Documentos»      la tercera pestaña; de un alumno o de la sección
   ② emitir una sección de boletines        de 26 segundos a 2
   ③ el boletín en las hojas justas         el pie ni cortado ni solo en su hoja
   ④ el de bachillerato, en UNA hoja        la comparación con la sección, dentro de la tabla de notas
   ⑤ dos arreglos que aparecieron leyendo   el documento de Inicial reventaba desde la ficha;
      los PDF                                la 31059 salía sin el año en la fecha de expedición
```

Lo que hay que saber de cómo está hecho vive en `CLAUDE.md § 11` (los
certificados) y `§ 12` (el boletín en papel). `bin/ci` en verde.

## Lo que falta para cerrarla

```
   ▸ que Daniel revise los PDF en local        director.bolivar@siga.edu · Documentos
       1er Año A, 1er lapso      →  una hoja por alumno, con la comparación
       4to Grado A, 1er lapso    →  dos hojas por alumno, la segunda con las notas y el pie
   ▸ subir la rama · PR · merge · tag v1.11.0 · desplegar     ← cuando Daniel diga
```

Daniel, 5 de octubre: **«espera a que la revise»**. No se sube nada hasta que
lo diga.

## Emitir en segundo plano: decidido, y es que no

```
   1 oct   una sección: 26 s   ──►   «tabla a mano + segundo plano»
   5 oct   una sección:  2 s   ──►   «dejarlo como está»
```

La primera mitad se hizo y volvió innecesaria a la segunda. El registro de lo
que se evaluó está en `docs/specs/emision-en-segundo-plano.md`, **cerrado sin
construir**. Se reabre si un colegio se queja de la espera.

## Visto y sin tocar

```
   ▸ el boletín de Inicial en PDF         sale con una tabla de «Sin nota» y la nota de la
                                          escala del 1 al 20: el boletín no lee la valoración
                                          descriptiva. Quedó fuera del spec de Inicial.
   ▸ la cédula de quien firma             «V-12884476» en el documento de Inicial y
                                          «12884476» en el de primaria y en la 31059
   ▸ armar los datos de una sección       ~55 consultas por alumno para un plan evaluado
                                          que es el mismo para toda la sección
   ▸ el código QR                         16 ms cada uno: entre un tercio y la mitad de lo
                                          que tarda dibujar un boletín
   ▸ la tarjeta de Linear de los          el conector estaba desconectado; los certificados
     certificados                         existían desde MOR-99 y nadie los encontraba
   ▸ el manual                            sin captura de la pestaña «Certificados»
   ▸ `/salud`                             sigue sin un monitor que lo mire
```

⚠️ **Del 12 al 24 de septiembre salieron de la 0.9.0 a la 1.10.1** —el informe
descriptivo, el cierre del lapso, el indicador dentro de su evaluación, el alta
de evaluaciones en la fila del plan— y este archivo no se actualizó. Qué trajo
cada versión está en [`CHANGELOG.md`](CHANGELOG.md), y por qué, en `CLAUDE.md`.

---

# Retome del 11 de septiembre de 2026 (00:50)

> Lo de aquí hacia abajo quedó como estaba ese día. Sirve de historia; **el
> estado de hoy es el de arriba.**

## Producción limpia y resembrada (MOR-146 · MOR-224)

```
   18:42   respaldo exportado y VERIFICADO restaurándolo en otra base
   19:19   borrado — 320 personas, 293 alumnos, 20 boletines
   19:22   resiembra con los datos nuevos
   19:25   las cuatro credenciales de los brokers, probadas contra prod
```

**El respaldo está en `~/Documents/siga-respaldos/siga-prod-20260905-1842.dump`.**
No se declaró: se restauró en una base aparte y se contaron las filas.

### Lo que había, y qué se decidió

El guarda encontró **cuatro colegios, no dos**. Dos los había registrado
alguien por `/registrarse`:

```
   U.E. Ceapucv    PD123123   Yoleima Contreras   3 alumnos, 2 profesores
   LA ESCUELITA    PD123125   Daniel              vacío
```

Le consulté a Daniel por el de Yoleima antes de tocar nada —es el trabajo de
una persona real que no está en la conversación— y autorizó borrar los dos.

### Lo que quedó en producción

```
   U.E. SIMÓN BOLÍVAR — los tres niveles + Media Técnica
     Educación Inicial    3 grados ·  54 alumnos
     Educación Primaria   6 grados · 190 alumnos
     Educación Media      6 grados · 116 alumnos
                                     ───
                                     360   →  plan Estándar
   U.E. ANDRÉS BELLO — el segundo inquilino, con la suscripción VENCIDA
```

Las cuatro credenciales de los brokers siguen siendo las mismas, probadas una
por una: `director.bolivar@siga.edu`, `prof.garcia@bolivar.edu`,
`maria.perez@familia.test`, `alvaro.lopez001@bolivar.edu` — todas con `123123`.

### ⚠️ Dos cosas que se rompieron ejecutando, y quedaron arregladas

**El guarda comparaba nombres literales**, y `School` los guarda en MAYÚSCULA:
declaraba que la propia demo «no era de la demo». En producción pasaba por
casualidad —ahí los nombres son los viejos—, o sea que dependía de cuándo se
había sembrado la fila. Ahora identifica por **código DEA**, que además no
tiene espacios: `dokku run` parte el comando por espacios y «U.E. Ceapucv»
llegaba despedazado.

**El orden de borrado estaba escrito a mano y falló dos veces** —`siga_staffs`
y `importaciones`— y le faltaban las cinco tablas de MOR-136 y MOR-216. Una
lista de dependencias a mano es una copia del esquema que se despareja sola.
Ahora vive en `lib/orden_de_borrado.rb` y se calcula preguntándole a PostgreSQL.

⚠️ **Y la transacción hizo su trabajo:** el intento fallido dejó la base
exactamente como estaba. Es la razón de no usar `TRUNCATE`.

### ⚠️ Lo que esto NO resuelve

Producción sigue con **cuentas de administrador con contraseña conocida y
públicamente documentada**. El día que entre un colegio de verdad esto es
urgente otra vez — pero ya no por alumnos inventados, sino por las cuentas.
`MOR-146` sigue abierto por esa mitad.

---

## Sesión del 10 al 11 de septiembre — Educación Inicial, la foto y la ficha del alumno

`bin/ci` verde: **1.437 tests**, 6.562 aserciones + 91 de sistema. **Tres
commits en LOCAL, sin desplegar** — falta que Daniel lo pida.

```
   03:49   Educación Inicial no califica, describe          3f71206
   04:35   la foto de perfil se sube, y el docente tiene RIF 2166284
   05:20   el profesor abre la ficha de su alumno           190b5af
```

### Educación Inicial

Daniel: *«los niños en Inicial no sacan ni A, ni B, ni C, ni PC, ni AP, ni 5,
ni 20, entonces la calificación es descriptiva»*. Y el resultado del año es
«aprobó», directo —«prácticamente con asistir al colegio»—; si hay una
condición particular, la maestra la sugiere en ese mismo texto.

```
   PRIMARIA / MEDIA          INICIAL
   ────────────────          ───────
   Planificar · Calificar    Calificar
   evaluaciones con peso     — no hay nada que ponderar
   un número del 1 al 20     un párrafo por área
```

Las tres capas decían que no se podía: `final_moment_score` era `NOT NULL`,
el modelo exigía número, y «Planificar» pedía una ponderación inexistente.
Ahora la columna admite `NULL`, nace `descripcion`, y un `CHECK` exige una
cosa **o** la otra — nunca las dos ni ninguna.

⚠️ `Grade#califica_con_texto?` es una pregunta PROPIA y no un
`unless primaria?`: `por_competencias?` YA es `primaria?`, así que Inicial y
Media caen juntas en el mismo `false` y todo lo que diga «no es primaria»
asume bachillerato.

SPEC congelado en [`docs/specs/educacion-inicial.md`](docs/specs/educacion-inicial.md).

### La foto de perfil y el RIF

`has_one_attached :foto` existía desde MOR-149 y `AvataresHelper` la dibujaba:
faltaba el CAMPO, así que la única forma de tener foto era la consola. Va en
`shared/_datos_de_la_persona`, o sea en los cuatro formularios de una vez, y
la ficha del alumno y la del profesor ahora la muestran junto al nombre.

El RIF es columna propia en `users` —no un `document_type` más: un profesor
tiene los DOS— y solo se le pide al docente, que es quien cobra. Se guarda sin
guiones y se muestra con ellos.

⚠️ `User::CAMPOS_DEL_FORMULARIO` / `CAMPOS_ANIDADOS` reemplazan tres `permit`
idénticos. `:id` va SOLO en la anidada: donde el formulario escribe el usuario
directo —el representante— permitirlo deja cambiar la clave primaria.

### La ficha del alumno, para el profesor

`/secciones/:id/alumnos/:enrollment_id`. La pestaña «Alumnos» era una tabla
muerta y el teléfono de la mamá vivía solo en la ficha de la dirección.

⚠️ NO es `students/show` —esa trae boletín, documentos oficiales y edición de
la familia— y cuelga de la sección para que el permiso quede resuelto por
construcción.

### Lo que sigue pendiente

```
   ▸ desplegar los tres commits           ← lo primero, cuando Daniel diga
   ▸ el boletín de Inicial en PDF          fuera del alcance del SPEC
   ▸ el portal del representante dice
     «Calificaciones» para un niño de
     Inicial, donde no hay notas
   ▸ promover deja a Inicial en «SIN DATOS»
   ▸ MOR-230 foto del alumno + almanaque · MOR-231 fila acordeón
   ▸ deuda de CSS: 11 clases sin regla (lista congelada), 108 selectores
     duplicados
```

⚠️ **Para probar los tres niveles hacen falta DOS ingresos**, no uno: ningún
docente de los seeds dicta en Inicial y en primaria a la vez —y en un colegio
real tampoco—. `prof.garcia@bolivar.edu` cubre primaria, bachillerato y media
técnica; `maestra.colmenares@bolivar.edu` es la guía de 1er Nivel – U, con
16 niños. Las dos con `123123`.

---

## Sesión del 8 de septiembre, tarde — la vista del profesor (etapa ③)

`bin/ci` verde: **1.348 tests**, 6.258 aserciones. **Todo en LOCAL, sin subir.**

```
   12:10   el sidebar es un árbol: área → nivel → grado → sección
   12:39   las cuatro pestañas de la sección
   13:47   las pestañas dejan de sacarte de la sección
   14:29   los tres estados de columna
```

### El sidebar

```
   ▾ SOY GUÍA DE            ▾ DICTO
       4to Grado – A  ✓         ▾ Castellano y Literatura
                                    5to Grado – A
                                  ▾ 6to Grado
                                      6to Grado – A
                                      6to Grado – B
```

**La regla que lo hace usable:** un escalón aparece solo si DIVIDE algo — la
misma de las pastillas y del selector de nivel. Verificada contra los cuatro
perfiles reales de los seeds, que son cuatro formas distintas del árbol.

⚠️ La MISMA sección sale en las dos ramas, y no es un bug: son dos trabajos.
Como guía entro a la sección (sin área, la asistencia es de todos); como
docente del área, a una asignación.

### Las cuatro pestañas, DENTRO de la sección

```
   Asistencia* · Calificar · Planificar · Alumnos      (*solo el guía)
```

Daniel rechazó que fueran URLs de otras pantallas: *«se descontextualiza todo,
se supone que estoy en mi espacio de trabajo… no es solo "fingir" sino
realmente estar en la sección»*. Las cuatro son acciones de
`SectionsController`, y la planilla de asistencia y el plan son los MISMOS
parciales que usan `/asistencia` y `/competencias` — vía `PreparaLaAsistencia`
y `MuestraElPlan`, para que no se separen.

⚠️ Y la ACTIVA por defecto sale de por dónde entró: por «Soy guía de» abre
Asistencia; por «Dicto» abre Calificar. El árbol ya lo dice, no hay que
preguntarlo.

### Los cuatro momentos de una columna

```
   ALUMNO  │ Diagnóstica │ Taller       │ Examen    │ Proyecto
           │ 19 de ago   │ 4 sep ya pasó│ 8 sep hoy │ 26 sep en 18 días
           │ 2 de 2      │ 1 de 2       │ 0 de 2    │ 0 de 2
           └ plana       └ ÁMBAR        └ azul      └ atenuada
             (cerrada)     lo de HOY      en curso    y ESCRIBIBLE
```

⚠️ **La fecha ordena, no cierra.** Daniel lo había planteado como «se activa
conforme a la fecha y se desactivan las otras»; eso deja fuera al profesor que
carga tarde, que es el caso normal. Estuvo de acuerdo.

### Lo transversal que se hizo en el camino

- **La franja del título**: la misma marca del ítem activo del sidebar —barra
  + fondo sutil— sangrando hasta el borde de la tarjeta, con los controles
  DENTRO. Tres vueltas de QA hasta acertar. `--compacta` se retiró.
- **«Mi trabajo» salió del menú del profesor**: sus tres entradas son pestañas
  de la sección.
- **El login de los tests de sistema era flaky** y fallaba una de cada cinco
  corridas. Ahora reintenta. Un login flaky hace fallar cualquier test con un
  mensaje que no menciona el login.

### ⚠️ Lo que sigue abierto de la vista del profesor

- **`MOR-230`** · la foto del alumno, actualizada cada año escolar. Lleva una
  decisión de MODELO adentro: ¿la foto es del usuario, de la inscripción, o
  las dos? Un boletín de 1er Grado no puede salir con la cara del muchacho de
  5to Año.
- **`MOR-231`** · la fila del alumno como acordeón, con la ficha adentro.
- Replicar la planificación a las secciones hermanas (existe para
  competencias, falta para evaluaciones).
- Las estadísticas del lapso — Daniel las dejó de último, «es un plus».

---

## Sesión del 8 de septiembre — el sistema de diseño deja de ser opcional

`bin/ci` verde: **1.340 tests**, 6.234 aserciones. **Todo en LOCAL, sin subir.**

```
   11:05   ① tonos + catálogo vivo en /siga/estilo
   11:33   ② una sola cabecera para las 128 pantallas
   11:36   ③ spec de la vista del profesor, en BORRADOR
```

⚠️ **Nada se desplegó ni se empujó a origin.** Regla que Daniel tuvo que
repetir: *«trabajemos en local y cuando te diga, desplegamos a prod y origin»*.
Está en memoria.

### De dónde salió

> *«Ayer hice una captura de por lo menos cinco tipos de títulos principales.
> Eso es inconcebible… un framework vale, nuestro propio framework, con las
> bondades de Bootstrap pero no tan extenso»*

Contó cinco. Había **siete** — y el diagnóstico no era que faltara el framework
(709 clases en 9.548 líneas) sino que **era opcional**: la cabecera correcta
existía desde `MOR-192` y la usaban **14 pantallas de 84**.

### ① El verde significa «esto queda guardado»

Decisión de Daniel: el alta va en verde, igual que el submit. Así
`[Guardar cambios]` en una edición deja de ser una excepción incómoda.

```
   guardar     verde       queda guardado    [+ Agregar] [Crear] [Guardar]
   accion      índigo      mucho de una vez  [Copiar de otro año]
   documento   petróleo    algo sale         [Descargar] [Emitir]
   ver         azul suave  mirar sin tocar   [Ver]
   secondary   neutro      volver atrás      [Volver] [Cancelar]
   danger      sin tono    destruye          [Eliminar]
```

⚠️ **`btn-primary` se retiró.** Se quedó sin trabajo, y «primario» nunca fue un
trabajo. `boton` **exige `tono:`**: ese default era el agujero.

**El catálogo vive en `/siga/estilo`**, tras la puerta del equipo de SIGA
(`desarrollador@siga.edu` / `123123`), y se dibuja con los helpers de verdad.

### ② Una sola cabecera

```
   43×  card-academic-header > %h2   ← título de TARJETA
   32×  card-academic-header > %h1   ← título de PANTALLA
   35×  … + acciones
```

La misma clase para dos cosas distintas, separadas solo por qué etiqueta
escribió cada quien. Ahora es `nivel:`, que se pide.

⚠️ **El partial NO emite la tarjeta** — eso es lo que lo hace componible.

### Cinco cosas que aparecieron, y ninguna estaba en el plan

1. **«Emitir el documento» estaba en el tono equivocado** (azul, siendo un
   papel). Llevaba así desde que existe.
2. **Un botón de dos palabras se desbordaba**: `line-height: 1` + alto fijo.
   Se vio recién con los seis tonos apilados en el catálogo.
3. **Un `%h2` VACÍO** en el panel del administrador: el icono y «Todo al día»
   le quedaban de hermanos, no adentro.
4. **`.dato-secundario` ya existía** y la redefiní — la colisión de
   `.contexto-fijo`, otra vez.
5. ⚠️ **La hoja tiene 108 selectores duplicados.** 98 con el mismo cuerpo, y 9
   de los 10 restantes son refinamientos deliberados en cascada. **No se tocó:
   es un PR propio.**

### Y dos guardas avisaron, que es de lo que se trata

`nombres_de_las_acciones_test` leía el título con `/%h1 (.+)/` y se quedó ciego
al migrar. No pasó en silencio porque **ese test comprueba primero que esté
comprobando algo**. Es la advertencia de la plantilla de specs, cumpliéndose.

### ⚠️ Lo que espera a Daniel

El spec de la **vista del profesor** está en borrador con **cuatro preguntas
abiertas** que son suyas: cómo se llaman las dos ramas del sidebar, qué ve un
profesor sin sección guía, el orden de las pestañas, y si puede mirar años
anteriores. Sin esas cuatro no se congela.

---

## Sesión del 7 de septiembre — el QA de competencias y el enganche

`bin/ci` verde: **1.316 tests**, 6.121 aserciones. **Todo desplegado** (`d935597`).

```
   08:30   PR #14 · las cinco correcciones del QA de la pantalla
   09:52   PR #15 · MOR-229 · conectar evaluaciones con competencias
   09:55   desplegado a producción · /up 200 · /salud 200
```

### Lo que faltaba, y lo dijo Daniel en una línea

> *«no sé cómo asociamos las evaluaciones con los indicadores. RECUERDA UX,
> debe ser un proceso fácil y fluido»*

El enganche **existía desde `MOR-136`** —al crear una evaluación se marca qué
competencia mide— pero solo en esa dirección. Y el orden real del trabajo es el
contrario:

```
   COMO ESTABA                        COMO TRABAJA UN DOCENTE

   1. crear la evaluación             1. escribir el plan del lapso
   2. acordarse de marcar             2. armar las evaluaciones
      ← acá o nunca                   3. «¿cuáles me faltaron?»  ← sin respuesta
```

Y no es cosmético: **una competencia que ninguna evaluación mide sale en la
boleta sin nivel**, y eso se descubría cuando la familia preguntaba.

### Lo que se ve ahora

```
   ┌──────────────────────────────────────────────────────────────┐
   │  1. Resuelve problemas de adición y sustracción   [✎] [🗑]   │
   │  ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ │
   │  LA MIDEN  (Prueba corta 30 %) (Examen 40 %)    ✎ Cambiar   │
   ├──────────────────────────────────────────────────────────────┤
   │  2. Reconoce figuras geométricas del entorno     [✎] [🗑]   │
   │  ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ │
   │  LA MIDEN  Ninguna evaluación todavía          + Conectar   │
   └──────────────────────────────────────────────────────────────┘
                └── ÁMBAR: esa sale en la boleta SIN nivel
```

**Y la vuelta, en la libreta** —la pantalla que el profesor más mira, y la
única donde el plan no existía—:

```
   ALUMNO      │ Examen del lapso │ Prueba corta │ LAPSO 1
               │ 40 %             │ 30 %         │
               │ 28 de 30         │ 30 de 30     │
               │ 📄 Mide 2        │ 📄 Mide 1    │  ← tooltip: cuáles
```

⚠️ «Mide 2» y **no un «2» pelado**: justo encima hay otro número —«28 de 30»,
lo que lleva cargado— y dos cifras apiladas sin etiqueta se leen como lo mismo.

### Tres trampas que costaron

1. **`params[:competency_id]` vs `params[:id]`.** `conectar` cuelga de una ruta
   ANIDADA, así que `find(params[:id])` era `find(nil)`: **404 en una acción
   que existía y estaba bien escrita**.
2. **El tooltip tapaba el panel que acababa de abrir.** El puntero sigue sobre
   el `summary` después del clic, y el globo se dibuja encima del título del
   panel. Se calla con `[open]` — una vez abierto ya no explica nada.
3. **Un `<details>` cerrado NO esconde un hijo con `position: absolute`.**
   Tercera aparición de esta trampa en el proyecto (panel de contexto, menú, y
   ahora éste). Va con su `display: none` explícito y su test de SISTEMA, que
   es donde se ve: en un test de integración el marcado sale perfecto.

### Y los seeds dejan un hueco a propósito

La última competencia de 1er Grado queda **sin conectar**. «Ninguna evaluación
todavía» es un estado que hay que poder ver —esa competencia sale en la boleta
sin nivel— y con el plan entero conectado no aparece nunca. Es la misma razón
por la que hay secciones sin notas y representantes sin correo.

---

## Sesión del 5 de septiembre — las cinco tandas del QA

`bin/ci` verde: **1288 tests**, 5.930 aserciones.
**Todo desplegado** a producción (`6d60e05`).

```
   10:51   desplegadas las cinco PR de la noche anterior
   12:35   TANDA 1 · nomenclatura del MPPE
   12:40   TANDA 2 · la barra resaltada, y el select duplicado
   12:53   TANDA 3 · paneles con pestañas
   13:19   TANDA 4 · dos selects en el formulario
   13:39   TANDA 5 · la libreta y el avance de calificación
   13:43   desplegado
```

### El vocabulario, en un solo lugar

```
   EN LA BASE            EN PANTALLA               CORTO
   preescolar            Educación Inicial         Inicial
   primaria              Educación Primaria        Primaria
   secundaria            Educación Media           Media
   media_tecnica         Educación Técnica Media   Técnica Media
   Subject / subjects    Áreas de aprendizaje      Áreas
```

Nace `app/services/vocabulario.rb`. **El enum, el modelo y la URL no cambian**:
son enteros y nombres de tabla escritos en la base de todos los colegios, y
`/materias` se lee mejor que `/areas-de-aprendizaje`.

### La libreta (lo más grande de la tanda)

`app/services/libreta_de_la_seccion.rb` — todas las notas de un lapso en una
tabla: alumno × evaluación, con el promedio a la derecha. Es la planilla girada
noventa grados: ésa es para CARGAR, ésta para MIRAR.

⚠️ Es del **área que dicta**, no de la sección entera. Daniel lo ratificó con
Cyndi: *«guía + áreas asignadas»*. La dirección las ve todas: supervisa.

### El avance de calificación, en tres estados

```
   6to Grado – A     [Castellano 1 de 4]  [Matemática ✓ 4 de 4]
   6to Grado – B     [Matemática 0 de 3]
```

Cada uno enlaza a la **primera evaluación incompleta**, no al listado. En el
menú lateral, cada sección lleva su punto de color — con el nombre en el
tooltip, nunca solo color.

### Tres bugs reales que destaparon los tests

1. **El Escape no siempre cerraba el panel de contexto.** Los listeners
   colgaban del evento `toggle`, que es ASÍNCRONO: entre abrir el panel y tener
   el oyente puesto hay una ventana. Un humano no presiona Escape en 20 ms,
   pero eso no lo vuelve un problema del test.
2. **El test del teléfono dejaba la ventana en 390 px** para el siguiente. Con
   el orden aleatorio de minitest, hace fallar un test cualquiera en un punto
   cualquiera, con un mensaje que no menciona el teléfono. Ahora el tamaño se
   repone en el `setup` de `ApplicationSystemTestCase`.
3. **32 renglones donde había 16.** El desplegable de «Registrar evaluación» no
   filtraba por año escolar. No era solo feo: el segundo renglón creaba la
   evaluación en el año que viene, sin que nada lo dijera.

### Y un patrón que ya cuesta caro

`assert_select ".x", "texto"` toma el segundo argumento como **texto esperado**,
no como mensaje de fallo. Cuatro veces en una sesión. Está anotado en
`test/test_helper.rb`, donde se lee.

---

## Sesión del 4 al 5 de septiembre — MOR-136 completo, la resiembra y la barra

`bin/ci` en verde: **1259 tests**, 5.841 aserciones, ~2 min 30 s.
Todo en `main`. **NO desplegado** — ver «Pendientes que necesitan a Daniel».

```
   MERGEADO ESTA SESIÓN
   ────────────────────
   PR  #7   MOR-136  el plan: competencias e indicadores
   PR  #8   MOR-224  la resiembra de la demo
   PR  #9   MOR-136  la rúbrica, el etiquetado y la boleta
   PR #10   MOR-216  el informe descriptivo del docente
   PR #11   MOR-223  la barra de contexto en un solo control
```

### MOR-136 · Evaluar primaria por competencias, de punta a punta

Cuatro tandas, en el orden en que se usan:

```
   1 · EL PLAN        Competencias e indicadores · pastillas grado→área→lapso
                      se sugiere el del año pasado · se copia a las hermanas
   2 · LA RÚBRICA     Configuración › Rúbrica de evaluación
                      los cinco niveles juntos · el colegio de TRES también
   3 · EL ETIQUETADO  «Qué evalúa» en el formulario de la evaluación
   4 · LA BOLETA      «PA (17)» + el plan con su nivel + la leyenda
```

**La decisión que lo hizo barato**, de Daniel: *«las competencias terminan siendo
solo para mostrarlas en la boleta»*. Con eso, `GradeCalculator`,
`activity_grades`, `moment_grades` y `final_grade_books` **no se tocaron**.

Spec cerrado en `docs/specs/mor-136-evaluacion-de-primaria.md`, con las cinco
trampas que se pisaron.

### MOR-224 · La demo, resembrada

```
   ANTES                          AHORA
   ─────                          ─────
   Bolívar  solo bachillerato     los TRES niveles + Media Técnica
            5 grados · 11 materias        15 grados · 26 áreas
            200 alumnos                   360 alumnos · 19 secciones
```

**El pensum es el del MPPE y por GRADO**: «Formación para la Soberanía
Nacional», «Grupo de Creación, Recreación y Producción», las dos etapas de
primaria con pensum distinto, y Física y Química que no existen en 1er Año.

Sembrados los casos que antes había que fabricar a mano: 3 retirados · una
sección sin guía · 11 secciones sin notas · 98 representantes sin correo ·
2024-2025 importado (4.002 definitivas) · 2026-2027 copiado y vacío · 29
informes descriptivos, con un tercio de alumnos SIN informe a propósito.

⚠️ **Los cuatro correos de los brokers y `123123` intactos.**

### MOR-216 · El informe descriptivo

Uno por alumno y lapso, escrito por el **guía de la sección** (o la dirección,
porque el guía es opcional). Sale al final de la boleta, en el PDF y en el
portal de la familia.

⚠️ **Dos decisiones las tomé con Daniel durmiendo** y están marcadas en
`docs/specs/mor-216-informe-descriptivo.md` para que las confirme: que sea uno
por LAPSO (no por materia) y que lo escriba el GUÍA. Las dos aguantan el cambio
barato.

### MOR-223 · La barra, de diez elementos a cinco

```
   ANTES  ▣ SIGA · 🛡 colegio · AÑO ESCOLAR [▾] · 📅 · en curso ·
          NIVEL [▾] · ⓘ acá no aplica · 🔍 · Daniel · Cerrar sesión

   AHORA  ▣ SIGA · 🛡 colegio · ( 2025-2026 · Primaria ▾ ) · 🔍 · Daniel · Salir
```

Es un `<details>` **nativo**: abre, cierra y envía sin JavaScript.

### Lo que se rompió, y lo que dejó puesto

**Un `import` roto mata la aplicación Stimulus ENTERA.** Un heredoc que no llegó
a escribirse dejó `carga_informes_controller.js` sin crear mientras `index.js`
ya lo importaba, y fallaron **ocho tests de sistema en pantallas ajenas** —el
filtro de la barra, el borrado en línea, el campo con error—. Nada apuntaba al
archivo que faltaba.

→ **`test/integration/controladores_de_stimulus_test.rb`**, que comprueba las
tres cosas que se desparejan solas: que cada import tenga su archivo, que cada
archivo esté registrado, y que el nombre del registro coincida con la clase.

**Y tres trampas de CSS que ya son un patrón:**

1. Un `<details>` cerrado **no oculta** a un hijo con `position: absolute` —
   tercera aparición, después de `.sidebar-nav` y `.nav-institutional`.
2. Un `@media` **5.700 líneas antes** de su regla base no aplica: a igual
   especificidad gana la última. Primo del accidente de `.nota-ayuda`.
3. El reparto de la barra estaba invertido, y **se pudo medir**: a 390 px el
   nombre del colegio se quedaba con 165 px y la pastilla de contexto con 13.

**Lección de proceso:** no encadenar `grep` con `&&` antes de escribir un
archivo. Un `grep` sin resultados devuelve 1 y corta la cadena — pasó dos veces
esta noche, y las dos veces el archivo no se escribió sin que nada avisara.

---

## Sesión del 1 de septiembre — QA de Daniel y la clonación

`bin/ci` en verde, **992 tests**. Todo desplegado.

### Del QA de Daniel

**«Nuevo Momento» debía decir «Nuevo Lapso»** — se me escapó en el renombre. Y al
mirar esa pantalla había dos cosas más: estaba **vacía y sin salida** (los años
escolares creados antes de MOR-163 no tienen lapsos sembrados) y el enlace de
cada fila iba en el AÑO, no en el lapso. Ahora el estado vacío ofrece **crear los
tres de un clic**.

**El día 1 de un colegio nuevo tenía tres callejones.** El más grave: el
departamento era obligatorio para crear una materia, pero el plan de arranque lo
presenta como opcional desde MOR-154 («un colegio de 150 alumnos no tiene
departamentos»). Un colegio recién registrado se trababa en el paso 3 de 8.
Ahora es opcional de verdad y en el plan va antes de las materias. Los otros
dos: `/secciones/new` e `/inscripciones/new` mostraban desplegables vacíos sin
explicación — lo tapa `shared/_precondicion`, con el mismo texto de
`PasosDeArranque`.

`test/integration/colegio_vacio_test.rb` guarda el día 1 completo: **ningún
formulario de alta puede quedarse sin formulario Y sin explicación.** Que
responda 200 no alcanza — un callejón responde 200.

### Los portales sin selector, que se rompían con dos años

Encontrado al revisar qué quedó fuera de MOR-165, y **la clonación lo habría
disparado**: el panel del alumno ordenaba por `grades.name`, así que un muchacho
de 5to Año veía las notas de 1er Año de hace tres. Es la pantalla que ve una
familia. Hoy no se notaba porque cada colegio tiene un año escolar.
Arreglados los tres —alumno, profesor, representante— más las fichas de profesor
y de materia. `Enrollment.recientes_primero` ordena por el año, no por la fecha
del trámite.

### La reparación y la promoción (`MOR-168`, `MOR-169`)

**El Art. 112 se podía leer pero no escribir.** Daniel: *«por ningún lado vi
dónde el profesor coloca la reparación»*. No la vio porque no existía:
`remedial_exam_score` se leía en el boletín, la certificación y el cálculo, y
solo se escribía desde el importador de historial. Ahora está `/reparaciones`,
que reusa entero el `carga-notas` y muestra la definitiva en vivo.

**Y la promoción**, que es la otra mitad de septiembre. Verificado sobre los
seeds: 200 alumnos evaluados en 55 ms, 1er Año A → 2do Año A.

⚠️ **Lo que hay que recordar de estas dos:**

- `debe_reparar?` (promedio ANUAL) **no** es `aplazado?` (la definitiva).
  Confundirlos hacía desaparecer al alumno de la planilla apenas se le cargaba
  una reparación aprobatoria: un tipeo quedaba imposible de corregir.
- La regla del 112 vive en `FinalGradeBook`, no en `GradeCalculator`: un libro
  **importado** no pasa por el calculador, y es el caso normal de un colegio que
  trae su historial y después repara.
- **SIN DATOS es lo normal en un cliente nuevo**, no un error. Las notas del año
  anterior están en el sistema viejo.
- En Haml, un comentario **entre** `if` y `elsif` —o entre dos `when`— rompe el
  bloque. Va adentro de la rama. Costó dos veces la misma noche.

**Abierto:** dónde se registra la nota de una materia pendiente cuando el alumno
finalmente la aprueba. La Circular 0007 dice que se inscribe *«en el grado
anterior con la asignatura pendiente»*, o sea que la nota va al año en que la
aplazó — pero Daniel lo está investigando por su lado antes de cerrarlo.

### Barrido sistemático de la noche

Un test que recorre **todas** las pantallas de los cuatro roles, más el panel de
SIGA y las páginas públicas, y exige que cada una traiga contenido, un
formulario que llenar, o una explicación del vacío. Encontró tres callejones más
—representantes, grados e inscripciones dejaban una tabla de encabezados y nada
debajo— y **el carnet**: cargar 360 alumnos de un Excel funcionaba y agregar UNO
a mano devolvía «Carnet no puede estar en blanco», pidiendo un número que el
importador ya sabía inventar. Vive ahora en `Student`, de donde lo piden los tres.

⚠️ **Dos aprendizajes al escribir ese test**, que valen para el próximo:

1. La primera versión **no podía fallar**: contaba el `input name="q"` del
   buscador de cada listado, que está en todas las pantallas de lista.
2. La segunda listaba nombres de clase y se rompía con cada pantalla que usa los
   suyos. Ahora mide **texto** dentro del `main`, que no hay que actualizar.

⚠️ **Y un error mío que costó trabajo:** escribí `formularios_test.rb` y
`puesta_en_marcha_test.rb` con `cat >` sin mirar si existían. Existían, con 31 y
16 tests. Se recuperaron de git —estaban commiteados— y mis tests nuevos quedaron
con nombres propios: `validacion_de_formularios_test.rb` (cómo se PORTA un
formulario al guardar vacío) y `arranque_de_punta_a_punta_test.rb` (el camino
completo creando datos). **Mirar el destino antes de escribir.**

### Monitoreo: `/salud` (`MOR-167`)

El pendiente decía «nada avisa si el worker se cae», y el modo de fallo es el
peor que hay: **la app sigue respondiendo 200 en todas sus pantallas**. Nada se
rompe; los promedios se quedan viejos y el colegio lo descubre en el boletín.

`GET /salud` responde JSON sin sesión, con el largo de la cola, cuántos workers
laten y **cuánto lleva esperando el trabajo más viejo**. Devuelve **503** cuando
eso pasa de 5 minutos.

Verificado a mano en desarrollo: con el worker apagado, 503 con siete trabajos y
el más viejo de cuatro días; levantando `bin/jobs`, 200 con la cola en cero.

⚠️ **Falta enganchar un monitor externo.** Hoy el aviso existe y no lo mira
nadie. Es lo primero de la lista.

⚠️ `/salud` NO reemplaza a `/up`: `/up` lo mira Dokku para dejar entrar una
versión nueva. Si mirara `/salud`, un worker caído impediría desplegar la
corrección que lo arregla.

### El importador era la quinta manera de decidir el año

Resolvía con `AcademicPeriod.vigente` en cada lectura, así que con «2024-2025»
elegido arriba una planilla de 360 alumnos se iba a 2026-2027 en silencio. Ahora
el año se **estampa al subir**, desde la sesión. Con eso **no queda ninguna
manera suelta** de decidir el año escolar en la app.

### Copiar la estructura del año (`MOR-166`)

Diez secciones y **ochenta y dos** asignaciones de profesor en 329 ms, en vez de
escribirlas a mano cada septiembre. Copia secciones (cupo, aula, guía) y quién
dicta qué; **no** copia alumnos, notas, asistencia ni boletines — y lo dice antes
de confirmar. Idempotente, respeta lo que el colegio ya armó a mano, y queda en
la auditoría con su propio token (`estructura_copiada`), no como «alguien editó
el año escolar».

⚠️ **La promoción de alumnos NO está hecha y es lo que sigue** — ver abajo.


## Sesión del 31 de agosto — el año escolar de la sesión (`MOR-165`)

`bin/ci` en verde, **909 tests**. Salió del QA de Daniel: *«vamos a implementar la
figura de año escolar de la sesión, arriba, donde está la sesión. Ese lo vamos a tomar
como pivote para filtrar todo lo que sea filtrable»*.

**Lo que había antes eran CUATRO maneras de decidir el año**, cada una escrita a mano
en su pantalla: `AcademicPeriod.vigente`, `.en_operacion`, el helper `periodo_vigente`
(que ya no lo llamaba nadie) y el prefijo del importador. Se contradecían en agosto.

**Ahora hay un selector en la barra de arriba** y todo cuelga de él:

```
   U.E. Simón Bolívar   ·   Año escolar [2025-2026 ▾]   finalizado el 31 de julio
```

- `Current.academic_period` + el concern de controller `LlevaElAnioEscolar`
- El concern de modelo `DelAnioEscolar` con `llega_al_anio_por` — declara CÓMO cada
  tabla llega al año (columna propia, un join, o dos) y pone el scope
  `del_anio_de_la_sesion`. Diez modelos.
- **NO es un `default_scope`**, y ahí está la diferencia con `SchoolScoped`: el colegio
  es un límite de seguridad, el año es una preferencia de quien mira. Un default_scope
  por año rompería el histórico de un alumno y la constancia de un egresado.
- **El profesor NO tiene selector.** Daniel: *«los docentes no deberían necesitar ni
  siquiera ver algo anterior, solo lo que están calificando»*.
- **«Todos los años»** es una opción explícita — la secretaria que busca la constancia
  de un egresado la necesita.
- El selector de año que tenía la pantalla de secciones **se borró**: eran dos controles
  para lo mismo, en la misma vista, contradiciéndose.

**El lapso dejó de preguntar lo que se puede deducir.** «Nuevo momento de evaluación»
se llama **Nuevo lapso** —Daniel: *«¿nos estamos refiriendo al lapso? Si es así, nada de
eso habría que preguntarlo»*—, el año sale de la sesión y el nombre se propone
(«1er Lapso», «2do Lapso»…). Igual la sección: al crear toma el año de la sesión, y al
editar **el año ni se muestra** — mover una sección de año arrastraría sus notas.

### ⚠️ Tres cosas que se rompieron acá y no hay que volver a romper

1. **`include LlevaElAnioEscolar` va DESPUÉS del `around_action`.** Estuvo arriba de
   todo y falló exactamente como ya había fallado `RespetaLaSuscripcion`: sin
   `Current.school`, el RLS devuelve cero años, el `return` temprano se dispara y
   `Current.academic_period` queda en nil. **En silencio**: los listados no filtraban y
   crear un lapso decía «Período académico debe existir» sin explicar nada.
2. **El año por defecto es el que TIENE ALUMNOS (`en_operacion`), no la fila más
   nueva.** En agosto son distintos: la fila más nueva es el año que empieza en
   septiembre y no tiene ni una sección. Arrancar ahí es abrir el panel de un colegio
   lleno y leer «0 alumnos». Es la tercera vez que aparece esta trampa —
   `Subscription.matricula_de` y `periodo_en_curso` fueron las otras dos— y ahora vive
   en un solo lugar: `anio_por_defecto`.
3. **Una expresión partida en varias líneas dentro de un `select_tag` revienta Haml**
   («indented 16 levels deeper than the previous line»). Las opciones se arman arriba,
   en variables.

## Sesión del 27 de agosto — lo que quedó desplegado

Todo en `main`, en producción, con `bin/ci` en verde (865 tests). Ocho commits.

**Rediseño de la sesión del colegio (`MOR-149`), tandas 1 y 2 — aprobadas por Daniel.**
El menú dejó de ser cuatro plantillas con el mismo bloque copiado 40 veces: ahora se
DECLARA como datos en `MenuHelper` y «estás acá» se deduce de la ruta. Agrupado por
*qué es la cosa* —Panel · Usuarios · Académico · Día a día · Reportes · Configuración—,
plegable con memoria en cookie. En el teléfono es un **navbar**: cinco chips y cajas
desplegables, sin scroll horizontal. Buscador global de ⌘K arreglado (era un
`<turbo-frame>` que se comía el Enter).

**El profesor guía es de la SECCIÓN (`MOR-209`).** No era un nombre mal puesto: la
asistencia se filtraba por el grado, así que el guía de «1er Año» pasaba lista de A, B
y C —alumnos que no son suyos— y los guías de B y C no veían su sección.
`grades.leader_teacher_id` → `coordinator_teacher_id`.

**Rótulos desde `es.yml` (`MOR-210`).** 55 etiquetas y 47 encabezados centralizados.
Destapó que `User` no estaba traducido: los errores decían **«First name no puede estar
en blanco»**. Y el término del colegio es **ALUMNO**, no estudiante.

**Los grados los fija la ley (`MOR-153`).** `GradoOficial` con los 14 grados de
Venezuela. **El nivel se DEDUCE del nombre** —«4to Grado» es primaria, «4to Año» es
secundaria—. Preescolar faltaba entero. `School#niveles` se deriva de los grados: cero
columnas nuevas.

**Las materias son del período (`MOR-211`).** Sin agregar columna: se derivan de quién
dicta qué en esa sección. ⚠️ Es una UNIÓN con las materias que tienen nota, porque el
importador de historial no crea `teacher_sections` y si no, diez años de boletines
salen en blanco.

**El panel es el mapa de la puesta en marcha (`MOR-154`).** No es un wizard: cada paso
enlaza a la pantalla que ya existe. **El progreso no se guarda, se deduce.** `/niveles`
son tres casillas en vez de catorce formularios. Franja de recorrido, estados vacíos
con su precondición.

**Quién no cargó notas (`MOR-155`)** — el único pendiente del panel con fecha de
vencimiento. El cálculo se compartió con el panel del profesor.

**El plan Inicial es gratis (`MOR-156`).** Límite **por función**, no por registros ni
por tiempo: cargar es libre, calificar / pasar lista / emitir se activan con el plan.

### `MOR-146` — producción limpia y resembrada (28 ago, madrugada)

Producción **ya no corre con los datos congelados**. Estado final verificado:

```
   2 colegios de demostración   ·  314 personas  ·  0 sin identificador
   respaldo verificado ANTES    ·  /Volumes/…/SIGA/respaldos/
   contraseña de la demo        ·  nueva, aleatoria, se la pasé a Daniel
```

Lo que se arregló: las 297 personas sin cédula ni cédula escolar estaban
**congeladas** —ningún `save` pasaba, ni el de cambiar la contraseña— porque la
validación de `MOR-138` se agregó sobre filas que ya existían. Se resembró, que
además regenera todo con los campos del MPPE. Y `dev.demo@siga.local`, que era
`fundador` desde el primer sembrado, ya no existe.

⚠️ **Sigue abierto:** `desarrollador@siga.edu` es `fundador`, o sea que ve todos
los colegios. Hoy no importa —los dos son inventados— y el día que entre un
colegio pagando es `MOR-92` con nombre y apellido.

⚠️ **Y una lección que costó un intento fallido contra producción.** La tarea de
borrado imprimió sus dieciocho líneas de «borradas N de tabla» y anunció «Base
vacía» **habiendo borrado nada**: `siga_staffs` también apunta a `users`, el
DELETE chocó contra esa FK, la transacción se deshizo, y los `puts` no son
transaccionales. Mi prueba local no lo atrapó porque corrí sobre una base recién
sembrada: **verifiqué el resultado, no el efecto.** Ahora `demo:limpiar`
comprueba tabla por tabla antes de anunciar nada.

### Sesión del 28–31 de agosto — el camino de entrada

**El panel de SIGA volvió a servir** (`MOR-157`). El botón «Dar de alta» estaba
escrito con un `if` modificador que se lleva el `do`: `link_to` tomaba la ruta
como TEXTO del enlace. No explota —200, HTML válido— así que ningún test de
códigos lo veía. Estaba en dos vistas.

**Los campos de dirección ya se pueden llenar.** `entidad_federal`, `municipio`,
`parroquia`, `direccion` y `telefono` existían en `schools` desde los documentos
del MPPE y ningún formulario los pedía. La entidad va como lista cerrada
(`EntidadFederal`, 25 entradas, La Guaira y no Vargas).

**Registro abierto y autogestionado** (`MOR-158`):

    /registrarse  →  /mi-colegio/nuevo  →  el panel, con su mapa de arranque

⚠️ **Revierte `MOR-101` a propósito.** El riesgo sigue existiendo —`users.email`
es único en la plataforma— y se acepta: facilidad por encima de seguridad
mientras el acceso sea compartir el enlace a mano. Lo que lo hace tolerable es
que **registrarse crea siempre un colegio nuevo**, nunca se une a uno existente.

Nace en el **Plan Inicial gratis**, y `schools.registrado_por_id` guarda quién lo
creó: la semilla de `Account`, que quedó **planteado y sin implementar**.

`PlataformaMailer` le avisa a Daniel. Configurado y **probado contra producción**
el 31 de agosto: `SIGA_AVISOS_EMAIL=moros.daniel@gmail.com`.

### Lo anotado por Daniel y todavía sin resolver

1. **`Account`** — varios colegios, un dueño, la suscripción colgando de la
   cuenta. Con un colegio, la interfaz de hoy; con varios, gestión en paralelo,
   *«y esto rompe el concepto de encapsulamiento al colegio»*.
2. **La figura del DEMO** — con el registro abierto, `DemoRequest` probablemente
   sobra. Ojo: se llevaría la pregunta «¿con qué llevan hoy las notas?»
   (`MOR-127`), que conviene mudar al alta del colegio.
3. **Cuándo avisar del costo** — pregunta abierta de Daniel. Con el plan gratis
   no hay nada que notificar hasta que el colegio elija; la pregunta llega sola
   al intentar calificar o emitir.
4. **Activar el acceso desde `/siga/solicitudes`** — hoy no hay por dónde.
5. **Correo de avisos a un dominio propio**, junto con `MOR-144` y `MOR-145`.

### Lo que sigue, en el orden que recomendó el PM

1. **Abrir el año escolar (clonar el anterior).** El PM recomienda **esperar a
   enero-febrero de 2027**, con dos o tres colegios adentro a quienes mirar: hoy se
   moldearía contra un agosto imaginado.
2. **Inscripción como etapa** (el representante ratifica, administración confirma).
   Depende de `MOR-145` —enterarse de un rebote— antes de mandarle correo a 360 familias.
3. **`MOR-146`: producción corre con datos de demo.** Sigue siendo lo más urgente.
4. Tanda 3 del rediseño: tarjetas de grado con KPIs y pestañas en el detalle.
5. La **Educación Media Técnica son SEIS años** y el catálogo cierra en cinco. Decidir
   antes de que un colegio técnico lo descubra.

**Análisis del flujo del director:** https://claude.ai/code/artifact/e17d038e-5882-4622-ac1b-0ae6bebd4a82

---

## Sesiones anteriores

> Sección volátil: es el estado de avance, no guía permanente. Actualizarla al cerrar cada sesión.

**Contexto de las sesiones previas.** Se hizo un análisis completo del proyecto (propuesta comercial,
modelo ER, código) corriendo la app con datos de dos colegios. Los hallazgos y decisiones están en
`## ⚠️ Estado conocido` más abajo, y el diagrama del modelo actual vs. objetivo en el artifact
enlazado al final.

> **El backlog vive en Linear**, en la initiative **SIGA**. `BACKLOG.md` quedó como puntero y tabla
> de equivalencias `E1-01 → MOR-82`, nada más — mantener dos copias a mano no era sostenible.

**Hecho:**
- Campo "¿qué usan hoy?" en el formulario de demo (`current_system` + `current_system_detail`).
  Pregunta por la forma de la solución —con internet / sin internet— y **no nombra competidores**,
  para no hacerles publicidad en el momento de máxima intención de compra.
- Censo de la cartera del incumbente por certificate transparency → `docs/investigacion/`.
- `CLAUDE.md` y `BACKLOG.md` escritos.
- **Commiteado** en la rama `feat/encuesta-demo-y-backlog` (4 commits, `main` intacto, sin push).
  `.claude/settings.local.json` y `.DS_Store` quedaron ignorados; `.mcp.json` sí se versiona.
- **`MOR-100` · Upgrade de Ruby y Rails — hecho.** Ruby 3.1.2 → **3.4.9**, Rails 7.0.10 → **8.1.3.1**,
  en la rama `chore/upgrade-ruby-rails` (7 commits, sin push). Se subió versión por versión
  (7.1 → 7.2 → 8.0 → 8.1), y valió la pena: **7.2 avisó que los enums con keyword arguments quedaban
  deprecados y 8.0 los elimina**. Saltando directo, la app se rompía sin aviso.
- **Linear reestructurado en initiatives.** Un ecosistema = una **initiative**; un cuerpo de trabajo
  con "terminado" propio = un **proyecto**; una fase adentro = un **milestone**. La ficha de negocio
  vive como **documento de la initiative**, no en un proyecto — sobrevive a cualquier proyecto que
  cierre. SIGA quedó en 5 proyectos y 41 issues.
- **Revisión de producto (10 ago).** Un agente PM revisó la estructura. Lo aplicado:
  importador de matrícula (`MOR-126`), conversaciones con directores (`MOR-127`), cobro de la
  suscripción (`MOR-128`); `MOR-91` fuera de Cimientos (silo puro primero); y la plantilla de issue
  cambió **"Especificación para el agente" por "Rabbit holes" y "No-gos"** — la spec numerada
  precomprometía decisiones y en `MOR-86` mandaba a un `before_action` que `MOR-87` obliga a rehacer.

- **Milestone `1 · Esquema por colegio` completo, más `MOR-89`.** En la rama
  `feat/mor-82-school-id-en-grades` (7 commits, sin push). Todas las tablas del dominio tienen
  `school_id` materializado, los índices únicos que debían ser por colegio lo son, y **ya no se
  puede escribir una fila que cruce dos colegios**. Ver `## ⚠️ Estado conocido` para el detalle
  de qué quedó global a propósito.
- **Tres concerns**, que es donde vive la mecánica del aislamiento:
  `DerivesSchoolFrom` (declara de qué padre sale `school_id` y lo mantiene al día),
  `ValidatesSameSchool` (impide vincular entidades de colegios distintos) y
  `SchoolScoped` (el `default_scope` por colegio).
- **`MOR-86` + `MOR-87` · La app es multi-tenant. Las dos capas están puestas y medidas.**
  Commits `cddab27` y `82a3259`, misma rama. `Current.school` sale **solo del rol del usuario
  autenticado**; el selector de colegio salió del formulario de grados y `school_id` dejó de estar
  en los parámetros permitidos. Debajo, RLS con `FORCE` en las 17 tablas del dominio.
  **El IDOR documentado (`GET /students/:id` de otro colegio) pasó de 200 a 404.**

  | | Solo capa 1 | Con RLS |
  |---|---|---|
  | `Student.count` con contexto Bolívar | 200 ✅ | 200 ✅ |
  | `Student.unscoped.count` | 290 ❌ | 200 ✅ |
  | `SELECT * FROM students` crudo | 290 ❌ | 200 ✅ |
  | **Sin contexto de colegio** | 290 ❌ | **0** ✅ |
  | `INSERT` cruzado | pasa ❌ | rechazado ✅ |

  ⚠️ **Requisito de setup que NO es opcional:** la app se conecta como `siga_app`, no como el
  usuario de macOS. Un superusuario **se salta el RLS por completo** y `FORCE` no lo alcanza —
  las políticas quedan decorativas. Pasó exactamente eso durante el desarrollo. Ver
  `## Common Commands` para el arranque en una máquina nueva.
- **`MOR-88` · El colegio viaja con el job.** Commit `8cf9dc9`. Concern `CarriesSchool`: el
  `school_id` se serializa en el payload al encolar —el único momento en que el contexto es un dato
  confiable— y se restablece, en la app y en la base, antes del `perform`. Por defecto un job
  **exige colegio** y levanta `CarriesSchool::SinColegio` si no lo trae; `colegio_opcional` y
  `de_toda_la_plataforma` son las dos salidas, explícitas y grepeables. `MailerDeliveryJob`
  reemplaza al de Rails, que no heredaba de `ApplicationJob` y por lo tanto no llevaba colegio.

  Lo encontró un test que parecía trivial: **`SET LOCAL` pertenece a la transacción más externa**,
  y `ActiveRecord::Base.transaction` anidado no abre una nueva. Un job corrido con `perform_now`
  dentro de una petición le dejaba su colegio puesto a la petición — capa 1 diciendo A, capa 2
  diciendo B, cero filas y ninguna explicación. Se guarda el valor anterior y se devuelve a mano.

  **Con esto cierra el milestone `2 · Aislamiento en la app y en la base`** (`MOR-86`, `87`, `88`,
  `89`). Y quedaron los **primeros 9 tests reales de aislamiento** del repo — la suite pasó de 3 a 13.

- **El módulo de evaluación está conectado de punta a punta** (`MOR-93` → `97`). Era "el núcleo del
  producto y está desconectado"; ahora el profesor define cómo evalúa, carga las notas desde el
  teléfono, los promedios se mantienen solos y el alumno los ve el mismo día.

  | | |
  |---|---|
  | `MOR-93` | El cálculo, verificado contra el Reglamento. **Guardaba 14,67 donde la norma dice 15** |
  | `MOR-94` | El profesor define sus evaluaciones y su ponderación |
  | `MOR-95` | La planilla de carga: guardado nota por nota, móvil primero |
  | `MOR-96` | Cargar una nota mueve el promedio, sin que nadie se acuerde |
  | `MOR-97` | El alumno ve sus notas — y lo que falta corregir |

  **La norma manda.** Reglamento General de la LOE: **Art. 108** (entero del 1 al 20; ≥ 0,50 sube),
  **Art. 111** (el anual es el *promedio* de los lapsos, sin ponderar) y **Art. 112** (la nota de la
  segunda oportunidad es la definitiva). Decisión explícita de Daniel: apegarse a la norma en vez de
  generalizarla. `evaluation_moments.weight` se queda pero **ya no entra en ningún cálculo**.

  **Tres trampas que costaron encontrar y valen para lo que viene:**
  1. **ActiveJob deserializa los argumentos ANTES de los `around_perform`.** Un job con contexto de
     colegio que recibe un `Section` resolvía su GlobalID sin colegio → cero filas. `CarriesSchool`
     engancha `perform_now`, que envuelve también la deserialización.
  2. **`unscoped` no se salta el RLS.** Quita el `default_scope` de la app y nada más. Contar sin
     contexto da cero, no todo.
  3. **Sin nota no es cero**, y hay que sostenerlo en las tres capas: el cálculo devuelve `nil`, la
     planilla borra la fila al vaciar el campo, y la vista del alumno escribe "Pendiente" en letras.

- **`MOR-98` · Boletines en PDF con verificación pública.** Commit `76d8bf3`. **Prawn**, elegido
  porque no necesita ningún binario del sistema: `wkhtmltopdf` está archivado por sus autores y
  Grover pide Node, y **el entorno de despliegue todavía no está decidido**.

  Una sola tabla —`report_cards`— resuelve tres cosas: el `snapshot` es el **archivo** (un boletín
  de diciembre sigue diciendo lo de diciembre aunque corrijan una nota en marzo), `issued_by` es la
  **auditoría**, y `code` es la **verificación** en `/verificar/:code`, pública y sin sesión.
  Verificado de punta a punta: PDF de 20 páginas por HTTP, código leído del papel, verificación
  devolviendo lo mismo.

- **`MOR-105` · Un solo pipeline, `bin/ci`, en 10 s.** Commits `0bc4451` y `7eba062`. `config/ci.rb`
  define qué se verifica y corre igual en la máquina y en GitHub. **El primer paso comprueba que el
  rol de la base no pueda saltarse el RLS** — si fuera superusuario, ningún otro paso se daría
  cuenta, porque los tests seguirían en verde. Verificado apuntando la app a un superusuario: falla
  en medio segundo.

  De paso: **`bin/setup` estaba roto en una máquina nueva** (hacía `db:prepare` conectándose como
  un rol que todavía no existía), y quien lo arreglaba a mano terminaba con un superusuario y el
  RLS decorativo. Ahora hace lo que `CLAUDE.md` decía que había que hacer.

- **El repositorio ya está enlazado y el CI corre en GitHub.** Esta copia local no
  tenía el remoto configurado —`.git/config` solo tenía `[core]` y `[lfs]`— por eso
  parecía que no había repo. Es `danielousky/siga`, privado. Las tres ramas
  encadenadas están subidas y **`main` sigue intacto**, para revisar por PR.

- **`MOR-105` cerrado · CI en verde en GitHub.** El workflow falló tres veces antes
  de andar, y ninguno de los tres errores se puede encontrar en la máquina de uno:
  el `Gemfile.lock` solo tenía plataformas de macOS; el paso de seeds dejaba la base
  de test sembrada y **el que reventaba era el `bin/rails test` de después**; y las
  tablas de `siga_test` no eran del rol de la app — bug que también estaba en
  `bin/setup` y que una máquina nueva se habría comido entero.

- **`MOR-101` + `MOR-104` cerrados · los dos agujeros de una URL pública.**
  No hay registro público (`/users/sign_up` da 404) y las cuentas nacen del panel
  del colegio. Los seeds no corren fuera de desarrollo salvo declarando
  `SIGA_ENTORNO_DEMO=1` **y** una contraseña propia, que fuera de desarrollo no
  tiene default. El correo personal salió del repositorio.

  El guard vive en `lib/seed_guard.rb` y no dentro de `db/seeds.rb` por algo que
  descubrí probándolo: **contra producción Rails aborta ANTES de llegar al guard**,
  por la conexión. Uno lo escribe, ve que falla, y cree que funcionó — cuando ni se
  ejecutó. Como clase se prueba de verdad.

- **La app se puede desplegar** (`DESPLIEGUE.md`). Dockerfile para Dokku, TLS por
  variables de entorno con HSTS de una hora, correo por SMTP, `GET /up`, y
  `bin/docker-entrypoint` que corre `rls:verificar` **antes** de levantar Puma.

  El hallazgo que habría roto el deploy: `database.yml` tenía `username: siga`
  escrito, y **las claves del archivo ganan sobre las de `DATABASE_URL`** —al revés
  de lo que dice el comentario que trae Rails—. Dokku inyecta la URL correcta y la
  app se habría conectado igual como `siga`. Se vio corriendo producción a mano:
  `/up` en 200 y toda vista con base en 500.

- **`MOR-90` cerrado · 173 tests, y la lección de por qué una suite puede no morder.**
  La primera versión medía las dos capas juntas: rompí el `default_scope` **entero** a
  propósito y **los 54 tests siguieron en verde**, porque el RLS filtraba igual. Que cada
  capa alcance sola es exactamente lo que se quería del diseño — y significa que un test
  que las mide juntas **no puede detectar la pérdida de una**. Ahora cada capa se mide con
  la otra apagada (`test/models/aislamiento_estructural_test.rb`).

  Y tres agujeros que **ninguna de las dos capas podía tapar**, los tres del mismo tipo:

  | Encontrado por | Qué era |
  |---|---|
  | QA de Daniel | `/departments/new` ofrecía un `<select>` con **los dos colegios** — y 5 formularios más |
  | QA de Daniel | La columna "Escuela" repetida en cada fila de los listados |
  | Milestone "División de Admins" | **Cualquier `director` veía el pipeline comercial completo** en `/demo_requests` |

  > La defensa en profundidad protege **los datos del inquilino**. No protege el **catálogo
  > de inquilinos** (`School`) ni los **datos de la plataforma** (`demo_requests`, que no
  > tiene `school_id`). Son dos problemas distintos y el segundo depende de acordarse en
  > cada pantalla nueva. De ahí salió `MOR-133`.

- **`MOR-99` · analizados Akdemia y Edudatos, y la segunda conversación de Cyndi.**
  Lo verificable está en `CLAUDE.md § Contexto de mercado`. Lo que cambió el plan:

  1. **`MOR-129` se derrumbó de alcance.** El sistema anterior de Cyndi (Arcada) ya hacía
     lo que hace falta: el docente carga **el número**, al representante se le muestra **el
     literal**. Deja de ser un cambio de esquema en dos capas y pasa a ser un **mapeo de
     presentación** — no se toca ningún `CHECK` ni ninguna validación `1..20`.
  2. **`MOR-136`, nuevo y es el único diferenciador que apareció**: persistir competencias
     e indicadores entre lapsos y años. Cyndi dice que **ningún sistema lo resuelve**, y es
     lo único que nombró como "lo principal".
  3. **Cobranza y representantes suben de prioridad**: los tres competidores los tienen.

  ⚠️ **`crt.sh` estaba caído (502)**: el censo de SAE no se pudo rehacer y **el cruce para
  ver si algún colegio está en dos sistemas a la vez quedó pendiente** — no dio negativo.

- **Proyecto "Apreciaciones Iniciales" tenía dos milestones y cero issues.** Ahora tiene tres:
  `MOR-133` (la administración de SIGA vive dentro del panel de los colegios · P1),
  `MOR-134` (arreglos de primera impresión antes de la demo · P2) y
  `MOR-135` (moldear el rediseño — **bloqueado a propósito** hasta que haya más estructura).

- **`MOR-134` + `MOR-137` cerrados · la app ya se puede mostrar.** Commits `482df7c`
  y `01497ea`, 201 tests.

  La barra de contexto trae el colegio y el año escolar de verdad —Bolívar dice
  `2026-2027 · comienza el 15 de septiembre`, Bello `2025-2026 · finalizado`—, los
  listados dicen cuántos son (**200** vs **90**, el remate de la demo, ya legible),
  el menú en el teléfono es una tira que se desliza en vez de trece enlaces
  apilados, y **Font Awesome salió**: se traía de un CDN en cada página para el
  ojito del login.

  **Dos cosas que valen más que el código:**

  1. **La búsqueda estaba rota a medias y por eso nadie la vio.** `ILIKE` ignora
     mayúsculas pero **no acentos**: `lopez` daba 0 y `ramos` daba 7. Se prueba con
     el primero de la lista, anda, y se cierra. En Venezuela eso es López, Pérez,
     Guzmán, Rodríguez, Martínez — la mayoría del país.

     Se arregló con `translate()` y **no** con `unaccent`, que desde PostgreSQL 13
     no es *trusted* y exige superusuario — o sea que chocaba de frente con
     `MOR-87`. Costo medido: **+0,026 ms**, porque el `school_id` acota a los 200
     alumnos del colegio antes de que la expresión corra. *El aislamiento paga la
     búsqueda.*

  2. **Lo destapó un cambio que no lo buscaba.** El indicador de escala convirtió
     una tabla vacía —que se lee como "no hay resultados"— en un `0 estudiantes`
     en números grandes. Mostrar la cantidad no era cosmético.

  Y apareció el **cuarto caso** del hueco de `MOR-133`: la corrección de
  `/demo_requests` tapó el controller y no llegó a la vista, así que el panel
  seguía diciéndole al director cuántas solicitudes de demo hay pendientes.
  **Tapar la puerta no alcanza si la pared tiene ventana.**

- **Noche del 13 al 14 de agosto · cuatro issues de la ruta crítica + constancias.**
  De `a500c6d` a `7dc4ab7`, 47 archivos, ~3.850 líneas. **283 tests.**

  | | Qué cambió de verdad |
  |---|---|
  | `MOR-129` | **Un colegio de primaria ya puede usar SIGA.** Y no costó lo que decía el issue: la respuesta de Cyndi lo convirtió de cambio de esquema en dos capas a un **mapa de presentación**. Cero `CHECK` aflojados. |
  | `MOR-111` | **Asistencia**, con la pantalla que entra en un minuto: todos presentes por defecto, se tocan las excepciones. |
  | `MOR-110` | **Portal de representantes** — el rol más numeroso del sistema, que no tenía ni una pantalla. |
  | — | **Constancias de estudio.** El documento que la secretaría escribe en Word, uno por uno. |

  **Las tres decisiones de diseño que valen para lo que viene:**

  1. **La escala cuelga del GRADO, no del colegio.** Un mismo colegio tiene primaria
     por literal y bachillerato por número. `grades.level` ya existía pero contesta
     otra pregunta —a qué nivel pertenece— y la certificación EMG tiene dos áreas
     por literal *dentro* de media general: ni dentro de un nivel la respuesta es
     única.

  2. **El colegio del representante sale de la sesión, y no es una excepción a la
     regla.** El conjunto viene de sus filas de `Representative` —vínculos que
     cargó el colegio, no él— y un id fuera de ese conjunto se descarta. La regla
     nunca fue *"el colegio no puede venir de la sesión"*: es **"no puede venir de
     algo que el usuario controla sin que el sistema lo haya verificado"**. Hay un
     test que manda un id ajeno y verifica que no pasa nada.

  3. **Asistencia tiene botón "Guardar" y la planilla de notas no.** Parece
     inconsistente y es deliberado: las notas son 30 valores tipeados y media hora
     de trabajo, así que cada una viaja sola. La asistencia son 3 toques, y con una
     conexión mala **una petición chica llega mucho más seguido que treinta**. La
     regla es "que el profesor no pierda su trabajo", y acá se cumple al revés.

  **Dos bugs que solo aparecieron al MIRAR, no al testear:**

  - La constancia salía con las etiquetas `<b>` impresas literalmente. Los tests
    pasaban: verificaban que el PDF existiera, no lo que decía. Se vio convirtiendo
    el PDF a imagen. Y arreglarlo destapó otro: con `inline_format`, un colegio
    llamado *"Bolívar & Asociados"* rompía el parser de Prawn.
  - El portal dejaba **encerrada** a una madre con un hijo en cada colegio: con un
    solo hijo saltaba directo al detalle, y el selector de colegio vive en la vista
    que se estaba salteando.

- **`MOR-133` decidido por Daniel: app aparte, mismo host de Dokku.** Comparte
  PostgreSQL, y eso sigue siendo seguro porque el aislamiento vive **en la base**:
  un segundo proceso con el rol `siga_app` está sujeto a las mismas políticas. De
  paso resuelve el rabbit hole 2 — en una app que por naturaleza ve todos los
  colegios, el bypass es la norma y no se confunde con un descuido.

**Pendiente inmediato, en orden:**

1. **La demo pública.** Ya se puede hoy, sin servidor:

       SIGA_HOSTS=".trycloudflare.com" bin/rails server
       cloudflared tunnel --url http://localhost:3000

   Está en `DESPLIEGUE.md` con qué mostrar y en qué orden.

2. **`MOR-102` y `MOR-103` esperan infraestructura.** El correo está configurado y
   falta un proveedor SMTP; el TLS está activo y falta el certificado. Los dos
   cierran sin tocar código cuando estén Contabo y el dominio.

3. **`MOR-129` · el literal A–E, ahora barato.** Cyndi contestó las cuatro preguntas
   que el issue tenía abiertas: A = 20–19, B = 18–17, C = 16–14, D = 13–10,
   **E = por debajo de 10** (el mismo corte de aprobación que el Art. 108). Sale de
   un **promedio numérico**, así que no hay aritmética sobre literales. Queda una
   tabla de rangos **colgada del grado, no del colegio** —un mismo colegio tiene
   primaria por literal y bachillerato por número— y mostrar **las dos cosas** en el
   boletín, porque el representante igual pregunta *"¿y cuánto, profe?"*.

4. **`MOR-133` · la administración de SIGA vive dentro del panel de los colegios.**
   P1, y ya costó **cuatro** agujeros: el controller de `/demo_requests`, la vista
   del panel, el `School.all` de los formularios y la columna "Escuela" de los
   listados. `desarrollador` es el parche de hoy y está escrito como tal en el
   código. Van a seguir apareciendo mientras compartan superficie.

5. **Lo que hay que pedirle a Cyndi**, en un solo mensaje: la constancia de
   **inicial**, la plantilla **en blanco** de la EMG 31059, si preescolar usa los
   mismos literales (mandó dos capturas sin mirar), y las cinco preguntas de
   `MOR-136` sobre las competencias.

- **`MOR-135` cerrado · el rediseño, decidido y ejecutado.** De `1859940` a `dc027c5`,
  **354 tests**, `bin/ci` en verde.

  El issue pedía **decidir**, no dibujar. Las cuatro decisiones quedaron escritas —y como
  los bloqueantes (`MOR-110`, `MOR-129`, `MOR-111`, `MOR-108`, `MOR-133`) se habían cerrado
  en el camino, se aplicaron en la misma tanda.

  **Tres hallazgos que valen más que las pantallas:**

  1. **La página que llega por WhatsApp pesaba 1,45 MB**, de los cuales **1,19 MB era el
     logo**: un PNG de 1024 px puesto donde se dibuja a 140. A 400 kbps —el piso realista
     en Venezuela— son 29 segundos de pantalla en blanco antes de ver un formulario de
     cuatro campos. Quedó en **260 KB**. Techo declarado: **≤ 300 KB por página pública**.

  2. **44 botones apuntaban a clases de Bootstrap que esta app no carga** — `btn-danger`
     (los 15 de borrar), `btn-outline-primary` (23), `btn-outline-secondary` (6) — más
     **80 clases de espaciado** en 39 vistas, o sea cero separación entre los campos de
     TODOS los formularios. Un botón así no explota: hereda `.btn` y se dibuja como texto
     suelto. *Esa era la causa real de "parece de otro sistema".* Nada en el pipeline lo
     veía: el HTML es válido y el humo devuelve 200. Ahora hay un test que lo fija
     (`test/integration/sistema_de_diseno_test.rb`).

  3. **El botón "Eliminar" fallaba 200 de 200 veces** en alumnos: cualquier alumno con
     inscripciones está protegido por `restrict_with_error`, y un alumno sin inscripciones
     no existe en un colegio real. Ahora aparece **solo donde va a funcionar** —dos de
     nueve recursos— y donde no, explica qué se perdería (`BorradoHelper`).

  **Lo demás:** portada reescrita (una tesis, cifras con fuente, precios leídos de
  `Subscription::PLANES`, ningún enlace muerto); página de demo con 4 campos y WhatsApp
  obligatorio, donde **pedirla dos veces ya no devuelve un error de validación** sino que
  suma en `veces`; fichas de alumno, grado, materia y profesor reescritas; cinco `show` que
  solo repetían la fila del listado, borradas; el menú del administrador reordenado **por
  frecuencia** (19 enlaces → 10 a la vista, resto en un `<details>`); 75 rótulos de Title
  Case a minúscula de frase.

  **Dos correcciones de rumbo, del propio Claude:**

  - El logo que usé no era el de SIGA: reconstruí con cuidado la sintaxis de un SVG roto
    (`siga-logo.svg`) sin preguntarme si ese archivo era siquiera el logo. El de verdad es
    `logo.svg`. Daniel lo corrigió y pidió que volviera el hero, que yo había sacado.
  - Los seeds daban **30 nombres distintos para 200 alumnos** —el mismo índice para nombre
    y apellido, así que solo salía la diagonal— y la lista mostraba "Blanco, José" tres
    veces seguidas. Mi primer arreglo (`k*7 + 3`) **no arregló nada** y lo di por bueno; lo
    vi porque conté los pares distintos en vez de mirar la fórmula. Arreglarlo destapó
    además que **`db:seed` no era idempotente ante cambios de contenido**: buscaba al alumno
    por correo, y el correo se deriva del nombre.

  ⚠️ **Trampa de medición, anotada para el próximo:** Chrome en macOS no abre ventanas de
  menos de 500 px, así que `--window-size=430` renderiza a 500 y *recorta* la captura —todo
  parece desbordado y no lo está. Para un ancho de teléfono real hay que meter la página en
  un `<iframe>` de 390 px **servido desde el mismo origen**: `X-Frame-Options: SAMEORIGIN`
  bloquea hacerlo desde `file://`.

- **La regla de color, auditada pantalla por pantalla + barrido visual.** De
  `d3fb5e2` a `0f80ab6`, **364 tests**.

  La regla es *el color lo usa el DATO, nunca el CONTROL*, y en un sistema
  escolar no es negociable: **un número en rojo es un niño aplazado**. Está en
  la libreta que mira una madre desde el teléfono. Si el rojo también quiere
  decir "este botón borra cosas", deja de decir lo primero.

  No se auditó pantalla por pantalla a ojo, sino cruzando **qué clases con
  color conviven en cada vista**: un rojo de control solo compite cuando está en
  la misma pantalla que un rojo de dato. 46 reglas usan color semántico; seis
  eran violaciones, una parecía violación y no lo era (`.asistencia-boton`: ahí
  el botón ES el estado, tocarlo cicla presente→ausente→tarde) y aparecieron dos
  que no buscaba —un ámbar escrito a mano y un `.status-pendiente` **pintado de
  verde** por un `style` inline, con las dos clases inexistentes—.

  Lo destructivo pasó a señalarse por **peso y posición**: borde fuerte, tinta
  sólida en hover, dentro de un bloque rotulado de la pantalla de edición. Y el
  rojo se quedó en la frase que nombra lo que se perdería, que es su trabajo.

  **Y después, mirar pantalla por pantalla encontró lo que ningún test veía:**

  1. **Los dos ojos del campo de contraseña se dibujaban superpuestos**, desde
     `MOR-134`, en la pantalla que un profesor abre cada mañana. Y **una caja de
     aviso vacía con un botón "Reintentar"**, permanente, en la planilla de
     notas. La misma causa: `[hidden] { display: none }` es del NAVEGADOR y
     cualquier `display` de autor le gana. Resuelto de raíz con
     `[hidden] { display: none !important }` — `hidden` es una afirmación sobre
     el DOM, no una sugerencia de estilo.
  2. **`.role-badge` traía `text-transform: capitalize`**, que capitaliza cada
     palabra: la pantalla de asistencia decía **"15 De Agosto De 2026"**. El
     HTML estaba bien; lo rompía la hoja de estilo, y por eso el barrido de
     Title Case de las vistas no lo había tocado.
  3. **La cabecera de TODAS las pantallas se encimaba en el teléfono**: flex sin
     `flex-wrap`.
  4. **Regresión mía:** el `<details>` del menú dejaba **nueve pantallas
     inalcanzables desde un teléfono** —la tira se desliza en horizontal y tiene
     `overflow-y: hidden`, así que lo que el `<details>` despliega hacia abajo
     queda recortado—. Y el CSS **no** puede forzarlo abierto: Chrome lo esconde
     por el slot de su shadow DOM, que es justo lo contrario del caso de
     `[hidden]`. Se resolvió renderizando el grupo de dos formas, apagando cada
     una en el ancho de la otra.

  **Los tres paneles pasaron a contestar la pregunta con la que se entra:** el
  del director muestra qué atender (con enlace a donde se resuelve) en vez de
  repetir el menú con emoji; el del profesor abre en lo que le falta corregir,
  con "Cargar notas" al lado; el del alumno muestra la nota, que antes estaba
  detrás de un botón.

  ⚠️ **Tres mediciones mintieron en esta tanda**, y las tres se zanjaron igual:
  renderizando completo y mirando. `getClientRects()` y `getComputedStyle()` en
  Chrome headless reportan cajas y `display` para el contenido de un `<details>`
  **cerrado**; y antes de eso di por bueno un colapso mirando una captura
  recortada a 900 px de alto. Para ver el final de la tira del menú hay que
  ponerle `scrollLeft = 99999` antes de capturar.

- **Cierre de pendientes técnicos.** De `59ef5ef` a `d0731c1`, **382 tests**.

  **La cola de trabajos deja de perderse.** Era `:async`, que guarda la cola en
  memoria del proceso web: un deploy se llevaba lo encolado sin dejar rastro, y
  el único job que hay recalcula los promedios de una sección entera. Ahora
  **Solid Queue sobre la misma base** —sin base aparte: para un job de un
  segundo, una segunda cadena de conexión que configurar, respaldar y
  monitorear no se paga—. Sus once tablas no llevan RLS a propósito: son
  maquinaria de plataforma, y el colegio viaja en el payload (`MOR-88`).
  Verificado a mano: encolar → matar el proceso → `bin/jobs` lo toma.

  **Auditar quién cambia una calificación.** *"¿Quién le cambió la nota a mi
  hijo?"* es la pregunta que un colegio necesita responder, y el sistema no la
  contestaba: había etiquetas para "Calificación registrada/modificada/
  eliminada" y **nadie las emitía**. Ahora queda quién, a quién, en qué
  evaluación y **de qué valor a cuál**. Guardar el mismo valor no cuenta: la
  planilla reenvía al salir del campo, y un historial lleno de cambios que no
  ocurrieron esconde los que sí.

  **Y una regresión mía, encontrada en el camino:** al borrar los cinco `show`
  que solo repetían la fila del listado, quince redirecciones quedaron
  apuntando a rutas que ya no existen. **No explotaban** —el helper
  `department_path` sobrevive porque `PATCH` y `DELETE` comparten esa ruta— así
  que creaban bien y dejaban al usuario en un 404. Ningún test lo veía porque
  ninguno ejercía alta ni edición de esos recursos; ahora hay uno que falla
  4 de 4 sin el arreglo.

  El registro de actividad pasó de cubrir 10 acciones a cubrir 25, con **los dos
  lados fijados por tests**: ninguna etiqueta sin emisor (prometía una auditoría
  inexistente) y ningún emisor sin etiqueta (la mostraba en inglés — incluida
  la visita de soporte de SIGA, que es la que hace defendible el acceso amplio).

  ⚠️ **`CLAUDE.md` estaba desactualizado en cinco puntos** y se verificó uno por
  uno: `force_ssl`, `action_mailer`, el registro público cerrado, el guard de
  los seeds y el Dockerfile ya estaban resueltos. Y **el repo ya tiene remoto**
  (`danielousky/siga`), así que el workflow de GitHub Actions puede correr —
  decía lo contrario. La rama actual está **21 commits adelante de su remoto**;
  subir es decisión de Daniel.

---

## 17–21 de agosto · SIGA está en producción, y el modelo aguanta a una persona real

### La app corre en Contabo, con dominio y HTTPS

`https://sigaeducando.com` — Dokku 0.38.27, PostgreSQL 18.4, Let's Encrypt con renovación
automática por el plugin de cron de Dokku (**no** `crontab -l`, que dice "no crontab for root"
y no significa nada).

Lo que costó descubrir, en orden:

- **La app se conectaba como `postgres`**, que es SUPERUSER y tiene BYPASSRLS. Con eso el
  aislamiento entre colegios **no se evalúa ni una vez** y nada lo delata. Ahora corre como
  `siga_app`, dueño de la base, sin ninguno de los dos atributos.
- **Mi verificación de la contraseña fue un falso positivo.** La probé por `127.0.0.1`, donde
  `pg_hba.conf` usa `trust`; la app se conecta desde otro contenedor, donde usa `scram-sha-256`.
  El `ALTER ROLE ... PASSWORD` había fallado en silencio —el heredoc se perdió entre `ssh` y
  `docker exec`— y la prueba pasaba igual. Se rehízo con `psql -c` y se verificó contra
  `172.17.0.2`.
- **Las migraciones no corrían en ningún despliegue.** El `entrypoint` comprobaba `./bin/rails`
  y el `Procfile` decía `bundle exec rails`. Daniel señaló que en otras apps usa `release:` y
  que no había doble ejecución — tenía razón y yo había omitido esa opción. Quedó
  `release: sh -c "..."`, con el `sh -c` porque Dokku no pasa `&&` por un shell.
- **Let's Encrypt rechazó la orden entera** por tener una IP en la lista de dominios. Culpa mía
  por agregarla.
- **HSTS duplicado**: nginx agregaba `max-age=15724800` encima del `max-age=3600` deliberado de
  Rails. Se apagó con `dokku nginx:set siga hsts false`.

El runbook privado está en `references/SERVIDOR-PRODUCCION.md` (+ `.html`), fuera de git,
`chmod 600`. Incluye restaurar desde cero y cómo entrar desde otra máquina.

### `MOR-138` · La identidad vive en la persona, no en su rol

Cuatro cosas, y la tercera es la que abrió todo lo demás:

1. **`id_card` → `document` + `document_type`.** El MPPE acepta cuatro documentos, no uno.
2. **`cedula_escolar` en `users`.** No era el carnet del plantel: es un identificador
   **nacional** que acompaña al alumno cuando se muda de colegio. El backfill desde
   `students.school_card` **falló**, y ese fallo es la prueba: 90 de 290 alumnos compartían
   carnet entre Bolívar y Bello. Eran numeración interna, no cédulas escolares.
3. **Los roles tienen PK propia.** `students` usaba `user_id` como clave primaria, así que una
   persona podía ser alumno en **un solo colegio de toda la plataforma**. `representatives` ya
   tenía la forma correcta: la misma pregunta estaba respondida de dos maneras dentro del
   mismo modelo. Ahora los cuatro roles llevan `id` propio + ÚNICO `(user_id, school_id)`.
4. **`name` → `first_name` / `last_name` / `second_last_name`.** El SAIME verifica el PRIMER
   apellido contra la partida de nacimiento, y con "López Medina" entero eso no coincide nunca.

⚠️ **Tres índices únicos se perdieron en silencio** al recrear las columnas de la migración, y
`bin/ci` quedó en verde porque ningún test intenta dos veces una operación prohibida. Se
encontraron **difeando `db/structure.sql` contra el commit anterior**, que de ahora en adelante
es el paso obligatorio después de una migración que toque claves.

⚠️ **Y los campos nuevos se guardaban sin verse.** Actualicé los 5 formularios y ninguna de las
~20 vistas de lectura. Lo encontró Daniel mirando la app, no un test.

### Decisión de producto: el alumno no es una cuenta

Se investigó con agentes especialistas y con búsqueda web sobre los competidores globales.
Todos convergen en lo mismo, y la ley (GDPR/COPPA) los empujó ahí — Venezuela no tiene ley de
protección de datos, así que acá la razón es puramente de producto:

```
   Student         nunca entra   ·  el que consulta es su representante
   Representative  opcional      ·  entra si tiene correo; si no, el colegio se lo pide
   Teacher         obligado
   Admin           obligado
   SigaStaff       obligado
```

El login sigue siendo el **correo**, no la cédula. Autenticar por cédula se evaluó y se
descartó: mueve el hueco en vez de taparlo, porque un alumno de primaria tampoco tiene cédula.

De ahí salieron tres issues: `MOR-142`, `MOR-143` y la reescritura de `MOR-126`.

### `MOR-142` · Una persona puede existir en SIGA sin poder entrar — **hecho**

`email` y `encrypted_password` pasan a nullable. Volver `email` nullable **no alcanzaba**: el
índice único era plano y `''` es un valor como cualquier otro, así que PostgreSQL admitía
**exactamente un usuario sin correo en toda la plataforma** — el alumno 2 de 360 reventaba.
Hacen falta las tres cosas y ninguna sirve sola: pasar los `''` a NULL, un índice
`WHERE email IS NOT NULL`, y que el modelo convierta a `nil` el `""` que manda cada `<input>`.

Sin contraseña nadie entra, y sin agregar ninguna bandera: `Devise::Encryptor.compare` arranca
con `return false if hashed_password.blank?`.

El correo lo exige el **rol**, no `User` — concern `EntraAlSistema` en `Teacher`, `Admin` y
`SigaStaff`. Y `document` se normaliza según su tipo: la cédula queda en dígitos (la
nacionalidad ya está en `document_type`), pero un pasaporte tratado igual pierde sus letras y
termina identificando a otra persona.

⚠️ **Escribí en el issue que el alta de representantes "duplicaba", y lo medí contra la app:
no duplica, BLOQUEA.** El índice único de `users.document` impide el duplicado; lo que pasa es
que el colegio B no puede registrar a una madre que ya existe en el colegio A —422 "Document ya
está en uso"— y la secretaria no tiene salida, porque el RLS no la deja ver a esa persona. Es
la promesa de `MOR-138` rota justo en el camino por el que se llega a ella. El issue quedó
corregido.

⚠️ **Y cinco de seis tests de esa suite pasaban igual contra el código viejo.** Contar personas
no prueba nada acá: bloquear el alta también deja el conteo quieto. La aserción tuvo que exigir
las dos mitades —ni persona nueva, **y** rol creado—.

Los seeds ahora cargan **90 alumnos de primaria sin correo ni contraseña**, que además de ser el
caso real es la prueba a escala del índice parcial, y una cuarta representante **sin correo**
para poder ver en pantalla lo que el importador va a producir por centenas.

### `MOR-143` · El colegio da de alta y la persona elige su contraseña — **hecho**

Es `recoverable` de Devise con otro texto: genera el token, lo digiere, lo caduca, lo consume
una vez. Cambia de dónde sale el disparo —la secretaria, no el usuario— y qué dice el mensaje.
El correo va en un mailer propio porque recibir *"¿pediste cambiar tu contraseña?"* cuando uno
nunca tuvo cuenta se lee como phishing.

```
  ficha del representante  →  [Generar el código de acceso]
                                    │
                    ┌───────────────┴───────────────┐
              con correo                        sin correo
        se envía Y se ve una vez          se ve una vez, y nada más
                    └───────────────┬───────────────┘
                                    ▼
                        /activar/:token   (público)
                     contraseña + correo si falta
```

Dos plazos, deducidos del estado sin guardar ninguna bandera: quien **no tiene** contraseña
está activando (**72 h**, porque la secretaria carga un jueves y la mamá abre el domingo);
quien ya la tiene está recuperando (las **6 h** de Devise, sentada frente a la pantalla).

El código se ve **una sola vez**, y eso es la propiedad que se quiere, no una limitación: una
pantalla con el código vigente de cualquier representante sería una lista de llaves de todas
las casas.

⚠️ **Buscando huecos en lo que acababa de escribir encontré uno de verdad.** El mismo token
abre también `/users/password/edit`, el formulario estándar de Devise, **que no pregunta por el
correo**:

```
    GET  /users/password/edit  → 200
    PUT  /users/password       → 303
    ¿quedó con contraseña? true
    ¿quedó con correo?     nil
```

Eso es exactamente el estado que el issue dice que no puede existir. Se cerró con un
**invariante en `User`** —tener contraseña obliga a tener correo— y no con un parche en el
controller, porque la puerta de Devise no es la única: están la consola y el importador que
todavía no existe. Al revés sí se puede, y es el caso normal: correo sin contraseña es alguien
a quien todavía no le activaron el acceso.

### Y con eso, el primer minuto de vida de un cliente dejó de ser un callejón

El alta de un colegio le ponía al director una contraseña aleatoria de 14 caracteres que
**nadie conocía**, y la nota del propio formulario lo admitía: *"hay que mandarle un enlace para
que la defina. Eso llega cuando haya correo configurado"*. El enlace ya existe, así que ahora el
alta lo genera y lo muestra. Hay un test que recorre el camino entero: fundador da de alta → sale
el enlace → la directora elige su contraseña → cae en el panel de **su** colegio.

En ese mismo formulario, `director[document]` estaba **dos veces con el mismo `name`** —ganaba
el segundo, que es el que nadie llenaba— y faltaba el segundo apellido aunque
`usuario_params` ya lo permitía.

Y **ocho vistas más seguían mostrando un solo apellido**: los listados de profesores y
administradores, el selector de profesor guía, las dos tablas de inscritos de una sección, la
ficha del alumno y las dos pantallas del portal del representante. Misma clase de bug que en
`MOR-138`: los helpers `nombre_completo` / `apellidos` / `apellidos_y_nombres` existen y esas
vistas seguían concatenando a mano.

⚠️ **Y una regresión mía:** al aflojar `password_required?`, el formulario de profesor y el de
administrador dejaron de fallar con la contraseña en blanco — creaban a alguien que no puede
entrar, en silencio. El campo volvió a ser obligatorio, y los dos listados ganaron una columna
"Acceso" para que nunca vuelva a ser invisible.

### `MOR-126` reescrito, no cerrado

El importador ya tiene su forma: tres tandas (1 · alumnos + representantes + secciones +
inscripción · 2 · materias, pensum y profesores · 3 · historial de notas), la clave de
identidad decidida (`document`, si no `cedula_escolar`, **nunca** el nombre ni el carnet del
plantel), y el correo del representante como **único prerrequisito** — que no bloquea la carga:
la fila entra igual y sale listada al final, en pantalla y en planilla.

---

## 24–25 de agosto · el importador, tandas 1 y 2

`MOR-126` completo hasta la tanda 2. Un colegio sube su planilla, ve qué se va a cargar y
confirma; el recorrido es el mismo para las dos planillas y `tipo` decide qué se espera y
qué se crea.

```
   new/create   subir el archivo         ← ?tipo=matricula | ?tipo=pensum
   show         el mapeo propuesto, con un ejemplo de la primera fila al lado
   update       guardarlo  →  previsualizar
   confirmar    escribir, fila por fila en su propio SAVEPOINT
   resultado    qué entró y qué no, con el número de fila DEL ARCHIVO
```

| Tanda | Qué trae | Estado |
|---|---|---|
| **1** | alumnos · representantes · secciones · inscripción | ✅ |
| **2** | materias · pensum por grado · profesores y su asignación | ✅ |
| **3** | historial de notas de años anteriores | ✅ |

**El importador está cerrado.** Un colegio trae todo lo que tiene, y **nada es un callejón**:
cuando falta una entidad, la previsualización la lista con su conteo y ofrece crearla de un
clic — el año escolar con sus lapsos, el grado proponiendo dónde cortar «3er Año C», y la
sección.

### Lo que hizo difícil a la tanda 3

**Cada fila puede ser de un año escolar distinto**, y eso rompe el supuesto de las otras dos:
«3er Año A» es una sección diferente en cada año. Por eso `HistorialInterpretado` sobrescribe
`secciones_de_la_planilla` y esta planilla no lleva selector de año.

Y antes de escribir una línea del importador había que resolver esto, medido:

```
   nota histórica cargada:   1
   tras UN recálculo:        0     ← destruida
```

No era un bug: es la regla que hace que «sin nota» no sea cero. La regla no se aflojó; se
agregó `origen` para distinguir «sin respaldo» de «con un respaldo que no está acá».

### Lo que costó más de un intento

- **La fila de encabezados.** Tres versiones: «una celda menos que el encabezado», «la
  mitad», y al final ninguna densidad — lo que de verdad separa el membrete de los datos es
  la **línea en blanco**.
- **Cuatro bugs de mapeo**, los cuatro destapados por el mismo test: generar la plantilla y
  volver a leerla con el mapeo automático. `«APELLIDOS Y NOMBRES DEL REPRESENTANTE»` caía en
  el nombre del alumno; `«OBSERVACIONES»` en la cédula, porque contiene `ci`.
- **El import partido entre dos años escolares.** Las secciones vivían en 2025-2026 y
  `vigente` era 2026-2027. El año escolar quedó como selector **en la previsualización**,
  que es donde se ve el problema.
- **El importador le borró el nombre a un profesor.** La planilla traía a otra persona con
  una cédula ya registrada. Buscar por cédula es correcto y no se toca —es lo que hace que
  una persona con rol en dos colegios sea una sola—; lo que faltaba era **notarlo**.

### Lo compartido se extrajo, no se copió

| Módulo | Qué guarda |
|---|---|
| `InterpretaLaPlanilla` | secciones, personas, error vs aviso, el año escolar |
| `EscribePersonas` | buscar **sin aislamiento** y qué se pisa al actualizar |
| `PlantillaDeImportacion` | el libro, los estilos, el panel congelado |

### Y una decisión de la tanda 2 que se puede leer mal

El **código de la materia** identifica a la materia dentro del colegio y sale en boletines.
Cuando la planilla no lo trae, SIGA lo inventa —y lo **lista** antes de confirmar, porque
ningún algoritmo acierta las elecciones humanas de un colegio: en los propios seeds
«Castellano y Literatura» es `LEN`. Reutilizar y chocar no son lo mismo: si el colegio ya
tiene `MAT` = Matemática, la planilla que trae «Matemática» lo reutiliza; solo se busca otro
código cuando el ocupado pertenece a **otro** nombre.

### Lo que salió de probarlo en la pantalla, no en los tests

Montar el escenario en local y recorrerlo entero destapó seis cosas que ningún
test miraba:

- **El conteo por sección salía sin el número.** `pluralizar` devuelve solo la
  palabra; el número lo pone `contar`. Anulaba justo la columna cuyo propósito es
  el conteo, y estaba en seis lugares desde la tanda 1. ⚠️ El test que debía
  atraparlo se llamaba «con su conteo» y verificaba el NOMBRE de la sección.
- **Dos botones «Crear 1er Año A»**, porque `1er Año Á` y `1er Año A` se
  agrupaban por el texto crudo aunque apuntan a la misma sección.
- **El choque de profesor se sabía y se decía tarde**: la planilla ya lo delata,
  pero solo salía después de escribir.
- **Los nombres gritaban** en las dos tablas del importador.
- **Excel no guarda los CSV con coma.** Daniel subió un archivo hecho a partir
  del de prueba y recibió «no encontré la fila de encabezados» sobre una planilla
  perfectamente bien. Un Excel en español separa con punto y coma. ⚠️ El `\r`
  costó una hora: al recortar la muestra antes del último `\n` quedaba un `\r`
  suelto y `CSV` fallaba con TODOS los separadores por igual, así que ganaba la
  coma por ser la primera y el síntoma era idéntico al bug original.
- **El formulario volvía a matrícula al fallar el archivo**, con la URL todavía
  en `?tipo=pensum`.

### Y el código de acceso dejó de ser del rol

El importador lo volvió urgente: carga ocho profesores de un golpe, todos con
correo y ninguno con contraseña, y no había forma de darles acceso salvo
editarlos uno por uno y tipearles la clave — el patrón que `MOR-143` vino a
sacar. Ahora es `GeneraCodigosDeAcceso`, el mismo para representante, profesor y
administrador; un alumno son dos líneas el día que entre.

⚠️ Cuelga de cada controller de rol y **no** de un `/personas/:id/codigo`
central: `User` no es `SchoolScoped`, y acá lo que se filtra no es una ficha, es
una llave.

---

## 25 de agosto · desplegado, y la revisión de funcionalidad

**Producción está al día**, en `7139e7c`. Se desplegaron las tandas 1 y 2 del importador,
el código de acceso generalizado y dos arreglos que salieron de revisar. Respaldo
tomado antes de migrar y verificado (43 tablas con datos), en
`~/Documents/SIGA-respaldos/`.

**Revisión completa de qué hay y qué falta:**
https://claude.ai/code/artifact/59e39507-c3f0-4b36-a432-7ed299ea92ab

El resumen de esa revisión, para no depender del enlace:

```
   EL COLEGIO          LA FAMILIA          EL NEGOCIO DE SIGA
   ──────────          ──────────          ──────────────────
   matrícula      ✓    portal         ✓    aislamiento      ✓
   asistencia     ✓    acceso         ✓    suscripciones    ✓
   notas          ✓    boletines      ✓    cobrar           ✗
   boletines      ✓    WhatsApp       ✗    alta sin ayuda   ✗
   importador     ✓                        monitoreo        ✗
```

**El producto que el colegio usa está construido. Lo que no existe es el negocio
alrededor:** nada cobra (`MOR-128`), un colegio nuevo no puede darse de alta solo
(`MOR-148`, `MOR-109`), y si el worker se cae nadie se entera (`MOR-106`).

### Lo que se hizo de más en esta sesión

- **Nada borraba los archivos importados.** `purgable?` existía desde la tanda 1 y no lo
  llamaba nadie. Ahora `PurgarPlanillasJob` corre todos los días a las 3 —ya registrado en
  el scheduler de producción— y alcanza a las importaciones **abandonadas a medias**, que
  eran las que se quedaban para siempre con datos de 360 menores adentro.
- **Descartar una importación y volver a abrirla daba un 500**, y estaba en producción.
  `archivo.open` sobre un adjunto purgado no revienta: devuelve `nil` sin llamar al bloque.
- **Tres afirmaciones viejas en `CLAUDE.md`**: decía que el correo no sale (sale desde el 21),
  que SIGA no tiene asistencia ni portal (los tiene), y contaba 22 tablas con RLS (son 23).
- **Linear al día**: `MOR-103` llevaba semanas resuelto y figuraba «In Progress»;
  `MOR-126` estaba en Backlog con dos tandas entregadas.

---

## 26 de agosto · los documentos oficiales del MPPE (`MOR-99`)

Un colegio venezolano no compite sin poder emitirlos, y hasta ayer los llenaba a
mano en Word. Ahora salen del sistema:

| Documento | Para quién | Formatos |
|---|---|---|
| **Certificación de Calificaciones** · forma **31059** | bachillerato, 1º a 5º en un solo papel | PDF y **Excel** |
| **Certificado de Educación Primaria** | quien termina 6to Grado | PDF |
| **Constancia de Prosecución** | quien aprueba cualquier otro grado de primaria | PDF |

### Lo que costó: la especificación, no el código

El issue avisaba que *«un formato mal hecho se rechaza en la zona educativa y el
colegio pierde el trámite»*. Se buscó la norma —Resolución DM/0033, **Gaceta
Oficial 41.221** del 24 de agosto de 2017, en vigencia desde el **17 de noviembre
de 2017**— y con eso se dibujó una primera versión.

**Después Daniel mandó un ejemplar real, lleno y sellado, y no se parecía.** La
31059 es una planilla de gobierno: densa, con rótulos diminutos, ocho secciones y
todo apretado en una hoja. Lo que había era un documento moderno, y la diferencia
no es de gusto — quien la recibe la coteja contra la que conoce.

Lo que ninguna descripción escrita mencionaba:

- La calificación va en **número Y EN LETRAS** («11 · ONCE»), que es como se
  protege un documento oficial contra la adulteración. **No** es el literal A–E.
- Un **recuadro por año**, no una matriz: las áreas cambian entre años.
- Columnas `T-E` (**F** final · **R** reparación · **P** pendiente), `Mes`, `Año`.
- **Orientación y Convivencia** y **Participación en Grupos** salen de la tabla y
  van en tablitas aparte, con literal por año.
- **Dos firmas**: VII el plantel certifica, VIII el CDCEE avala.
- El **pie fiscal**: sin las tres décimas de U.T. el documento no tiene validez.

### Y una dependencia que el propio código había anticipado

Esas dos áreas se califican con **letra** aunque estén en bachillerato. El
comentario de `Grade#escala` ya lo había escrito: *«si esas áreas del EMG hacen
falta algún día, la escala tendría que vivir por MATERIA»*. Hacen falta:
`subjects.escala`, NULL por defecto.

### Dos correcciones de Daniel que valen más que el código

1. **La 31059 no cubre primaria** — mandó los dos formatos que sí, y llenaron el
   hueco que había quedado marcado.
2. **Un colegio no dicta «hasta 4to Grado».** La primaria venezolana son SEIS
   grados y se dicta completa. Mi regla decidía cuál documento emitir preguntando
   «¿existe un grado siguiente en este colegio?», y eso hacía depender un
   documento oficial de **qué grados alguien alcanzó a cargar en SIGA**: un
   plantel que todavía no creó 5to y 6to le habría emitido «Certificado de
   Educación Primaria» a un alumno de 3er Grado.

### Y por qué también en Excel

El formato tiene casillas que SIGA no puede llenar —teléfono del plantel, grupo
de Participación, datos del director del CDCEE— y mientras esto se asienta va a
haber más. **Con solo el PDF, el colegio queda bloqueado esperando que nosotros
cambiemos algo.**

---

## 26 de agosto, tarde · el rediseño de la sesión del colegio (`MOR-149`)

La app llegó a agosto con **cero iconos**. Se presentaron tres propuestas
—renderizadas con datos reales, no descritas— y Daniel eligió una combinación:

| Plano | Propuesta | Qué aporta |
|---|---|---|
| Navegación | **B · Consola** | riel encogible, buscador global, atajos |
| Tono | **A · Expediente** | serif en títulos, tablas que se leen como registros |
| Trato | **C · Aula** | avatares donde hay una persona del otro lado |

Las tres, en vivo: https://claude.ai/code/artifact/7f24948a-ff15-4b70-a613-fd139b5947b2

### Lo que está hecho y desplegado

```
   40 iconos propios, sin una dependencia nueva
   4 menús de rol + 60 botones en 46 vistas
   avatares en los 3 listados de personas, la planilla y la asistencia
   menú encogible · buscador global ⌘K · atajos ↑↓↵ esc /
   panel con jerarquía: lo accionable en ámbar, las cifras navegables
```

### Las reglas que sostienen esto

1. **El icono acompaña a la palabra, nunca la reemplaza.** Quien abre SIGA por
   primera vez es una secretaria que hasta ayer llevaba todo en Word.
2. **Nada de iconos en una lista de hermanos.** Diez secciones son diez cosas del
   mismo tipo: el mismo símbolo repetido diez veces es ruido.
3. **La paleta de avatares no toca los colores semánticos.** Ocho tonos fríos y
   terrosos, los ocho con contraste ≥ 4.5:1 medido.
4. **El color del avatar sale del NOMBRE, no del `id`** — con el `id` la misma
   persona cambiaría de color entre dos colegios.
5. **Al encoger el menú, el texto se oculta a la vista pero NO del árbol de
   accesibilidad**: el icono va `aria-hidden`, así que la palabra es lo único que
   nombra al enlace.
6. **Sin Google Fonts.** Dos familias son ~120 KB y dos peticiones a un dominio
   ajeno antes de que se pinte una letra.

Lo fija `test/integration/iconos_y_avatares_test.rb` — 11 tests, 1598
aserciones—, como `sistema_de_diseno_test` y `regla_de_color_test` fijan lo suyo.

### Tres bugs que aparecieron en el camino

- **El listado de estudiantes salía corrido**: cuatro encabezados, cinco celdas,
  `document` repetido. «Cédula escolar» mostraba un guión y «Cédula» mostraba la
  cédula escolar.
- **Las variantes de imagen estaban rotas en producción desde siempre.**
  `image_processing` en el Gemfile, `variant_processor` en `:vips`, y **libvips
  sin instalar**. Ya está: `libvips 8.16.1 cargada ✓`, verificado generando una
  miniatura de verdad. El paquete es `libvips42t64` —Debian 13, transición a
  `time_t` de 64 bits— no `libvips42`.
- **Un test intermitente que llevaba tiempo escondido.** `parallelize` forkea y
  `EscenarioAcademico` numeraba con un contador de clase: cada worker arrancaba
  en 0, así que dos escenarios pedían la misma cédula escolar. El PID desempata.

### Lo que falta del rediseño

La landing (queda como está, por decisión), las pantallas de configuración —se
tocan una vez al año— y los estados vacíos con lenguaje de producto.

---

## Dónde está todo ahora

```
  main  (0cb373b)   ← origin al día · PRODUCCIÓN QUEDÓ ATRÁS, ver abajo
```

`bin/ci` en verde: **1259 tests**, 5.841 aserciones, ~2 min 30 s.

## ⚠️ Pendientes que necesitan a Daniel

0. ~~DESPLEGAR~~ y ~~limpiar producción~~ → **hechos el 5 de septiembre.**
   Producción corre `550792a` con los datos nuevos.

0b. **Confirmar dos decisiones de MOR-216** que tomé sin él: el informe es uno
   por LAPSO (no por materia) y lo escribe el GUÍA de la sección. Están
   marcadas en el spec y en el comentario del issue.

1. **Subir `SIGA_HSTS_SEGUNDOS` a 31536000** cuando pasen unos días sin sobresaltos.
3. **`MOR-144` · DMARC a `p=reject`** — vence el 4 de septiembre de 2026.
4. **`MOR-146` · Limpiar los datos de prueba de producción** antes del primer colegio real.
   Es lo único **urgente** del backlog, y es destructivo: necesita a Daniel delante.

**Resueltos:**

- ~~Rotar la clave de `siga_app`~~ → hecha el 21 de agosto.
- ~~Rotar `RAILS_MASTER_KEY`~~ → **resuelto el 25 quitándola, no rotándola.** Ver abajo.
- ~~Restaurar la suscripción de Bello a `vencida`~~ → ya estaba, verificado.
- ~~Una segunda llave SSH~~ → puesta el 25, y era peor de lo que decía esta nota: la MISMA
  llave abría `root` **y** `dokku`, así que perderla no era perder los despliegues, era
  perder la máquina. Ahora hay dos, en dos equipos, en los dos lugares:

  ```
     root@80.190.77.167    administración   ┐  siga-deploy-202608
     dokku@80.190.77.167   git push         ┘  siga-MacBook-Air-2015-de-Daniel-202608
  ```

  ⚠️ Esto resuelve «si pierdo una, pierdo el servidor» y crea «hay dos laptops que abren
  producción». Es el intercambio correcto para un equipo de dos; cuando entre alguien más,
  lo que toca no es una tercera llave, es que el acceso deje de ser por llaves personales
  repartidas.

### Los secretos: un sistema, no dos

`config/credentials.yml.enc` guardaba **un solo valor**, `secret_key_base`, y todo lo demás
—SMTP, base de datos, host, dominios— ya vivía como variable de entorno en Dokku. El archivo
cifrado era el raro, y traía su propia llave que cuidar, que rotar y que filtrar.

```
   ANTES                              DESPUÉS
   ─────                              ───────
   master.key      (local, secreta)   —
   credentials.yml.enc (en el repo)   —
   RAILS_MASTER_KEY   (en Dokku)      SECRET_KEY_BASE (en Dokku)
   SMTP_PASSWORD      (en Dokku)      SMTP_PASSWORD   (en Dokku)
```

El secreto nuevo se generó **en el servidor** y se puso en la misma orden: no pasó por
ninguna terminal ni quedó en ningún archivo. Verificado por su largo, no por su valor.

⚠️ Cambiarlo **desconecta a todo el mundo** —invalida sesiones y cookies firmadas—. Se hizo
con datos de demo, que era el momento más barato. Los códigos de activación NO se afectan:
Devise los guarda digeridos en la base, no firmados con esta llave.

⚠️ Si algún día hace falta guardar un secreto **en el repo** —una llave privada, un
certificado— vuelve a hacer falta `credentials`. Mientras el despliegue sea por variables de
entorno, no.

## Lo que sigue, en orden

**En cola en Linear, sin abrir** (el acuerdo es una tarea a la vez):

```
   MOR-218  Educación Inicial no califica: DESCRIBE  ← otra pantalla entera
   MOR-213  los tres equipos administrativos (directivo, pedagógico, admin.)
   MOR-217  un profesor coordinador por área de aprendizaje del grado
   MOR-214  poder borrar grados y áreas   ← lleva una pregunta para Daniel
   MOR-215  registrarse eligiendo el colegio de una lista, no escribiéndolo
```

**Y dos que quedaron a medias, cada una esperando UNA decisión de Daniel:**

```
   MOR-212  el vocabulario del MPPE ya está desplegado (Vocabulario);
            faltan las DOS ETAPAS de primaria — hoy viven solo en los
            seeds. ¿Dato del grado, derivado del orden (1-3 / 4-6), o
            solo una agrupación de la boleta?
   MOR-216  el informe descriptivo está escrito y desplegado; falta
            confirmar que es por LAPSO y que lo escribe el GUÍA
```

0. ~~**`MOR-146` · Limpiar los datos de demo de producción**~~ → hecho el 5 de
   septiembre. Queda abierta la otra mitad: las cuentas de administrador con
   contraseña conocida.
1. **`MOR-148` · Wizard de alta de un colegio nuevo.** Hoy un colegio recién creado nace sin
   año escolar, sin grados y sin secciones, y el importador es el que se lo encuentra. La
   salida de emergencia ya está puesta —crear el año escolar y las secciones **desde la
   previsualización**, donde el problema se ve— pero el alta guiada es otra cosa.
2. **El repaso de estilo que quedó postergado.** `shared/_errors` sale como un titular serif
   gigante con lenguaje de programador. Daniel lo dejó explícitamente para después de lo
   funcional.
3. **`MOR-145` · Rebotes de correo.** Hoy un correo que rebota se queda ahí y solo se entera
   alguien si el usuario lo reporta.
4. **`MOR-92`** — el acceso amplio del equipo de SIGA, la decisión con fecha de vencimiento.
   Se retoma cuando haya colegios pagando.

**Cómo se entrega, desde ahora** (convención escrita en el documento *Cómo trabajamos* de Linear):
cada issue cerrado deja **transferencia de aprendizaje** (qué salió distinto, qué falló y cómo se
descubrió, qué no hacer la próxima vez), **material visual** siempre que se pueda —diagramas ASCII,
tablas, antes/después— y una **guía de QA** con datos sembrados que cubran el caso que el issue
resuelve **y** el que rechaza. Nada se da por terminado sin poder verlo funcionando en la app.

**Riesgo abierto que no está en ningún issue:** no hay estimaciones, ni fechas, ni cycles, ni
horas/semana asignadas a SIGA. Con alcance fijo y tiempo indefinido, "Cimientos primero" no es una
decisión evaluable. Pendiente de resolver más adelante, por decisión explícita.

**Datos de trabajo:** base `siga_development` creada y con seeds cargados. Server: `bin/rails server`.

---

> Este archivo es **volátil por diseño**: es el estado de avance, no guía permanente.
> Vive fuera de `CLAUDE.md` porque esa sección se reescribe cada sesión — adentro viajaba
> en cada petición al modelo y además invalidaba el caché del prompt en cada edición.
> La guía permanente (stack, comandos, convenciones, estado conocido) sigue en `CLAUDE.md`.
