# MOR-136 · Evaluar Educación Primaria por competencias

> **Estado:** en discusión — **una** decisión abierta, la § 9
> **Issue:** [MOR-136](https://linear.app/morosdevelopment/issue/MOR-136) · P1 · proyecto «SIGA · Módulo de evaluación»
> **PR:** —

---

## 1 · El problema

En Educación Primaria no se evalúa con notas sueltas: se evalúa **competencias**.
Hoy el docente las escribe de cero **cada lapso, todos los años**, y las tira al
terminar.

Cyndi Montoya, maestra con 19 años de aula:

> *«Lo principal en la parte académica de los sistemas es **guardar las
> competencias y los indicadores**. Eso sería una ayuda grandísima para el
> docente, porque si no **nosotros todos los lapsos tenemos que estar cargando
> competencias e indicadores**… y **eso es algo que pasa con todos los
> sistemas**. Es de verdad una pérdida de tiempo muy grande.»*

**El tamaño, contado de dos boletas reales** (U.E. Colegio Teresiano Nuestra
Señora de Coromoto, 3er lapso 2025-2026):

```
   5to Grado B    12 áreas · 31 competencias
   6to Grado B    13 áreas · 37 competencias
   ───────────────────────────────────────────
   un colegio de 6 grados × 3 lapsos  ≈  620 competencias AL AÑO
```

Y SIGA hoy no puede ni recibirlas: `EvaluationActivity` es una actividad con una
nota, y esto es competencia → indicadores → rúbrica.

⚠️ **Por eso el boletín de primaria hoy miente por omisión.** `ReportCardPdf` y
la vista del representante muestran el número del lapso porque la rúbrica no
existe, y está anotado en tres archivos que eso es provisional. Una madre de
primaria no espera un 17: espera un **PA**.

## 2 · Qué NO entra

```
   ENTRA                                   NO ENTRA
   ─────                                   ────────
   el plan: competencias e indicadores     Educación Inicial      → MOR-218
   la sugerencia del plan anterior         los indicadores en la
   copiar el plan a mis otras secciones      boleta y el comentario → MOR-216
   cargar el nivel de cada alumno          el coordinador de área  → MOR-217
   la rúbrica del colegio                  la nomenclatura del MPPE → MOR-212
   el boletín con la competencia y su nivel
```

⚠️ **Y no se sobreconstruye.** Cyndi lo advirtió sin que se le preguntara:
*«hay un montón de cosas que son innecesarias que uno no utiliza, y la gente que
te vende el sistema te ofrece todo eso»*. La versión mínima —guardar, sugerir,
reutilizar, calificar— es casi todo el valor.

**Lo que NO se construye, aunque aparezca solo:** pesos o ponderación entre
competencias (el Art. 111 no aplica y `MOR-164` ya borró un peso que no
calculaba nada) · catálogo compartido entre colegios · etiquetas y taxonomías ·
flujo de aprobación del plan por la coordinadora · gráficos de progreso.

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Dónde se pone el nivel? | En la **COMPETENCIA**. Ni en la actividad ni en el indicador. Ver § 4 | ✅ revisión de UX |
| 2 | ¿Los indicadores se califican? | **No: se imprimen.** Imprimir ≠ calificar | ✅ revisión de UX |
| 3 | ¿De qué cuelga el plan? | De la **SECCIÓN**. Corroborado con Cyndi | ✅ Daniel |
| 4 | ¿Se clona al abrir el año escolar? | **No.** Se SUGIERE cuando el profesor entra a su sección | ✅ Daniel |
| 5 | ¿`NP` es reprobado o «sin evaluar»? | **REPROBADO.** *«El docente está obligado a evaluar»* | ✅ Daniel |
| 6 | ¿Qué se guarda: el número o el nivel? | **El número.** La rúbrica es una máscara. Ver § 4 | ✅ deducido — § 9 |
| 7 | ¿La rúbrica es constante o configurable? | **Configurable por colegio**, porque es presentación | ✅ deducido de la 6 |
| 8 | ¿Cómo sabe el código qué camino usar? | Se **deriva del plan**: si `(sección, materia, lapso)` tiene competencias, va por competencias | ✅ técnica |
| 9 | ¿La nota del lapso sale de las competencias? | **ABIERTO** — § 9 | ⬜ Cyndi |

## 4 · El dominio

### La ley, que no se negocia

- **Art. 108** — la calificación es un **entero del 1 al 20**; ≥ 0,50 sube.
- **Art. 111** — el anual es el **promedio simple** de los lapsos. Dentro del
  lapso, 70 % parciales + 30 % evaluación final.
- **Art. 112** — la nota de la segunda oportunidad es la definitiva.

### La rúbrica: qué se guarda y qué se muestra

Este era el punto que faltaba aclarar. Daniel:

> *«Me cuenta Cyndi que ellos evalúan con rúbricas: PC, PA, NP… **esto puede
> cambiar entre colegios**, cada uno tiene su manera. Incluso había colegios que
> solo tenían **tres**, lo que lo hacía muy complicado porque **metías en el
> mismo saco a estudiantes con 13 que a estudiantes con 17**. Luego, no sabe de
> qué forma, eso se convierte en la nota final del lapso. Entonces se me ocurrió
> mapear la rúbrica a una calificación numérica para poder sumar, porque se
> suman y promedian números, no rúbricas. Termina siendo como una **máscara**,
> pero no sé por qué se plantea así.»*

**Se plantea así porque es lo correcto, y la queja de los tres niveles es la
prueba:**

```
   A · la maestra escribe el NIVEL
   ───────────────────────────────
   PC ──► se guarda "PC" ──► para promediar hace falta un número,
                              y el número hay que INVENTARLO
   ⚠️ La información se pierde AL CAPTURAR. En un colegio de tres
      niveles, el 13 y el 17 quedan en el mismo saco — para siempre.

   B · la maestra escribe el NÚMERO, la familia ve el NIVEL
   ───────────────────────────────────────────────────────
   17 ──► se guarda 17 ──► promedia como manda el Art. 111
                      └──► la familia lee «PA»
   ✓ No se pierde nada. El colegio de tres niveles tiene una máscara
     más gruesa, y por dentro el 13 y el 17 siguen siendo distintos.
```

⚠️ **Y B no es una propuesta: es lo que Cyndi ya vivía.** Está citado en
`EscalaLiteral` desde `MOR-129`:

> *«Nosotros subíamos las notas cuantitativas… la niña sacó 19, por eso tiene
> PC. Al momento de subir la nota yo le tenía que poner 19, pero a los
> representantes se les reflejaba era PC.»*

**Elegir B desarma tres problemas de una vez:**

1. **La regla de agregación no hay que inventarla.** Se promedian números, que
   es lo que manda el Art. 111. Con niveles habría que decidir moda, promedio o
   mínimo, y **ninguna norma lo define** — una regla inventada es una regla que
   la maestra le tiene que defender a una mamá en la puerta del salón.
2. **La rúbrica pasa a ser configurable SIN riesgo.** Cambiar la máscara no
   reescribe ninguna nota, porque las notas son números. Se cae entero el
   *«cambiar el value implica un recálculo de todas las calificaciones»*.
3. **El colegio de tres niveles se representa sin pelear.** Su máscara tiene
   tres bandas y ya.

**Los cinco niveles y sus bandas** — y fíjese que caen uno en cada banda de
`EscalaLiteral`, que ya existe:

| | | banda | `EscalaLiteral` |
|---|---|---|---|
| **PC** | Proceso consolidado | 19–20 | A |
| **PA** | Proceso avanzado | 17–18 | B |
| **PI** | Proceso intermedio | 14–16 | C |
| **PD** | Proceso con dificultad | 10–13 | D |
| **NP** | No cumplió el proceso | 1–9 | E — **reprobado** |

⚠️ **`NP` es REPROBADO, no «sin evaluar».** Daniel: *«el docente está obligado a
evaluar»*. Son cinco niveles, no cuatro más un estado. Y aun así **«sin evaluar»
existe** y es otra cosa: es la ausencia de nota, se escribe en letras y **nunca
es NP ni cero**. Es la misma doctrina de tres capas que ya está escrita.

### Dónde va el nivel: en la competencia

Ni en la actividad ni en el indicador. La cuenta la hizo la revisión de UX:

```
   POR COMPETENCIA   21 × 30       =    630 valores/lapso  →  ~21 min   ✓
   POR INDICADOR     21 × 3 × 30   =  1.890 valores/lapso  →  ~95 min   ✗
   POR ACTIVIDAD     21 × 2 × 30   =  1.260  + una regla de agregación
```

⚠️ **En primaria la evaluación es continua y por observación**, no por eventos
discretos. Colgar el nivel de una actividad obliga a la maestra a inventar
«Evaluación 1 / Evaluación 2» donde no las hay.

⚠️ **Los indicadores describen qué significa la competencia; no se puntúan.** El
pedido de `MOR-216` —que los padres entiendan mejor— se resuelve
**imprimiéndolos**. Pedir tres niveles donde la maestra juzgó uno produce el
mismo valor repetido tres veces: precisión falsa impresa en un papel que la
familia guarda.

### El plan es de la SECCIÓN, y lo maneja su profesor

Corroborado con Cyndi. Revierte lo que habían recomendado las dos revisiones —y
la razón manda: **cada profesor es autónomo en su gestión**.

⚠️ **No se clona al abrir el año escolar.** `CopiarLaEstructura` (`MOR-166`) no
toca esto: la sugerencia aparece **cuando el profesor entra a su sección**. Un
plan clonado que nadie miró es un plan que alguien va a usar sin leer.

⚠️ **Copiar a mis otras secciones es un ATAJO, no un vínculo.** Después de
copiar, cada sección es independiente y admite modificaciones particulares.

## 5 · Cómo se ve

**Planificar el lapso.** La pantalla no abre vacía: abre ofreciendo.

```
   ┌─ TELÉFONO ────────────────────────────────────┐
   │ ←  Plan de evaluación · 1er Lapso             │
   │    5to Grado B · Matemática                   │
   ├───────────────────────────────────────────────┤
   │ ╭───────────────────────────────────────────╮ │
   │ │ Hay un plan del 1er Lapso de 2025-2026    │ │
   │ │ para 5to Grado · Matemática.              │ │
   │ │        [ Cargarlo para revisar ]          │ │
   │ ╰───────────────────────────────────────────╯ │
   │                                               │
   │  Todavía no hay competencias en este plan.    │
   │  + Registrar competencia                      │
   └───────────────────────────────────────────────┘

   ── después de cargarlo ──

   │ ☑ Resuelve problemas de proporcionalidad…     │
   │      3 indicadores                      ⌄     │
   │ ☑ Resuelve situaciones con fracciones…        │
   │      2 indicadores                      ⌄     │
   │ ☐ Construye figuras y cuerpos geométricos     │
   │      4 indicadores                      ⌄     │
   │                                               │
   │  + Registrar competencia                      │
   │  ⟲ Limpiar todo y empezar de cero             │
   │ ┌───────────────────────────────────────────┐ │
   │ │            Guardar el plan                │ │
   │ └───────────────────────────────────────────┘ │
   │                                               │
   │  ⧉ Copiar este plan a mis otras secciones (2) │
   └───────────────────────────────────────────────┘
```

**Cargar los niveles.** Una pantalla por materia; las competencias son secciones
adentro.

```
   ┌─ TELÉFONO ────────────────────────────────────┐
   │ ←  Matemática · 1er Lapso · 5to Grado B       │
   │ ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░  54 de 90 cargadas        │
   ├───────────────────────────────────────────────┤
   │ ▸ COMPETENCIA 1 de 3                          │
   │   Resuelve problemas de proporcionalidad…     │
   │   ⌄ Ver los 3 indicadores                     │
   │ ─────────────────────────────────────────     │
   │  (o) ACOSTA PÉREZ, Luis                    ✓  │
   │       PC   ▐PA▌   PI    PD    NP              │
   │  (o) BRICEÑO LARA, Ana Sofía               ✓  │
   │      ▐PC▌   PA    PI    PD    NP              │
   │  (o) DELGADO GUZMÁN, Camila                —  │
   │       PC    PA    PI    PD    NP              │
   │                    ↑ sin evaluar — NO es NP   │
   │ ─────────────────────────────────────────     │
   │  12 PC · 9 PA · 5 PI · 4 sin evaluar          │
   └───────────────────────────────────────────────┘
```

⚠️ **`.carga-fila` es hoy `flex` de UNA línea** y cinco botones no caben al lado
de «CARRILLO NIÑO, José Miguel». Pasa a dos líneas: nombre arriba, la fila de
cinco abajo.

⚠️ **La unidad de pantalla es la MATERIA, y es por el DOM**: 3 competencias × 30
alumnos × 5 botones = 450 botones, que aguanta en un Android barato. Un lapso
entero serían 3.150 y no aguanta.

⚠️ **El color: la rúbrica es DATO, así que puede llevarlo — pero no SOLO color,
y NO rojo.** En SIGA un número en rojo es un niño aplazado y ese significado no
se gasta. Va una rampa de intensidad de un tono, con las letras siempre visibles.

## 6 · Criterios de aceptación

- [ ] Dado un profesor en su sección sin plan, cuando hay uno del mismo grado y
      materia del año anterior, entonces se le **ofrece** cargarlo — y no se
      carga solo.
- [ ] Dado que lo carga, cuando lo edita y guarda, entonces el plan del año
      anterior **no cambia**.
- [ ] Dado que dicta 5to A y 5to B, cuando copia el plan, entonces las dos
      secciones quedan con las mismas competencias y **editarlas por separado
      no afecta a la otra**.
- [ ] Dado que limpia el plan, entonces se borran las competencias **solo si
      nadie cargó un nivel contra ellas**; si los hay, se dice qué se perdería.
- [ ] Dado un alumno con nivel en las 3 competencias de Matemática, entonces su
      nota del lapso en Matemática existe y es un entero del 1 al 20.
- [ ] Dado un alumno **sin** nivel en una competencia, entonces el boletín
      escribe «Sin evaluar» en letras — nunca NP y nunca cero.
- [ ] Dado que se corre `bin/rails notas:recalcular`, entonces las notas de
      primaria **siguen ahí**. (Ver § 7 — es el peor riesgo de todo el issue.)
- [ ] Dado un colegio que cambia su rúbrica de 5 niveles a 3, entonces **ninguna
      nota guardada cambia**: solo cambia cómo se lee.
- [ ] Dado un boletín ya emitido, cuando se corrige el texto de una competencia,
      entonces el boletín emitido sigue diciendo lo que decía.
- [ ] Dado bachillerato, entonces todo sigue funcionando exactamente igual.

## 7 · Lo que se puede romper

⚠️ **`GradeCalculator` le borra las notas a la primaria entera, en silencio.**
Es el riesgo número uno y hay que resolverlo en el mismo despliegue:

```ruby
return borrar_nota_de_lapso(...) if activities.empty?
```

En primaria **no hay actividades**. En cuanto exista una nota producida por
competencias, el primer `notas:recalcular` —o cualquier `RecalcularSeccionJob`—
la borra. Es exactamente lo que le pasaba al historial importado antes de
`origen`, y la cura es la misma: un tercer valor, `por_competencias`, que
`borrar_nota_de_lapso` respeta igual que a `importada`.

⚠️ **La bifurcación vive DENTRO de `calculate_moment_grade`**, no en un servicio
paralelo. Es lo que hace que `notas:recalcular`, `RecalcularSeccionJob` y
`calculate_all_for_enrollment` sigan funcionando sin tocarlos.

⚠️ **El boletín de primaria saldría VACÍO, y no por culpa de este issue.**
`Enrollment#materias_del_boletin` sale de `teacher_sections` o de las
actividades. En primaria **una sola maestra dicta todo**: si el colegio no crea
sus siete `TeacherSection`, los dos términos dan vacío y el boletín queda en
blanco **sin un solo error**. Hace falta un tercer término: las materias que
tienen competencias en el plan.

⚠️ **«Quién no cargó notas» se queda ciego en primaria.** Compara contra
evaluaciones cuya `date_scheduled` ya pasó, y una competencia **no tiene fecha**
—es evaluación continua—. La pantalla de control de la dirección deja de ver a
la primaria entera. El equivalente honesto usa `evaluation_moments.ends_on`.

⚠️ **El guarda de aislamiento NO agarra una tabla sin `school_id`.**
`aislamiento_estructural_test` pregunta «¿qué tablas *tienen* `school_id` y les
falta RLS?». Una tabla **sin la columna** pasa en verde y la lee todo el mundo.
El RLS evalúa columnas de la fila, no asociaciones.

⚠️ **`validates_same_school` en las DOS asociaciones, no en una.** La
competencia cuelga de una sección y el nivel de una inscripción: sin la
validación cruzada se escribe un nivel contra un alumno de otra sección, y queda
escrito.

⚠️ **Tres comentarios del código quedan mintiendo** el día que esto exista:
`report_card_pdf.rb:203`, `application_helper.rb:67` y `escala_literal.rb` dicen
los tres «hasta que exista MOR-136 se muestra el número». Son promesas escritas;
se cobran en el mismo PR.

⚠️ **Un bug adyacente que este trabajo destapa y no es suyo:**
`report_card_data.rb` usa `grade.escala` y la certificación 31059 usa
`Subject#escala_en(grado)`. «Orientación y Convivencia» de 4to Año sale **en
número en el boletín y en letra en la 31059** — el mismo alumno, dos papeles que
no coinciden. Va en su propio issue.

⚠️ **No despachar por `escala`.** Ese mismo caso lo prueba: tiene
`escala = literal` y **no** se evalúa por competencias. Son dos preguntas
distintas —cómo se MUESTRA vs cómo se PRODUCE— y hoy se confunden porque
`literal` casi siempre significa primaria. Se deriva del plan.

## 8 · Cómo se verifica

- `bin/ci` completo antes del PR.
- **El test que vale por todos:** cargar niveles de primaria, correr
  `bin/rails notas:recalcular`, y comprobar que las notas **siguen ahí**.
- Un test que reconstruya **la boleta real de 5to Grado B**: 12 áreas, 31
  competencias, sus niveles y la nota de promoción. Si el PDF que sale no se
  parece al que el colegio usa hoy, no sirve.
- Test de sistema (Chrome de verdad) para tres cosas que no se ven leyendo el
  HTML: que la fila de cinco botones no desborde a 390 px, que el guardado
  incremental sobreviva a perder la conexión, y que copiar a otra sección no
  ate las dos.
- A mano, con Cyndi delante: cargar un lapso completo de un grado y comparar el
  boletín contra el que emite su sistema actual.

## 9 · La única pregunta abierta

`MOR-136` la dejó escrita desde el principio como *rabbit hole 3*, con un no-go
al lado: **«no modelar antes de preguntar esto»**.

```
   A ·  la nota del lapso SALE de las competencias
        3 competencias  ──promedio──►  17  ──►  moment_grade  ──►  anual

   B ·  corren en PARALELO
        las competencias se imprimen, no se promedian
        la nota del lapso sale de las actividades, como hoy
```

Cyndi describió la agregación **indicador → competencia**. **Nunca** describió
competencia → nota del lapso; de hecho dijo que *no sabe de qué forma* se
convierte en la nota final. Promediar las competencias sería **invención
nuestra**, y sería la tercera regla aritmética del sistema sin norma detrás.

⚠️ **Pero no bloquea empezar.** El esquema es el MISMO en A y en B; lo único que
cambia es si el calculador se bifurca, y **B es subconjunto estricto de A**.

```
   1. congelar el esquema y las pantallas   ──►  se puede hacer YA
   2. preguntarle a Cyndi                   ──►  bloquea SOLO el paso 3
   3. cablear el calculador                 ──►  B = no tocar nada
                                                 A = una rama en un método
```

**Las dos preguntas para ella, redactadas:**

> **1.** «Cuando usted termina el lapso, la nota que sale en la boleta para
> Matemática, ¿de dónde sale? ¿Es un promedio de las competencias que evaluó, o
> la calcula aparte con las evaluaciones que hizo?»

> **2.** «Al cargar en el sistema, ¿usted escribe el número —17, 19— y el
> representante ve PC, o usted toca directamente PC?»

*La segunda confirma la § 4. Su respuesta de `MOR-129` dice que escribía el
número; conviene oírlo otra vez ahora que sabemos que la rúbrica cambia entre
colegios.*
