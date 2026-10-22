# Los horarios de clase

> **Estado:** **congelado de nuevo** el 22 de octubre de 2026, con la maqueta · las decisiones 26 a 29 van como las propuso Claude y se confirman en el QA de la tanda 2
> **PR:** — (rama `docs/spec-horarios`, sin subir; el issue de Linear está sin crear: el conector no estaba autenticado)

Se congeló el 13 de octubre con 18 decisiones. La tanda 1 se construyó el 14, y
Daniel la devolvió el 16:

> *«Se supone que la idea era que se viera el horario por sección, por alumno,
> por profes… No veo nada de eso. Lo que veo es el esquema general del horario y
> el total de horas semanales por área: eso no es el horario.»* Y de la pantalla:
> *«CERO intuición y poco acabado».*

En vez de seguir programando, el 20 se hizo una **maqueta navegable**, y el 22
la aprobó con un solo pedido: *«todo muy bien; el único comentario es que la
sección de los mensajes debería resaltar un poco más… que brinque cuando se
haga clic en la tabla»*. Esta revisión la recoge: las decisiones 19 a 29 (§ 3),
las pantallas (§ 5), los criterios (§ 6) y las tandas (§ 10). Lo demás sigue
como se congeló.

Ese mismo 22 Daniel pidió pasarla al spec y seguir —*«aplica caffeinate por unas
3 horas y avanza cuanto más puedas»*—: las decisiones 26 a 29 se tomaron como
las propuso Claude, y se confirman en su QA de la tanda 2.

```
   13 DE OCTUBRE (congelado)                       22 DE OCTUBRE (esta revisión)
   ① Turno ② Carga ③ Armar ④ Publicar ⑤ Verlo     una puerta: el horario de la sección
   primero las pantallas de configuración          el timbre y la carga se corrigen DENTRO de él
   armar (tanda 2) y verlo (tanda 3) por separado  juntas: lo próximo que se prueba es el horario
   el PDF en la tanda 3                            en la tanda 4, con «otro turno»
```

La maqueta: https://claude.ai/artifact/MjKiTVWUbcvAH4toQRfuYX (privada, versión 2,
con datos inventados). Si un día no abre, manda este documento: sus pantallas
están en § 5.

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
| 11 | ¿Cómo se llama el timbre? | **«Turno»** («Turno de la mañana»): es la palabra de la resolución y del colegio. Desde el 22 no tiene pantalla propia (decisión 20). | Claude · confirmó Daniel, 13 oct |
| 12 | ¿La familia en mora ve el horario? | **Sí.** Es logística de la sección —está pegado en la puerta del salón—, no el expediente del hijo; esconderlo no presiona el pago y hace que el muchacho falte. | Claude · confirmó Daniel, 13 oct |
| 13 | ¿Se publica? | **«Borrador → Publicado», por sección.** Profesor, familia y alumno ven solo lo publicado; quien administra, todo. | Claude · confirmó Daniel, 13 oct |
| 14 | ¿Solo Media? | Sirve para toda sección con áreas —Primaria también, por los especialistas—; Inicial no. Se entrega pensado y sembrado para Media. | Claude · confirmó Daniel, 13 oct |
| 15 | ¿Sábados? | Lunes a viernes. El sábado, cuando un colegio lo pida. | Claude · confirmó Daniel, 13 oct |
| 16 | ¿Qué se bloquea? | Una sección con clases no cambia de turno sin vaciarse. Un año finalizado queda en solo lectura. | Claude · confirmó Daniel, 13 oct |
| 17 | ¿El automático es gratis? | No: es procesamiento. Se ve y no se toca sin suscripción. | Claude · confirmó Daniel, 13 oct |
| 18 | ¿Quién arma y quién publica? | Quien hoy administra secciones (`manage_sections`: dirección, coordinación y secretaría). El profesor mira. | Claude · confirmó Daniel, 13 oct |
| 19 | ¿Por dónde se entra? | **Por el horario.** «Horarios» abre en la semana de una sección: la hoja de la foto. La tanda 1 entraba por «Turnos» y «Carga horaria», y se devolvió. | Daniel, 16 oct · maqueta aprobada el 22 |
| 20 | ¿Cómo nace el turno? | **Solo, y ya puesto.** La primera vez que se abre «Horarios» en un año sin turnos nace «Turno de la mañana» con el timbre de la foto, y lo usan las secciones con áreas de ese año. Se corrige en la columna de las horas con «Armar» abierto, y avisa que el cambio llega a todas las secciones del turno. | Maqueta, 22 oct |
| 21 | ¿Dónde vive la carga horaria? | **En «Por ubicar»**: «Inglés · López · 2 de 4». El 4 sube y baja con − y +, para el grado entero. El plan oficial se propone solo, donde está vacía, sin botón. Si la carga no cabe en la semana, lo dice ahí, en ámbar y sin bloquear. | Maqueta, 22 oct |
| 22 | ¿Cómo se mira? | Cuatro pestañas: **Secciones · Profesores · Áreas · Alumnos**. En Secciones y en Profesores, «la semana de uno» o «todos, un mismo día». En el teléfono, un día, con los días arriba. | Maqueta, 22 oct |
| 23 | ¿Cómo se arma? | Se elige el área en «Por ubicar» y se toca la casilla, en bloques de 2 horas, con un interruptor para ubicar una sola. Lo que no se puede va rayado y con «?»: al tocarlo, el mensaje dice por qué. | Maqueta, 22 oct |
| 24 | ¿Cómo avisa el armador? | **Un mensaje fijo sobre la rejilla, que brinca** al tocar una casilla. Tres tipos: qué hacer (azul), lo que quedó guardado (verde) y por qué no se pudo (ámbar, con «?», y marca la casilla tocada). | Daniel, 22 oct |
| 25 | ¿Las tandas 2 y 3? | **Juntas.** Lo próximo que se prueba es el horario entero: armarlo y verlo por todas sus puertas. | Daniel, 22 oct |
| 26 | ¿Qué pasa con la tanda 1? | Su modelo se queda (§ 6). Sus dos pantallas se retiran, y no sube sola: va con el horario, en el mismo PR. | Claude · se confirma en el QA |
| 27 | ¿Y el PDF? | Pasa a la tanda 4: la maqueta no lo cubrió y no hace falta para probar el horario. | Claude · se confirma en el QA |
| 28 | ¿Un segundo turno (Primaria, tarde)? | En la tanda 4, desde la cabecera de la sección: «Cambiar de turno» ofrece los del año y «+ Otro turno», que abre el generador de la tanda 1. Hasta entonces, todas las secciones usan el turno del año. | Claude · se confirma en el QA |
| 29 | ¿Una sola puerta? | **Dos, a la misma pantalla:** «Horarios ▸ Secciones» y la pestaña «Horario» de la sección. No es otra manera de armar: es el mismo armador. Y la ficha del alumno lleva al horario de su sección. | Claude · se confirma en el QA |

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

- ⚠️ **«Primero se configura y después se ve.»** Así se armó la tanda 1 —turnos,
  después carga, después la rejilla— y Daniel la devolvió: entró a «Horarios» y
  no había ningún horario, y lo buscó en Secciones, en Grados y en
  Inscripciones. Un colegio piensa en la hoja de la foto, no en «turno» ni en
  «carga horaria». **La puerta es el horario, ya con valores puestos, y lo
  demás se corrige dentro de él.**
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
   una fuente, muchas vistas, y el teléfono        WebUntis · EduPage    las miradas (tanda 2)
   borrador → publicado                            GHC · OpenEduCat      tanda 2
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

Las pantallas son las de la maqueta, con sus datos inventados: 7 secciones de
Media, 12 profesores y 260 clases sin un choque.

### El recorrido

```
   Académico ▸ Horarios
        │
        ▼
   LA SEMANA DE UNA SECCIÓN ──► [Armar] ──► elegir el área ──► tocar la casilla ──► [Publicar]
   ya con el timbre de la foto        │                                                  │
   y la carga del plan oficial        └── el timbre y la carga se corrigen aquí mismo    ▼
                                                                    la ven sus profesores, sus
                                                                    alumnos y sus familias

   las otras miradas, de la misma tabla:  Profesores · Áreas · Alumnos · «todos, un mismo día»
```

### ① La semana de una sección — la puerta

```
   Académico ▸ Horarios
   ┌──────────────────────────────────────────────────────────────────────────────────────┐
   │ Horarios  2026-2027                                                                  │
   │ [Secciones]  Profesores   Áreas   Alumnos                                            │
   │ [La semana de una sección]  Todas, un mismo día                                      │
   └──────────────────────────────────────────────────────────────────────────────────────┘
   ┌──────────────────────────────────────────────────────────────────────────────────────┐
   │ 1er Año (●A)(○B) · 2do Año (●A)(●B) · 3er Año (●A) · 4to Año (●A) · 5to Año (●A)     │
   │                                                            ● publicado   ○ borrador  │
   │ 1er Año A  [Publicado]                                    [✎ Armar]  [⤓ Descargar]   │
   │ 38 de 38 horas ubicadas · Turno de la mañana, de 7:10 a. m. a 1:00 p. m.             │
   │                                                                                      │
   │             LUNES hoy      MARTES         MIÉRCOLES      JUEVES         VIERNES      │
   │ 1ra 7:10    ┃Arte          ┃Informática   ┃Dibujo        ┃Orientación   ┃…           │
   │ 2da 7:50    ┃Colmenares    ┃Díaz          ┃Díaz          ┃Guzmán        ┃            │
   │ 3ra · ahora ┃Matemática    ┃Grupos de C.  ┃C. Naturales  ┃Ed. Física    ┃            │
   │ 4ta 9:10    ┃García        ┃Colmenares    ┃Castillo      ┃Moreno        ┃            │
   │ Receso      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░ RECESO ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    │
   │ 5ta 10:20   ┃GHC           ┃GHC           ┃Castellano    ┃C. Naturales  ┃            │
   │ 6ta 11:00   ┃Herrera       ┃Herrera       ┃Rojas         ┃Castillo      ┃            │
   │ …                                                                                    │
   │                                                                                      │
   │ ÁREAS Y PROFESORES DE 1ER AÑO A                                                      │
   │ ▪ Castellano y Literatura   Rojas, Ana          4 de 4 h                             │
   │ ▪ Matemática                García, Carlos      4 de 4 h      …                      │
   └──────────────────────────────────────────────────────────────────────────────────────┘
   cada clase es un bloque de 80 minutos: dos horas de 40, dibujadas unidas
   cada área tiene su tono; el nombre manda, el color acompaña
```

### ② Armar

```
   1er Año B  [Borrador] [faltan 6 h]                            [Listo] [Publicar] [⤓ Descargar]
   ┌ POR UBICAR · FALTAN 6 HORAS ─────────────────────── (●) En bloques de 2 horas (80 min) ┐
   │ [Castellano Rojas 4 de 4 ✓] [Matemática García 4 de 4 ✓] [▣ Inglés López 2 de 4]       │
   │ [Arte Colmenares 0 de 2] [Dibujo sin profesor 0 de 2] …                                 │
   │ Inglés: [−] 4 [+] horas a la semana en 1er Año A y B        ← la carga horaria, aquí    │
   └─────────────────────────────────────────────────────────────────────────────────────────┘
   ╔═════════════════════════════════════════════════════════════════════════════════════════╗
   ║ (?) Miércoles a las 8:30 no se puede: López está en 2do Año A dando Inglés.             ║ ← fijo y
   ╚═════════════════════════════════════════════════════════════════════════════════════════╝   brinca
                    LUNES          MARTES         MIÉRCOLES         JUEVES          VIERNES
   [1ra 7:10   ✎]  Ed. Física  ×  Ed. Física  ×  Castellano     ×  Matemática   ×  Informática ×
   [2da 7:50   ✎]  Moreno         Moreno         Rojas              García          Díaz
   [3ra 8:30   ✎]  GHC         ×  Inglés      ×  ┏López en 2do A ?┓ C. Naturales ×  C. Naturales ×
   [4ta 9:10   ✎]  Herrera        López          ░López en 2do A ?░ Castillo        Castillo
   [Receso     ✎]  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ RECESO ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
   [5ta 10:20  ✎]  Grupos de C. × Orientación ×  Matemática     ×  [ + Inglés ]    Grupos de C. ×
   [6ta 11:00  ✎]  Colmenares     Guzmán         García             [ + Inglés ]    Colmenares
   [7ma 11:40  ✎]  Castellano  ×  GHC         ×  C. Naturales   ×  ░López en 2do B ?░ [ + Inglés ]
   [8va 12:20  ✎]  Rojas          Herrera        Castillo           ░López en 2do B ?░ [ + Inglés ]

   [ + Inglés ]  libre: tocarla la ubica          ░ … ? ░  no se puede: tocarla dice por qué
   ×  quitar: el bloque vuelve a «Por ubicar»     ✎  corregir la hora (cambia en todo el turno)
```

- Tocar una casilla libre **guarda en el momento** y el contador sube.
- Con «en bloques de 2 horas» se ubica también la otra hora del bloque. Si esa
  no se puede, se ubica una sola y el mensaje dice por qué.
- Al completar un área, el armador pasa solo a la siguiente que falta.
- La trama es neutra y nada va en rojo: el rojo sigue siendo del aplazado.
- Sin arrastrar: tocar y tocar sirve con el dedo y con el teclado. Mover e
  intercambiar llegan en la tanda 4.

### El mensaje del armador (decisión 24)

```
   (i)  azul    qué hacer              «Elija un área de arriba y toque una casilla con +»
   (✓)  verde   lo que quedó guardado  «Listo: Inglés el jueves de 10:20 a 11:40. Van 4 de 4.
                                         Sigue Arte (0 de 2).»
   (?)  ámbar   por qué no se pudo     «Miércoles a las 8:30 no se puede: López está en
                                         2do Año A dando Inglés.»  — y marca la casilla tocada
```

Va fijo sobre la rejilla: al tocar una casilla de las 12:20, el mensaje sigue a
la vista. Brinca una vez cuando cambia, y el ámbar deja además un halo que se
apaga. Con «reducir movimiento» no se mueve: quedan el color y el «?».

### Corregir una hora del timbre

```
   ┌ Corregir la 2da hora   de [ 07:50 ]  a [ 08:30 ]   [Guardar] [Cancelar] ───────────────┐
   │ Este timbre lo usan las 7 secciones del turno de la mañana: el cambio les llega a todas. │
   └──────────────────────────────────────────────────────────────────────────────────────────┘
   si se pisa con la de al lado:   «Se pisa con la 1ra hora (7:10 – 7:50).»
```

### ③ Todas, un mismo día

```
   Lunes, todas las secciones                                        [Lun] Mar Mié Jue Vie
   SECCIÓN                1RA 7:10 · 2DA 7:50       3RA 8:30 · 4TA 9:10   ┊ 5TA 10:20 …   ESE DÍA
   1er Año A              Arte · Colmenares         Matemática · García   ┊ GHC · Herrera   8 h
   publicado
   1er Año B              Ed. Física · Moreno       GHC · Herrera         ┊ …               8 h
   borrador · faltan 6 h
   …                      toque una sección para ver su semana
```

```
   Lunes, todos los profesores
   PROFESOR               1RA · 2DA                 3RA · 4TA             ┊ 5TA · 6TA …     ESE DÍA
   García, Carlos         libre      libre          1er A · Matemática    ┊ …               6 h
   López, María           2do B · Inglés            libre      libre      ┊ …               4 h
                          «libre» es un hueco: sirve para cubrir una ausencia
```

### ④ Un área y un alumno

```
   Matemática · 28 horas a la semana en 7 secciones · García 20 h · Pérez 8 h
                LUNES               MARTES              …
   1ra 7:10     1er B · García      4to A · Pérez
                5to A · Pérez
   dos secciones a la misma hora = la misma área con profesores distintos
```

```
   [ Buscar por nombre o apellido         ]
   (Valentina Suárez · 1er Año A)  (Andrés Suárez · 1er Año B)  (Camila Ortega · 2do Año A) …
   Valentina Suárez · 1er Año A · su horario es el de su sección
   (la semana de 1er Año A)
```

### ⑤ El profesor, en su inicio

```
   Inicio · lunes, 8:40 a. m.
   ┌ AHORA ─────────────────────────────┐  ┌ DESPUÉS ──────────────────────┐
   │ 1er Año A                          │  │ 10:20 · 2do Año B             │
   │ Matemática · hasta las 9:50        │  │ Matemática                    │
   │ [Pasar lista] [Calificar]          │  └───────────────────────────────┘
   └────────────────────────────────────┘
   Mi semana   (su rejilla, sin botones)
```

### ⑥ La familia, en el teléfono

```
   ┌─────────────────────────────────┐
   │ SIGA          U.E. Simón Bolívar │
   │ Andreína Suárez                  │
   │ [Valentina]      [Andrés]        │
   │  1er Año A        1er Año B      │
   │ Horario de Valentina             │
   │ (Lun•)  Mar  Mié  Jue  Vie       │
   │  7:10 ┃ Arte y Patrimonio        │
   │  8:30 ┃ Prof. Colmenares         │
   │  8:30 ┃ Matemática      [Ahora]  │
   │  9:50 ┃ Prof. García             │
   │ ░░░░ RECESO · 9:50 – 10:20 ░░░░░ │
   │ 10:20 ┃ Geografía, Historia y…   │
   │ …                                │
   │      Sale a la 1:00 p. m.        │
   └─────────────────────────────────┘
   Andrés, con 1er Año B en borrador:  «El horario de 1er Año B todavía no está publicado.»
```

### Cuando cambia el profesor — tanda 2

```
   García deja Matemáticas de 1er Año A  ──►  sus 4 horas siguen en el horario, «sin profesor»
   Se asigna a Pérez                     ──►  donde Pérez está libre:  toma la clase
                                              donde Pérez ya dicta:    la clase vuelve a «por ubicar»
                                              y el aviso dice cuáles:  «miércoles 8:30 — Pérez está en 3er Año A»
```

### Otro turno — tanda 4 (decisión 28)

```
   1er Grado A · Turno de la mañana, de 7:10 a. m. a 1:00 p. m.      [Cambiar de turno ▾]
                                                                      ● Turno de la mañana
                                                                      + Otro turno…
                                                                         └─► el generador de la tanda 1:
                                                                             entrada · minutos · horas ·
                                                                             receso, con su «Así queda»
```

### La vida real — tanda 4

```
   Profesores ▸ Herrera, José ▸ Disponibilidad          Horarios ▸ Diagnóstico
              Lun  Mar  Mié  Jue  Vie                   ✗ Herrera: 44 horas y su semana tiene 32 → no cabe
   7:10        ✓    ✓   ░░    ✓    ✓                    ⚠ 4to Año A: Biología no tiene profesor
   8:30        ✓    ✓   ░░    ✓    ✓                    ⚠ 1er Año B: faltan 6 horas por ubicar
              ░░ no está: dicta en otro colegio         cada renglón lleva a donde se arregla
```

El PDF —de una sección o de un profesor— es una hoja apaisada con el membrete
del colegio.

### El automático — tanda 5, con su propio spec

```
   [Completar lo que falta] ──► «Ubicaría 212 de 216 horas. Estas 4 no caben porque…» ──► [Confirmar]
   respeta lo ya puesto · nada se escribe sin confirmar · con suscripción
```

## 6 · Criterios de aceptación

### Lo que queda de la tanda 1 (hecha el 14 de octubre, devuelta el 16)

```
   SE QUEDA                                           SE RETIRA
   bell_schedules · time_slots · su EXCLUDE           la pantalla «Turnos»: lista, alta y ficha
   sections.bell_schedule_id                          la pantalla «Carga horaria»: la planilla
   grade_subjects.weekly_hours                        el turno en el formulario de la sección
   HorasDelTurno (el timbre) · CargaHorariaOficial     sus tests de pantalla, el humo y el menú
   HoraDelDia · los tests del modelo                  de esas dos pantallas
```

Con `bin/ci` en verde el 14 de octubre: dos horas de un turno no se pisan, ni
saltándose la validación, y el turno de una sección es de su año.

### Tanda 2 · El horario: armarlo y verlo

**Entrar**

- [ ] «Horarios» abre en la semana de una sección de Media del año de la sesión
      —la última que se miró, o la primera—, con su estado (publicado o
      borrador), sus horas ubicadas y su turno.
- [ ] Un año sin turnos estrena «Turno de la mañana» con el timbre de la foto
      —de 7:10 a 1:00, horas de 40 minutos, receso de 9:50 a 10:20— y lo usan
      sus secciones con áreas. Inicial no tiene horario.
- [ ] Un área sin carga recibe la del plan oficial si la reconoce por su
      nombre; si no, sale «sin horas» y se le ponen con +. Nunca se pisa lo que
      el colegio escribió.

**Armar**

- [ ] «Armar» muestra «Por ubicar»: cada área de la sección con su profesor
      —o «sin profesor»— y «ubicadas de carga». Las completas, atenuadas y con ✓.
- [ ] Elegida un área, cada casilla vacía es libre (`+ Inglés`) o rayada con
      «?», con el apellido del profesor y la sección donde está.
- [ ] Tocar una libre la guarda en el momento. En bloques de 2 horas ubica
      también la pareja del bloque; si la pareja no se puede, ubica una sola y
      dice por qué. Un bloque no cruza el receso ni el final del día.
- [ ] Una sección no puede tener dos clases a la misma hora, ni un profesor
      estar en dos secciones a la misma hora: la pantalla no lo ofrece, el
      modelo lo rechaza con el mismo texto, y saltándose la validación lo
      rechaza la base.
- [ ] El choque se mide por reloj: para un mismo profesor, una clase de 8:30 a
      9:10 en un turno choca con una de 8:45 a 9:30 en otro. Dos horas
      contiguas (7:10–7:50 y 7:50–8:30) no chocan.
- [ ] Un área sin profesor se ubica sin chocar con nadie y dice «sin profesor».
- [ ] Dos guardados a la vez sobre la misma casilla: uno entra y el otro lee
      «Esa casilla ya está ocupada», sin error 500.
- [ ] El × de una clase la quita entera —las dos horas de su bloque— y la
      devuelve a «Por ubicar».
- [ ] Al completar un área, el armador pasa sola a la siguiente que falta.

**El mensaje (decisión 24)**

- [ ] Va fijo sobre la rejilla: al tocar una casilla de las 12:20 se sigue viendo.
- [ ] Tres tipos, en color y en icono: qué hacer (azul, «i»), lo que quedó
      guardado (verde, ✓) y por qué no se pudo (ámbar, «?»). Un «no se puede»
      marca la casilla tocada.
- [ ] Brinca una vez cuando una acción sobre la rejilla lo cambia; no al
      cambiar de pestaña ni al volver a pintar. Con «reducir movimiento» no se
      mueve.
- [ ] Los textos de § 5 son el contrato: el día, la hora, el profesor, la
      sección donde está y el área que dicta allá.

**El timbre y la carga, dentro de la rejilla**

- [ ] Con «Armar» abierto, cada hora de la columna izquierda se corrige ahí, y
      el aviso dice que el cambio llega a las secciones del turno. Si se pisa
      con la de al lado: «Se pisa con la 1ra hora (7:10 – 7:50).»
- [ ] Corregir una hora mueve los minutos de sus clases en todas las secciones.
      Si haría chocar a un profesor con otro turno, no se guarda y dice con quién.
- [ ] Con un área elegida, su carga sube y baja con − y + para todo el grado
      («en 1er Año A y B»). No baja de lo ya ubicado en ninguna sección del
      grado: lo dice y no la cambia.
- [ ] Si la carga del grado suma más que la semana, «Por ubicar» lo dice en
      ámbar —«suma 44 horas y la semana tiene 40: sobran 4»— y no bloquea.

**Cuando cambia el profesor**

- [ ] Al borrar la asignación de un profesor, sus clases siguen en el horario
      «sin profesor» — también cuando se borra con `delete_all`.
- [ ] Al asignar un profesor: toma las clases donde está libre; donde choca, la
      clase vuelve a «Por ubicar» y el aviso nombra el día, la hora y dónde
      está. La asignación se guarda siempre.
- [ ] Una sección con clases no cambia de turno: el aviso pide vaciarla.
- [ ] Borrar una sección se lleva sus clases. Una hora con clases no se borra,
      y el aviso dice cuántas tiene.

**Las miradas (decisión 22)**

- [ ] Secciones, Profesores, Áreas y Alumnos salen de la misma tabla de clases
      y dicen lo mismo.
- [ ] «Todas, un mismo día» y «Todos, un mismo día»: una fila por sección o por
      profesor, una columna por hora, el receso marcado y el bloque unido;
      «libre» donde el profesor no tiene clase. Tocar una fila abre su semana.
- [ ] La semana de un área muestra en cada casilla las secciones que la tienen
      y con quién.
- [ ] Alumnos busca por nombre o apellido, palabra por palabra y sin importar
      los acentos (`MOR-179`, `MOR-183`); su horario es el de su sección.
- [ ] La pestaña «Horario» de la sección es la misma pantalla (decisión 29), y
      la ficha del alumno lleva al horario de su sección.
- [ ] En el teléfono, cada semana se ve como un día, con los días arriba y el de
      hoy marcado. A 380 px nada se corre de lado.

**Publicar y las otras puertas**

- [ ] «Publicar» pide confirmar y dice qué falta: «Faltan 6 horas por ubicar:
      esas casillas saldrán vacías.»
- [ ] Una sección publicada la ven sus profesores, sus alumnos y sus familias;
      en borrador, solo quien administra (decisión 13). ⚠️ La maqueta le muestra
      al profesor también lo que está en borrador: manda la decisión.
- [ ] El profesor ve en su inicio «Ahora» y «Después» con la hora de
      Venezuela —a las 8 de la noche de Caracas sigue siendo hoy— y «Mi
      semana», sin botones.
- [ ] La familia ve el horario de cada hijo en el teléfono: abre en el día de
      hoy (el fin de semana, en el lunes), marca la clase de ahora y dice a qué
      hora sale. Con la sección en borrador: «El horario de 1er Año B todavía no
      está publicado.»
- [ ] El alumno ve el de su sección. Una familia en mora lo ve (decisión 12).

**Lo de siempre**

- [ ] Otro colegio no ve ni toca nada (404), y las tablas nuevas tienen RLS con
      `FORCE`.
- [ ] En gratis se arma y se mira; los portales de la familia y del alumno
      siguen pidiendo la suscripción. Con la suscripción vencida, se ve y no se
      escribe.
- [ ] En un año finalizado el horario se ve y no se edita.
- [ ] El profesor no arma: ve su semana y la de sus secciones, sin botones.
- [ ] Las pantallas de la tanda 1 ya no están: ni en el menú, ni en las rutas,
      ni en el humo.

**La muestra**

- [ ] Amanece con las secciones de Media del año en curso armadas con el turno
      de la foto y sin un choque, y 1er Año B con horas «por ubicar» a
      propósito, como en la maqueta.

### Tanda 4 · La vida real

- [ ] **Otro turno** (decisión 28): «Cambiar de turno» en la cabecera ofrece
      los del año y «+ Otro turno», con el generador de la tanda 1 y su «Así
      queda» en vivo. Una sección con clases no cambia (decisión 16).
- [ ] **El PDF** (decisión 27) de una sección y el de un profesor caben en una
      hoja apaisada y dicen el colegio, el año, el turno y cada clase — leídos,
      no pesados. En gratis piden suscripción; vencido, se descargan.
- [ ] Quien administra marca las horas en que un profesor no está. Esas casillas
      salen rayadas con «Herrera no está disponible a esa hora» y no se ubican.
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
- [ ] Publicar varias secciones de una vez. El Excel trae una hoja por sección.

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
- **Retirar las pantallas de la tanda 1** cambia a propósito sus rutas
  (`/turnos`, `/carga-horaria`), sus tres archivos de tests de pantalla, el
  humo, el menú, las listas de `RespetaLaSuscripcion` y el formulario de la
  sección. Lo que se queda —modelo y servicios— conserva sus tests.
- **La versión.** `main` ya está en 1.21.0 (el enlace por WhatsApp): el horario
  sube a **1.22.0**, y el commit de la tanda 1, que dice 1.21.0 en `VERSION` y
  en el `CHANGELOG`, se corrige al rebasar sobre `main`.
- **El brinco.** Una animación que corre en cada pintado brincaría también al
  cambiar de pestaña: brinca solo el mensaje nuevo de una acción sobre la
  rejilla, y `prefers-reduced-motion` la apaga.
- **El mensaje fijo.** `position: sticky` deja de pegar si un ancestro tiene
  `overflow`: la rejilla se desplaza de lado dentro de su propio marco, y el
  mensaje va FUERA de ese marco.
- **El color.** `regla_de_color_test` va a mirar el verde y el ámbar del
  mensaje. Se defienden como dato —lo que quedó guardado, por qué no se pudo—
  y no como control; si el test no lo admite, se habla antes de forzarlo. Un
  choque en rojo lo rompe, y con razón.
- **`pestanas_de_la_seccion_test` y `areas_y_profesores_test`** afirman la lista
  exacta de pestañas: cambian a propósito.
- **`menu_del_profesor_test`** exige que el menú del profesor sea `["Dicto"]`:
  «Ahora · Después» va en su inicio, no en un grupo nuevo.
- **`frontera_de_lo_gratis_test`**: cada controlador nuevo, en una lista; los
  dos que se van, fuera de todas.
- **`aislamiento_estructural_test`**: las tablas nuevas, con `SchoolScoped`, RLS,
  `FORCE` y su política.
- **`erd_del_modelo_test`** (`ORDEN` en `lib/tasks/modelo.rake`) y
  **`lo_que_impide_borrar_test`** (los nombres en `es.yml`).
- **`lib/tasks/prueba.rake`** borra con una lista escrita a mano: le faltarían
  las tablas nuevas. `OrdenDeBorrado` sí se calcula solo.
- **La hora.** La app corre en UTC: desde las 8 de la noche «hoy» ya es mañana.
  «Ahora», «Después» y «hoy» salen de `HoraDeVenezuela`, no de `Date.current`.
- **Los códigos no coinciden.** La siembra usa `LEN`, `EDF`, `CNA`; el plan,
  `CAS`, `EF`, `CN`. Proponer la carga por código dejaría en blanco medio
  colegio: se empareja por nombre, como `Subject.area_del_31059`.
- **La siembra.** Los profesores sembrados tienen más horas que la semana
  —Herrera dicta dos áreas en siete secciones—: la muestra lleva una carga
  propia que quepa en 40, o amanecería con medio horario sin ubicar.
- **La muestra se resiembra en UNA transacción**: el horario no puede depender
  de un `after_commit`.
- **El año y el nivel de la sesión.** Con «Todos los años» se cae en
  `anio_de_trabajo`. «Horarios» declara `el_nivel_no_aplica` donde no filtra.
- **El importador de pensum.** Si reasigna y desubica clases, lo dice en su
  reporte.
- **La carga no tiene año.** `weekly_hours` es del pensum: cambiarla en 2027
  mueve el «faltan» de 2026. Se acepta: es un aviso de planificación.
- **Los tests y otra sesión.** `siga_test` es UNA base: dos `bin/ci` a la vez se
  pisan. Resuelto en la tanda 1: `SIGA_TEST_DB_NAME` le da otro nombre al
  worktree.

## 8 · Cómo se verifica

- `bin/ci` en verde antes de cada PR, y `bin/smoke` pasando por las rutas nuevas
  con los cuatro roles.
- **La base, sola**: tests que guardan saltándose la validación
  (`save(validate: false)`, en su `SAVEPOINT`) y esperan el rechazo.
- **Las cascadas**: borrar la asignación, corregir una hora, borrar la sección.
- **De sistema**: elegir un área y tocar una casilla, leer el porqué de una
  rayada, a 380 px.
- **Las capturas, antes de entregar**: cada pantalla nueva en escritorio y en
  teléfono, mirada. Es la lección del 16 de octubre: los tests en verde no
  vieron nueve botones «Guardar» ni las horas cortadas («07:00 a.n»).
- **Daniel, en la muestra**, al cierre de cada tanda:

```
   tanda 2   director      Horarios: 1er Año A · Todas, un mismo día · García · Matemática · Valentina
                           1er Año B ▸ Armar: ubicar Inglés, Arte y Dibujo; tocar una rayada;
                           corregir una hora; subir y bajar una carga · Publicar
                           Áreas y profesores: cambiar a un profesor y leer el aviso
             profesor      García: «Ahora · Después» y «Mi semana»
             representante el teléfono: un hijo con la sección publicada y otro en borrador
```

---

## 9 · Cómo está hecho

### Los nombres

```
   SE LEE                     EN EL CÓDIGO                          DÓNDE
   Horarios (las miradas)     HorariosController                    /horarios
   la semana de una sección   la misma pantalla                     /horarios y la pestaña «Horario»
                                                                    de la sección (decisión 29)
   clase                      Lesson · lessons                      /secciones/:id/clases
   Turno                      BellSchedule · bell_schedules         sin pantalla propia (decisión 20)
   hora (1ra, 2da… Receso)    TimeSlot · time_slots                 se corrige desde la rejilla
   carga horaria              grade_subjects.weekly_hours           el − y + de «Por ubicar»
   el turno de la sección     sections.bell_schedule_id
   publicado                  sections.timetable_published_at
   no disponible              TeacherUnavailability                 (tanda 4)
```

Servicios, en español: `HorasDelTurno` (el timbre: el del turno que nace solo y,
en la tanda 4, el de «otro turno»), `CargaHorariaOficial` (la propuesta, ahora
sin botón), `ChoquesDeHorario` (el porqué, en UN sitio), `HorarioDeLaSeccion`,
`RejillaDeHorarios`, `ArmarElHorario` (la siembra), `DiagnosticoDelHorario`,
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
   LA_ENTRADA             horarios · lessons · time_slots (corregir una hora) · la carga (− y +)
                          (el PDF y el Excel, tanda 4, piden suscripción solos: son archivos)
   ya estaban ahí         sections · dashboards/profesor
   SOLO_CON_SUSCRIPCION   representante · dashboards/estudiante   (ya estaban)
   CON_SUSCRIPCION        el automático (tanda 5)
   SE VAN                 bell_schedules · carga_horaria          (las pantallas de la tanda 1)
```

### El armador, sin librerías

Un solo formulario: cada área de «Por ubicar» es un `radio` y cada casilla libre
un botón. La respuesta —un Turbo Stream— reemplaza el armador y el mensaje, así
que el estado sale siempre del servidor, y sin JavaScript ya funciona.
`horario_controller.js` solo pinta, al cambiar de área, qué casillas quedan
libres, sin ir al servidor. Todo lo que bloquea a un área se calcula en UNA
consulta por rejilla.

El mensaje entra con una animación de CSS: brinca al nacer. El servidor le pone
la clase solo en la respuesta a una acción sobre la rejilla, y por eso no brinca
al cambiar de pestaña.

## 10 · Las tandas

Una tanda, una rama, un PR. Se entrega una, se prueba, y sigue la próxima.

```
   0 · EL SPEC            congelado el 13 · revisado el 22 con la maqueta
   1 · TURNO Y CARGA      hecha el 14 y devuelta el 16: su modelo se queda, sus pantallas no
   2 · EL HORARIO         (antes 2 y 3) armarlo y verlo: la rejilla como puerta, las cuatro
                          miradas, publicar, el profesor y la familia, la muestra armada
                          · lleva dentro la tanda 1 (decisión 26) · 1.22.0
   3 · —                  se juntó con la 2 (decisión 25)
   4 · LA VIDA REAL       otro turno · el PDF · disponibilidad · diagnóstico · mover e
                          intercambiar · copiar al año siguiente · publicar varias · Excel
   5 · EL AUTOMÁTICO      «Completar lo que falta», con su propio spec
```

Cada una sube la versión MENOR que siga a la que esté en `main`.
