# Los horarios de clase

> **Estado:** **congelado** el 13 de octubre de 2026 · en construcción: tanda 1
> **PR:** — (rama `docs/spec-horarios`; el issue de Linear está sin crear: el conector no estaba autenticado)

Las 18 decisiones están tomadas (§ 3): las 11 a 18 las propuso Claude y las
confirmó Daniel el mismo 13 de octubre. Con todas contestadas dio la orden de
seguir —*«Continúa»*—, y desde ahí está congelado: si algo cambia, se cambia
aquí primero.

---

## 1 · El problema

SIGA sabe QUIÉN dicta QUÉ —`teacher_sections`: sección · área · profesor— y no
sabe CUÁNDO. Daniel, 8 de octubre de 2026:

> *«Es algo que no hemos tocado para nada y creo que siempre puede representar
> un dolor de cabeza para los administradores y directivos.»*

Y el 13, al pedirlo:

> *«Que la administración pueda gestionar los horarios de las secciones en un
> año determinado sin solapamientos entre clases y profesores. Es decir, que 2
> profes no se encuentren en la misma sección para dar su clase, ni que un profe
> dicte 2 clases en el mismo momento.»*

```
   ✗  una SECCIÓN con dos clases a la misma hora     dos profesores en 1er Año A el lunes a las 7:10
   ✗  un PROFESOR en dos sitios a la misma hora      García en 1er Año A y en 2do Año B a la vez
```

En Media un profesor dicta en varias secciones y una sección tiene diez o doce
profesores: armado a mano, en papel o en Excel, el choque aparece en septiembre
con el colegio ya andando.

Y hay una segunda mitad:

> *«Al final el horario deben verlo todos los usuarios: directivos (por sección,
> por área, por detalle del profe o del alumno, etc.); al final es la misma
> estructura dependiendo de por dónde se quiere ver.»*

```
   LA DIRECCIÓN     por sección · por profesor · por área · por alumno
   EL PROFESOR      el suyo
   LA FAMILIA       el de la sección de su hijo
   EL ALUMNO        el de su sección
```

## 2 · Qué NO entra

```
   ENTRA                                  NO ENTRA (y por qué)
   ─────                                  ────────────────────
   turnos y horas del timbre              juntar dos secciones con un profesor, partir una
   carga horaria por área y grado           sección en dos grupos, GCRP mezclando secciones:
   armar sin choques, en tres capas         «es algo excepcional o particular» (Daniel)
   las miradas, y publicar                aulas y laboratorios como recurso que choca
   «Ahora · Después», portales, PDF       suplencias y cambios por fecha: el horario es UNA
   disponibilidad del profesor              semana que se repite
   diagnóstico, mover, intercambiar       semanas A/B y sábados
   copiar al año siguiente, Excel         versiones con vigencia: publicar es un interruptor
   el automático (con spec propio)        el horario de un profesor entre DOS colegios de SIGA
                                            (son dos filas detrás del RLS: lo cubre «no disponible»)
                                          pasar lista por clase: la asistencia sigue siendo diaria
                                          iCal y notificaciones
                                          cambiar `config.time_zone` de la app
```

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Hay clases que rompan «una sección, un profesor, una hora»? | **No.** Juntar o partir secciones es excepcional y queda fuera. | Daniel, 13 oct |
| 2 | ¿Cuándo entra el armado automático? | **Después** del armador a mano, con su propio spec (tanda 5). | Daniel, 13 oct |
| 3 | ¿Dónde cae en la frontera de lo gratis? | **Armar es gratis** (es cargar). El PDF y los portales de la familia y del alumno piden suscripción. El profesor ve el suyo en su inicio, que ya es entrada. | Daniel, 13 oct |
| 4 | ¿Qué patrón de timbre se propone? | El de la foto de Daniel: horas de 40 minutos de dos en dos, un receso, turno de mañana (§ 4). | Daniel, 13 oct |
| 5 | ¿Los días se agrupan («lunes y miércoles a las 7») o es día-hora? | **Día-hora.** Cada casilla es independiente; la semana se repite. | Investigación |
| 6 | ¿El choque se mide por número de hora o por reloj? | **Por reloj.** La hora se guarda en minutos desde la medianoche. | Investigación |
| 7 | ¿De qué cuelga una clase? | De **sección + área**. El profesor sale de la asignación. | Investigación |
| 8 | ¿Qué pasa si el profesor nuevo choca? | **La asignación se guarda siempre.** Lo que choca vuelve a «por ubicar» y se avisa. | Investigación |
| 9 | ¿De dónde sale la carga horaria? | Del plan oficial de 2017, propuesto por NOMBRE del área; el colegio la corrige. | Investigación |
| 10 | ¿Con qué se arma el automático? | En Ruby. La gema `or-tools` no trae binario para la imagen de producción. | Investigación |
| 11 | ¿Cómo se llama el timbre? | **«Turno»** («Media · mañana»): es la palabra de la resolución y del colegio. | Claude · confirmó Daniel, 13 oct |
| 12 | ¿La familia en mora ve el horario? | **Sí.** Es logística de la sección —está pegado en la puerta del salón—, no el expediente del hijo; esconderlo no presiona el pago y hace que el muchacho falte. | Claude · confirmó Daniel, 13 oct |
| 13 | ¿Se publica? | **«Borrador → Publicado», por sección.** Profesor, familia y alumno ven solo lo publicado; quien administra, todo. | Claude · confirmó Daniel, 13 oct |
| 14 | ¿Solo Media? | Sirve para toda sección con áreas —Primaria también, por los especialistas—; Inicial no. Se entrega pensado y sembrado para Media. | Claude · confirmó Daniel, 13 oct |
| 15 | ¿Sábados? | Lunes a viernes. El sábado, cuando un colegio lo pida. | Claude · confirmó Daniel, 13 oct |
| 16 | ¿Qué se bloquea? | Una sección con clases no cambia de turno sin vaciarse. Un año finalizado queda en solo lectura. | Claude · confirmó Daniel, 13 oct |
| 17 | ¿El automático es gratis? | No: es procesamiento. Se ve y no se toca sin suscripción. | Claude · confirmó Daniel, 13 oct |
| 18 | ¿Quién arma y quién publica? | Quien hoy administra secciones (`manage_sections`: dirección, coordinación y secretaría). El profesor mira. | Claude · confirmó Daniel, 13 oct |

## 4 · El dominio

### La norma

- **Resolución DM-029/2022** (Gaceta 42.505, 15 de noviembre de 2022): en Media
  los horarios *«se organizan en bloques de 80 minutos»*, de lunes a viernes y
  *«sin día libre»*. Vale para planteles públicos y privados.
- **Resolución DM/0033 de 2017** (Gaceta 41.221): el plan de estudio de Media
  General, con las horas semanales de cada área de formación.

```
   horas a la semana                        1°   2°   3°   4°   5°
   Castellano                                4    4    4    4    4
   Inglés y otras lenguas extranjeras        6    6    6    6    4
   Matemática                                4    4    4    4    4
   Educación Física                          6    6    6    6    6
   Arte y Patrimonio                         4    4    ·    ·    ·
   Ciencias Naturales                        6    6    ·    ·    ·
   Física                                    ·    ·    4    4    4
   Química                                   ·    ·    4    4    4
   Biología                                  ·    ·    4    4    4
   Ciencias de la Tierra                     ·    ·    ·    ·    2
   Geografía, Historia y Ciudadanía          6    6    6    4    4
   Formación para la Soberanía Nacional      ·    ·    ·    2    2
   Orientación y Convivencia                 2    2    2    2    2
   Grupos de Creación, Recreación y Prod.    6    6    6    6    6
                                            ──   ──   ──   ──   ──
                                            44   44   46   46   46
```

### El horario real que mandó Daniel

`IMG_3975`, el cuaderno de un alumno de 1er o 2do Año de un colegio privado:

```
   Hora            Lunes          Martes         Miércoles     Jueves            Viernes
   7:10 – 7:50     CASTELLANO     MATEMÁTICA     GHC           CIENCIAS          EDUC. FÍSICA
   7:50 – 8:30                                                 NATURALES
   8:30 – 9:10     MATEMÁTICAS    INFORMÁTICA    CASTELLANO    GHC               ARTE Y
   9:10 – 9:50                                                                   PATRIMONIO
   9:50 – 10:20    R              E              C             E                 S O
   10:20 – 11:00   EDUC. FÍSICA   CIENCIAS       INGLÉS        INGLÉS            DIBUJO
   11:00 – 11:40                  NATURALES
   11:40 – 12:20   ARTE Y         DIBUJO         ORIENTACIÓN   TÉCNICAS          Salida
   12:20 – 1:00    PATRIMONIO                                  DE ESTUDIO
```

```
   horas de 40 minutos, de dos en dos       = el «bloque de 80» de la resolución
   8 horas al día, receso de 30 minutos     = 40 horas de clase a la semana
   19 bloques ocupados                      = 38 horas; el viernes sale antes
   cada casilla lleva el ÁREA               día × hora, sin agrupar días
   Informática, Dibujo, Técnicas de estudio las pone el colegio
```

### Lo que parece razonable y está mal

- ⚠️ **«El horario son los días de un área.»** No: «Matemática lunes y
  martes» son dos casillas. Agrupar días es el modelo de la universidad, y con
  él no se puede decir que el lunes va a las 8:30 y el martes a las 7:10 —que es
  exactamente lo que dice la foto—.
- ⚠️ **«La 3ra hora es la 3ra hora.»** Primaria y Media no comparten timbre, y en
  la muestra **11 de los 18 profesores de Media también dictan en Primaria**.
  Comparar números de hora deja pasar ese choque; hay que comparar el reloj. Es
  donde tropiezan aSc y Untis, los dos sistemas más usados del mundo.
- ⚠️ **«La carga oficial es la del colegio.»** El plan pide 44 a 46 horas y una
  semana de turno de mañana tiene 40: el colegio de la foto dicta 38. La carga
  oficial es un punto de partida —como `MateriaOficial`— y que no cierre es un
  AVISO, nunca un error.
- ⚠️ **«Si el profesor nuevo choca, no se le asigna.»** Quién dicta es un hecho;
  el horario es un plan. Un plan no puede tener de rehén a un hecho.
- ⚠️ **GCRP no es un caso especial.** Es una de las 14 áreas del plan (en SIGA,
  `PGC`). Que en algunos liceos mezcle secciones es de esos liceos; aquí es un
  área más de la sección (decisión 1).

### Lo que hacen los mejores, y lo que se copia

```
   LO QUE HACEN                                    QUIÉN                 AQUÍ
   el choque es IMPOSIBLE, no un aviso             aSc · Untis           tres capas (tanda 2)
   tarjetas «por ubicar» + casillas válidas        aSc · Untis · Prime   el armador (tanda 2)
   una fuente, muchas vistas, y el teléfono        WebUntis · EduPage    tanda 3
   borrador → publicado                            GHC · OpenEduCat      tanda 3
   disponibilidad del profesor por horas           aSc · GHC · Prime     tanda 4
   diagnóstico ANTES de armar                      aSc · Untis · GHC     tanda 4
   respetar lo puesto y «completar lo que falta»   aSc · Untis · FET     tanda 5
```

Las tres quejas que se repiten en las reseñas: el botón automático que falla sin
decir por qué, la herramienta de experto con cien opciones, y la casilla
prohibida que no explica el motivo. De ahí sale lo que distingue a esta: **toda
casilla que no se puede usar dice por qué**.

### Lo que la investigación NO pudo confirmar

- Cuánto dura la hora académica según la DM-029: la prensa dice 35 minutos y
  otro resumen 45; la foto dice 40. No importa: la duración la escribe el colegio.
- La tabla del plan se leyó en Pandectas Digital y en La Nación, no en el PDF de
  la Gaceta 41.221.
- La carga de Media Técnica (el 6to Año): la escribe el colegio, como sus áreas.
- La foto es de UN colegio. Daniel: *«creo que todos siguen ese patrón»*.

## 5 · Cómo se ve

### El recorrido

```
   ① TURNO            ② CARGA HORARIA       ③ ARMAR              ④ PUBLICAR          ⑤ VERLO
   a qué hora suena   cuántas horas a la    área por área,       cuando está listo   cada quien por
   el timbre          semana tiene cada     casilla por casilla                      su puerta
                      área
   una vez al año     una vez (se hereda)   por sección          por sección         siempre
   └──────────── GRATIS (es cargar) ────────────────────┘        └── PDF y portales: con suscripción ──┘
```

### ① El turno — tanda 1

```
   Académico ▸ Horarios        [ Horarios | Turnos | Carga horaria ]
   Turnos ▸ Registrar turno
   ┌────────────────────────────────────────────────────────────────────┐
   │ Nombre         [ Media · mañana          ]                         │
   │ Entrada        [ 7:10 ]        Cada hora dura   [ 40 ] min         │
   │ Horas al día   [ 8 ]           Receso de [ 30 ] min tras la [ 4ta ▾]│
   │                                                                    │
   │ Así queda                                                          │
   │   1ra  7:10 – 7:50          5ta  10:20 – 11:00                     │
   │   2da  7:50 – 8:30          6ta  11:00 – 11:40                     │
   │   3ra  8:30 – 9:10          7ma  11:40 – 12:20                     │
   │   4ta  9:10 – 9:50          8va  12:20 –  1:00                     │
   │   ── Receso  9:50 – 10:20 ──                                       │
   │                                                        [Crear]     │
   └────────────────────────────────────────────────────────────────────┘
   Después cada hora se corrige en su fila: otro receso, una hora más corta.
   Un colegio con Primaria o con turno de tarde registra otro turno.

   Y cada sección dice cuál usa:   1er Año A   Turno [ Media · mañana ▾ ]
```

### ② La carga horaria — tanda 1

```
   Carga horaria                                     [Proponer las del plan oficial]
   horas a la semana       1er Año  2do Año  3er Año  4to Año  5to Año
   Castellano               [ 4 ]    [ 4 ]    [ 4 ]    [ 4 ]    [ 4 ]
   Matemáticas              [ 4 ]    [ 4 ]    [ 4 ]    [ 4 ]    [ 4 ]
   Inglés                   [ 6 ]    [ 6 ]    [ 6 ]    [ 6 ]    [ 4 ]
   Ciencias Naturales       [ 6 ]    [ 6 ]      ·        ·        ·
   Física                     ·        ·      [ 4 ]    [ 4 ]    [ 4 ]
   Informática              [   ]    [   ]    [   ]    [   ]    [   ]   ← del colegio: la escribe
   …
   ───────────────────────────────────────────────────────────────────
   Total                      44       44       46       46       46
   La semana tiene            40       40       40       40       40
                              ⚠ sobran 4 horas: no caben en «Media · mañana»
```

El punto dice «esa área no se cursa en ese grado». El aviso es ámbar —un dato
que pide atención— y no bloquea nada.

### ③ Armar — tanda 2

```
   1er Año · Sección A
   Asistencia │ Calificar │ Plan de Evaluación │ Informes │ Alumnos │ Áreas y profesores │ Horario
   ─────────────────────────────────────────────────────────────────────────────────────────────
   Turno  Media · mañana            26 de 38 horas ubicadas   «Borrador»          [⤓ Descargar]

   POR UBICAR   toque un área y después la casilla
   (•) MAT García 2 de 4   ( ) CAS Rojas 2 de 4   ( ) ING López 0 de 4   ( ) TEC Díaz 0 de 2   ( ) ORI sin profesor 0 de 2
   [✓] Ubicar en bloque de 2 horas

   ▸ García está en 2do Año B el miércoles a esa hora                    ← el porqué, en letras

                 Lunes        Martes       Miércoles    Jueves       Viernes
   7:10–7:50     CAS          [   +   ]    GHC          CN           EF
   7:50–8:30     Rojas   ×    [   +   ]    Herrera ×    Castillo ×   Moreno ×
   8:30–9:10     MAT          INF          ░░░░░░░░░    GHC          ART
   9:10–9:50     García  ×    Díaz    ×    ░░░░░░░░░    Herrera ×    Suárez ×
   9:50–10:20    ───────────────────── R E C E S O ─────────────────────
   10:20–11:00   EF           CN           [   +   ]    [   +   ]    DIB
   11:00–11:40   Moreno  ×    Castillo ×   [   +   ]    [   +   ]    Rojas  ×
   11:40–12:20   ART          DIB          [   +   ]    [   +   ]    [   +   ]
   12:20–1:00    Suárez  ×    Rojas   ×    [   +   ]    [   +   ]    [   +   ]

   [ + ] libre para Matemáticas     ░░░ no se puede: García está ocupado     × quitar
```

- Elegida el área, la rejilla se reparte en **libre** y **no se puede**. Tocar
  una casilla tramada escribe el motivo arriba: el tooltip solo no alcanza,
  porque en el teléfono tocar no lo dispara.
- Tocar una libre **guarda en el momento** y el contador pasa a «4 de 4».
- La trama es neutra, sin rojo ni ámbar: el rojo sigue siendo del aplazado.
- En la casilla manda el CÓDIGO del área; el color acompaña y no reemplaza (son
  8 tonos para 14 áreas).
- Sin arrastrar: tocar y tocar sirve con el dedo y con el teclado. Mover e
  intercambiar llegan en la tanda 4.

### Cuando cambia el profesor — tanda 2

```
   García deja Matemáticas de 1er Año A  ──►  sus 4 horas siguen en el horario, «sin profesor»
   Se asigna a Pérez                     ──►  donde Pérez está libre:  toma la clase
                                              donde Pérez ya dicta:    la clase vuelve a «por ubicar»
                                              y el aviso dice cuáles:  «miércoles 8:30 — Pérez está en 3er Año A»
```

### ④–⑤ Las miradas — tanda 3

```
   Académico ▸ Horarios
   Ver por  [Secciones]  Profesores  Áreas       Día  [Lun] Mar Mié Jue Vie · Semana      Turno [Media · mañana ▾]

   LUNES           7:10   7:50   8:30   9:10  ┊  10:20  11:00  11:40  12:20
   1er Año A       CAS    CAS    MAT    MAT   ┊  EF     EF     ART    ART       publicado
   1er Año B       MAT    MAT    CAS    CAS   ┊  ING    ING     ·      ·        borrador · faltan 6
   2do Año A       GHC    GHC    ING    ING   ┊  MAT    MAT    CN     CN        publicado
   …                                                            · = falta ubicar
   cada casilla abre el horario de esa sección          [Publicar los 6 completos]
```

```
   Ver por Profesores (el mismo lunes)
   García, Carlos     1B     1B     1A     1A   ┊  2A     2A     –      –        20 h
   Herrera, José      2A     2A     –      –    ┊  –      –      3A     3A       32 h
   Moreno, Sofía      –      –      –      –    ┊  1A     1A     –      –        12 h
                                    – = libre: aquí se ven los huecos
```

```
   Tocando una fila: la semana de UNO (sección, profesor, área o alumno)
   Horario de García, Carlos · 20 horas                             [⤓ Descargar]
                 Lunes       Martes      Miércoles   Jueves      Viernes
   7:10–8:30     1er Año B   1er Año A               3er Año A
                 MAT         MAT                     MAT
   8:30–9:50     1er Año A               2do Año B   …
                 MAT                     MAT
```

«Por alumno» es el horario de su sección, con enlace desde su ficha.

```
   EL PROFESOR, en su inicio
   ┌ Ahora ─────────────────────────────┐  ┌ Después ───────────────────────┐
   │ 1er Año A · Matemáticas            │  │ 10:20   2do Año A · Matemáticas │
   │ hasta las 9:50        [Calificar]  │  │                                 │
   └────────────────────────────────────┘  └─────────────────────────────────┘
   Mi semana   (la rejilla de arriba, con sus secciones)
```

```
   LA FAMILIA Y EL ALUMNO, en el teléfono: abre en HOY
   ┌─────────────────────────────┐
   │ Valentina · 1er Año A       │
   │ Lun [Mar] Mié Jue Vie       │
   │ ─────────────────────────── │
   │  7:10  Matemáticas          │
   │        Prof. García         │
   │  8:30  Informática          │
   │        Prof. Díaz           │
   │  9:50  Receso               │
   │ 10:20  Ciencias Naturales ◄ │  ← ahora
   │        Prof. Castillo       │
   │ 11:40  Dibujo               │
   │        sale a la 1:00       │
   └─────────────────────────────┘
```

El PDF —de una sección o de un profesor— es una hoja apaisada con el membrete
del colegio.

### La vida real — tanda 4

```
   Profesores ▸ Herrera, José ▸ Disponibilidad          Horarios ▸ Diagnóstico
              Lun  Mar  Mié  Jue  Vie                   ✗ Herrera: 44 horas y su semana tiene 32 → no cabe
   7:10        ✓    ✓   ░░    ✓    ✓                    ⚠ 4to Año A: Biología no tiene profesor
   8:30        ✓    ✓   ░░    ✓    ✓                    ⚠ 1er Año B: faltan 6 horas por ubicar
              ░░ no está: dicta en otro colegio         cada renglón lleva a donde se arregla
```

### El automático — tanda 5, con su propio spec

```
   [Completar lo que falta] ──► «Ubicaría 212 de 216 horas. Estas 4 no caben porque…» ──► [Confirmar]
   respeta lo ya puesto · nada se escribe sin confirmar · con suscripción
```

## 6 · Criterios de aceptación

### Tanda 1 · Turno y carga

- [ ] Dado un colegio sin turnos, cuando se registra «Media · mañana» con
      entrada 7:10, horas de 40 minutos, 8 horas y un receso de 30 minutos tras
      la 4ta, entonces quedan las nueve filas de la foto, de 7:10 a 1:00, con el
      receso de 9:50 a 10:20.
- [ ] Dos horas de un mismo turno no se pisan: ni por el formulario ni
      saltándose la validación (lo rechaza la base).
- [ ] Una hora se corrige en su fila. El receso no cuenta como hora de clase.
- [ ] Un turno es del año escolar de la sesión, y el de otro colegio da 404.
- [ ] Una sección elige su turno entre los de su año. Sin turno, su pestaña lo
      dice —«Elija el turno de esta sección»— en vez de dibujar una rejilla vacía.
- [ ] «Carga horaria» muestra una fila por área y una columna por grado de los
      que el colegio dicta, con un punto donde el área no se cursa.
- [ ] «Proponer las del plan oficial» llena SOLO las casillas vacías de las
      áreas que reconoce por su nombre, no pisa lo escrito, y dice cuántas
      propuso y cuáles no reconoció.
- [ ] El total de un grado se compara con las horas de clase a la semana del
      turno de sus secciones (si difieren, el más corto). Si sobra, avisa y no
      bloquea.
- [ ] Un colegio en gratis puede hacer todo lo anterior.
- [ ] Un profesor no entra a «Turnos» ni a «Carga horaria».

### Tanda 2 · Armar

- [ ] La pestaña «Horario» es la última de la sección, para quien administra
      secciones y para sus profesores (que la ven sin botones). Una sección de
      Inicial no la tiene.
- [ ] Dado «Matemáticas 0 de 4», al tocar el área y una casilla libre con
      «bloque de 2 horas», quedan dos clases seguidas y el contador dice «2 de 4».
- [ ] Un bloque no cruza el receso ni el final del día: ahí se ubica una sola hora.
- [ ] Una sección no puede tener dos clases a la misma hora: la casilla ocupada
      no se ofrece, y saltándose la validación lo rechaza la base.
- [ ] Un profesor no puede estar en dos secciones a la misma hora: la casilla
      sale tramada, al tocarla dice «García está en 2do Año B a esa hora», y
      saltándose la validación lo rechaza la base.
- [ ] El choque se mide por reloj: para un mismo profesor, una clase de 8:30 a
      9:10 en un turno choca con una de 8:45 a 9:30 en otro.
- [ ] Dos horas contiguas no chocan (7:10–7:50 y 7:50–8:30).
- [ ] Un área sin profesor se puede ubicar: su casilla dice «sin profesor» y no
      choca con nadie.
- [ ] Dos guardados a la vez sobre la misma casilla: uno entra y el otro lee
      «Esa casilla ya está ocupada», sin error 500.
- [ ] Quitar una clase la devuelve a «por ubicar».
- [ ] Al borrar la asignación de un profesor, sus clases siguen en el horario
      «sin profesor» — también cuando se borra con `delete_all`.
- [ ] Al asignar un profesor: toma las clases donde está libre; donde choca, la
      clase vuelve a «por ubicar» y el aviso nombra el día, la hora y dónde
      está. La asignación se guarda siempre.
- [ ] Corregir una hora del turno mueve los minutos de sus clases. Si el cambio
      haría chocar a un profesor con otro turno, no se guarda y dice con quién.
- [ ] Una sección con clases no cambia de turno: el aviso pide vaciar el horario.
- [ ] Borrar una sección se lleva sus clases. Una hora con clases no se borra,
      y el aviso dice cuántas tiene.
- [ ] Otro colegio no ve ni toca nada (404), y las tablas nuevas tienen RLS con
      `FORCE`.
- [ ] En gratis se arma. Con la suscripción vencida se ve y no se escribe.
- [ ] En un año finalizado el horario se ve y no se edita.
- [ ] La muestra amanece con las ocho secciones de Media del año en curso
      armadas con el turno de la foto: al menos el 90 % de sus horas ubicadas, y
      una sección con horas «por ubicar» a propósito.

### Tanda 3 · Verlo

- [ ] «Horarios» muestra por secciones, por profesores o por áreas; un día o la
      semana; de un turno. Cada casilla lleva a la semana de su fila.
- [ ] La semana de una sección, de un profesor, de un área y de un alumno salen
      de la misma tabla y dicen lo mismo.
- [ ] Una sección publicada la ven su profesor, la familia y el alumno. En
      borrador, solo quien administra. «Publicar los completos» publica las que
      no tienen horas por ubicar.
- [ ] El profesor ve «Ahora» y «Después» con la hora de Venezuela: a las 8:00 de
      la noche de Caracas sigue siendo hoy.
- [ ] El representante ve el horario de cada hijo, y abre en el día de hoy; el
      fin de semana, en el lunes.
- [ ] El alumno ve el de su sección.
- [ ] Una familia en mora ve el horario (decisión 12).
- [ ] En gratis los portales siguen cerrados y el PDF pide suscripción. Vencido,
      se ve y se descarga, y no se edita.
- [ ] El PDF de una sección y el de un profesor caben en una hoja apaisada y
      dicen el colegio, el año, el turno y cada clase — leídos, no pesados.
- [ ] A 380 px de ancho nada se corre de lado.

### Tanda 4 · La vida real

- [ ] Quien administra marca las horas en que un profesor no está. Esas casillas
      salen tramadas con «Herrera no está disponible a esa hora» y no se ubican.
- [ ] Marcar «no disponible» sobre una hora que el profesor ya dicta no borra la
      clase: la señala en el diagnóstico.
- [ ] El diagnóstico lista las áreas sin carga, las áreas sin profesor, el
      profesor con más horas que horas disponibles, la sección con más horas que
      su turno y las secciones con horas por ubicar. Cada renglón lleva a donde
      se arregla.
- [ ] Mover una clase a otra casilla e intercambiar dos de la misma sección
      pasan por las mismas tres capas.
- [ ] Copiar la estructura al año siguiente trae los turnos, sus horas, el turno
      de cada sección y las clases. Una clase que no se puede copiar es un
      aviso, no un error.
- [ ] El Excel trae una hoja por sección.

### Tanda 5 · El automático

Su contrato, que el spec propio no puede aflojar: respeta lo ya ubicado, da el
mismo resultado con los mismos datos, previsualiza cuántas horas ubicaría y por
qué no caben las demás, no escribe nada sin confirmar, y pide suscripción.

## 7 · Lo que se puede romper

- **Una restricción violada aborta la petición entera.** En SIGA la petición es
  UNA transacción: cada escritura que pueda chocar va en su `SAVEPOINT`
  (`transaction(requires_new: true)`) y rescata `ActiveRecord::ExclusionViolation`.
  Es la lección del doble clic de «pagar sin consola».
- **Un test con un `EXCLUDE` violado y sin `SAVEPOINT`** aborta la transacción
  del test, y el error aparece en el SIGUIENTE.
- **Cambiar el timbre hora por hora** daría un choque falso entre la 1ra y la
  2da mientras se corre: las restricciones son diferibles, y se difieren y se
  vuelven a exigir DENTRO del `SAVEPOINT`. Sin lo segundo, el error saltaría al
  cerrar la petición, fuera del `rescue`.
- **`pestanas_de_la_seccion_test` y `areas_y_profesores_test`** afirman la lista
  exacta de pestañas: cambian a propósito.
- **`menu_del_profesor_test`** exige que el menú del profesor sea `["Dicto"]`:
  «Ahora · Después» va en su inicio, no en un grupo nuevo.
- **`frontera_de_lo_gratis_test`**: cada controlador nuevo, en una lista.
- **`aislamiento_estructural_test`**: las tablas nuevas, con `SchoolScoped`, RLS,
  `FORCE` y su política.
- **`erd_del_modelo_test`** (`ORDEN` en `lib/tasks/modelo.rake`) y
  **`lo_que_impide_borrar_test`** (los nombres en `es.yml`).
- **`lib/tasks/prueba.rake`** borra con una lista escrita a mano: le faltarían
  las tablas nuevas. `OrdenDeBorrado` sí se calcula solo.
- **La hora.** La app corre en UTC: desde las 8 de la noche «hoy» ya es mañana.
  «Ahora», «Después» y «hoy» salen de `HoraDeVenezuela`, no de `Date.current`.
- **El color.** Un choque en rojo rompe `regla_de_color_test`, y con razón.
- **Los códigos no coinciden.** La siembra usa `LEN`, `EDF`, `CNA`; el plan,
  `CAS`, `EF`, `CN`. Proponer la carga por código dejaría en blanco medio
  colegio: se empareja por nombre, como `Subject.area_del_31059`.
- **La siembra.** Los profesores sembrados tienen más horas que la semana
  —Herrera dicta dos áreas en siete secciones—: la muestra lleva una carga
  propia que quepa en 40, o amanecería con medio horario sin ubicar.
- **La muestra se resiembra en UNA transacción**: el horario no puede depender
  de un `after_commit`.
- **El año y el nivel de la sesión.** Con «Todos los años» se cae en
  `anio_de_trabajo`. «Turnos» declara `el_nivel_no_aplica`.
- **El importador de pensum.** Si reasigna y desubica clases, lo dice en su
  reporte.
- **La carga no tiene año.** `weekly_hours` es del pensum: cambiarla en 2027
  mueve el «faltan» de 2026. Se acepta: es un aviso de planificación.
- **Los tests y otra sesión.** Este trabajo vive en un worktree, y `siga_test` es
  UNA base, con el nombre fijo en `config/database.yml`: dos `bin/ci` a la vez
  se pisan. `SIGA_DB_NAME` separa la base de desarrollo —la siembra, el
  servidor—, no la de los tests. O no se corren a la vez, o la tanda 1 le da
  nombre por variable también a esa.

## 8 · Cómo se verifica

- `bin/ci` en verde antes de cada PR, y `bin/smoke` pasando por las rutas nuevas
  con los cuatro roles.
- **La base, sola**: tests que guardan saltándose la validación
  (`save(validate: false)`, en su `SAVEPOINT`) y esperan el rechazo.
- **Las cascadas**: borrar la asignación, corregir una hora, borrar la sección.
- **De sistema**: tocar área y casilla, leer el motivo de una tramada, a 380 px.
- **El PDF**, leído con `LeePdf`.
- **Daniel, en la muestra**, al cierre de cada tanda:

```
   tanda 1   director      Turnos (el de la foto) · Carga horaria («no cabe»)
   tanda 2   director      1er Año B ▸ Horario: ubicar lo que falta, tocar una tramada
                           Áreas y profesores: cambiar a un profesor y leer el aviso
   tanda 3   director      Horarios por secciones, por profesores y por áreas · publicar
             profesor      García: «Ahora · Después» y «Mi semana»
             representante Valentina, en el teléfono
```

---

## 9 · Cómo está hecho

### Los nombres

```
   SE LEE                    EN EL CÓDIGO                          URL
   Turno                     BellSchedule · bell_schedules         /turnos
   hora (1ra, 2da… Receso)   TimeSlot · time_slots                 /turnos/:id/horas
   clase                     Lesson · lessons                      /secciones/:id/clases
   carga horaria             grade_subjects.weekly_hours           /carga-horaria
   el turno de la sección    sections.bell_schedule_id
   publicado                 sections.timetable_published_at       (tanda 3)
   no disponible             TeacherUnavailability                 (tanda 4)
```

Servicios, en español: `HorasDelTurno` (genera el timbre), `CargaHorariaOficial`,
`ChoquesDeHorario` (el motivo, en UN sitio), `HorarioDeLaSeccion`,
`RejillaDeHorarios`, `ArmarElHorario`, `DiagnosticoDelHorario`,
`HoraDeVenezuela`, `HorarioPdf`, `HorariosXlsx`.

### Una clase es una casilla

`lessons`: sección · área · día (1 a 5) · hora. Un bloque de 80 minutos son dos
clases seguidas, que se dibujan unidas. Una hora es una hora académica: no hay
horas «que valen dos».

### Las tres capas

```
   1 · LA PANTALLA   la casilla ocupada no se ofrece, y dice por qué
   2 · EL MODELO     valida antes de guardar, con el MISMO texto (`ChoquesDeHorario`)
   3 · LA BASE       aunque dos personas guarden a la vez, PostgreSQL rechaza la segunda
```

```sql
-- una sección, una clase a la vez
EXCLUDE USING gist (section_id WITH =, day WITH =,
                    int4range(starts_min, ends_min) WITH &&)
-- un profesor, un sitio a la vez
EXCLUDE USING gist (teacher_id WITH =, academic_period_id WITH =, day WITH =,
                    int4range(starts_min, ends_min) WITH &&)
```

El rango es `[inicio, fin)`, en minutos desde la medianoche y en hora del
colegio: sin columnas de hora ni zona horaria que convertir. Dos clases sin
profesor no chocan (`NULL = NULL` no es verdadero).

### La base copia sola

Una restricción solo mira columnas de su propia fila, así que la clase guarda
tres datos que son de otra tabla. Los mantiene PostgreSQL, con llaves
compuestas, y no el código:

```
   (section_id, academic_period_id)       → sections          borrar la sección se lleva sus clases
   (time_slot_id, starts_min, ends_min)   → time_slots        corregir la hora mueve los minutos
   (section_id, subject_id, teacher_id)   → teacher_sections  borrar la asignación deja «sin profesor»
                                                              (`ON DELETE SET NULL (teacher_id)`)
```

Hay seis sitios que crean o borran asignaciones —la pantalla, `CargaDePensum`,
`CopiarLaEstructura`, dos siembras y `prueba.rake`, que usa `delete_all`—: con
callbacks, alguno se quedaría atrás. Lo único que va en el modelo es
`TeacherSection#after_create`, que le lleva el profesor nuevo al horario.

⚠️ **Este SQL no se ha corrido.** La llave con `SET NULL (columna)` y el
`EXCLUDE` diferible se prueban en la primera migración de la tanda 2. Si la
llave diera problemas, el plan B es un disparador.

### Producción, mirada el 13 de octubre de 2026 (solo lectura)

```
                         siga-db            siga-demo-db
   PostgreSQL            18.4               18.4            (local y CI: 17)
   dueño de la base      siga_app           siga_app
   puede crear en ella   sí                 sí
   btree_gist            1.8, sin instalar  1.8, sin instalar
```

`btree_gist` es una extensión de confianza: la crea `siga_app` desde la
migración, sin superusuario y sin paso a mano. `SET NULL (columna)` pide
PostgreSQL 15 o más: se cumple en los tres sitios.

### La suscripción

```
   LA_ENTRADA             bell_schedules · time_slots · carga_horaria · lessons · horarios
                          (el PDF y el Excel piden suscripción solos: son archivos)
   ya estaban ahí         sections · grade_subjects · dashboards/profesor
   SOLO_CON_SUSCRIPCION   representante · dashboards/estudiante   (ya estaban)
   CON_SUSCRIPCION        el automático (tanda 5)
```

### El armador, sin librerías

Un solo formulario: cada área «por ubicar» es un `radio`, cada casilla libre un
botón, y la respuesta reemplaza el armador entero —son 40 casillas, y el estado
sale siempre del servidor—. Sin JavaScript ya funciona. `horario_controller.js`
(unas 40 líneas) solo pinta, al cambiar de área, qué casillas quedan libres, y
escribe el motivo de una tramada en una línea con `role="status"`. Todo lo que
bloquea a un área se calcula en UNA consulta por rejilla.

## 10 · Las tandas

Una tanda, una rama, un PR. Se entrega una, se prueba, y sigue la próxima.

```
   0 · EL SPEC            este documento · producción mirada · el issue de Linear
   1 · TURNO Y CARGA      turnos + generador del timbre · carga horaria con la propuesta oficial
                          el turno de cada sección · «no cabe en la semana»
   2 · ARMAR              la pestaña «Horario» · las tres capas · cambiar de profesor
                          la muestra con sus 8 secciones de Media armadas
   3 · VERLO              Horarios por secciones / profesores / áreas · publicar
                          «Ahora · Después» · familia y alumno · PDF
   4 · LA VIDA REAL       disponibilidad del profesor · diagnóstico · mover e intercambiar
                          copiar el horario al año siguiente · Excel
   5 · EL AUTOMÁTICO      «Completar lo que falta», con su propio spec
```

Cada una sube la versión MENOR que siga a la que esté en `main`.
