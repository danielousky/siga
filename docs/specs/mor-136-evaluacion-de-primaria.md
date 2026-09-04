# MOR-136 · Evaluar Educación Primaria por competencias

> **Estado:** **congelado** — 4 de septiembre de 2026
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
   el plan: competencias e indicadores     Educación Inicial       → MOR-218
   la sugerencia del plan anterior         el comentario del
   copiar el plan a mis otras secciones      docente en la boleta  → MOR-216
   etiquetar la evaluación con lo que      el coordinador de área  → MOR-217
     evalúa                                la nomenclatura del MPPE → MOR-212
   la rúbrica que define el colegio
   el boletín con competencias,            ⚠️ y NO entra tocar la aritmética:
     indicadores y su nivel                   GradeCalculator, activity_grades,
                                              moment_grades y final_grade_books
                                              se quedan como están
```

⚠️ **Y no se sobreconstruye.** Cyndi lo advirtió sin que se le preguntara:
*«hay un montón de cosas que son innecesarias que uno no utiliza, y la gente que
te vende el sistema te ofrece todo eso»*. La versión mínima —guardar el plan,
sugerirlo, reutilizarlo e imprimirlo— es casi todo el valor.

**Lo que NO se construye, aunque aparezca solo:** pesos o ponderación entre
competencias (el Art. 111 no aplica y `MOR-164` ya borró un peso que no
calculaba nada) · catálogo compartido entre colegios · etiquetas y taxonomías ·
flujo de aprobación del plan por la coordinadora · gráficos de progreso.

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿El profesor captura un nivel? | **No captura ninguno: escribe el número.** El nivel de la competencia se DERIVA de las evaluaciones que la etiquetan | ✅ Daniel |
| 2 | ¿Los indicadores se califican? | **No: se imprimen.** Imprimir ≠ calificar | ✅ revisión de UX |
| 2b | ¿Qué pasa si nadie carga un plan? | Nada: **primaria sin competencias sigue funcionando como hoy** | ✅ técnica |
| 3 | ¿De qué cuelga el plan? | De la **SECCIÓN**. Corroborado con Cyndi | ✅ Daniel |
| 4 | ¿Se clona al abrir el año escolar? | **No.** Se SUGIERE cuando el profesor entra a su sección | ✅ Daniel |
| 5 | ¿`NP` es reprobado o «sin evaluar»? | **REPROBADO.** *«El docente está obligado a evaluar»* | ✅ Daniel |
| 6 | ¿Qué se guarda: el número o el nivel? | **El número.** *«Los profesores califican con números»* | ✅ Daniel |
| 7 | ¿La rúbrica es constante o configurable? | **Configurable por colegio.** La define el director al arrancar | ✅ Daniel |
| 8 | ¿De dónde sale la nota del lapso? | **De las evaluaciones, con su peso** — como hoy. Las competencias NO la producen | ✅ Daniel |
| 9 | ¿Para qué sirven entonces las competencias? | Para **mostrarlas en la boleta** con sus indicadores y su nivel | ✅ Daniel |

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

### La rúbrica la define el COLEGIO, al arrancar

Daniel: *«en una etapa inicial se le pregunta al director cuál es la rúbrica…
identificador, código, nombre, descripción y valor. Cuando se le muestra al
representante, se le muestra en función de esa rúbrica»*.

O sea: **tabla por colegio**, no constante. Y es seguro justamente porque es
presentación — cambiarla no reescribe ninguna nota.

⚠️ **`valor` es el PISO de la banda, no su tope ni su punto medio.** Decisión
técnica: con una sola columna, «el nivel más alto cuyo valor no supera la nota»
produce bandas contiguas donde **no puede haber huecos ni solapes**. Con el
valor como tope o como representante, un colegio puede dejar el 16 sin nivel y
nadie se entera hasta que salga una boleta con un renglón en blanco.

```
   código  nombre                   valor        cubre
   ──────  ──────                   ─────        ─────
   PC      Proceso consolidado        19         19-20
   PA      Proceso avanzado           17         17-18
   PI      Proceso intermedio         14         14-16
   PD      Proceso con dificultad     10         10-13
   NP      No cumplió el proceso       1          1-9   ← reprobado
```

El colegio que use **tres** niveles carga tres filas y ya. Su máscara es más
gruesa y **por dentro el 13 y el 17 siguen siendo distintos**, que es la queja
que esto viene a resolver.

**Lo que SIGA propone al arrancar** —el colegio lo cambia— y que coincide banda
por banda con `EscalaLiteral`, que ya existe desde `MOR-129`:

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

### De dónde sale la nota, y para qué sirven las competencias

Daniel lo cerró el 4 de septiembre, y **achica el trabajo a la mitad**:

> *«La nota del lapso viene de la evaluación. ¿Por qué? Porque la evaluación
> tiene una evaluation activity que tiene un peso: yo lo lleno y voy en función
> de ese peso sumando y completando la calificación final del lapso. A su vez,
> eso me sirve para saber quién está completamente calificado… Y en realidad
> **las competencias terminan siendo solo para mostrarlas en la boleta** junto
> con los indicadores y la rúbrica.»*

```
   LA NOTA — como hoy, sin tocar nada
   ──────────────────────────────────
   evaluation_activities (peso)  ──►  activity_grades (número 1-20)
                                            │
                                    GradeCalculator
                                            ▼
                                      moment_grades  ──►  final_grade_books

   LA BOLETA — lo único nuevo
   ──────────────────────────
   la actividad se ETIQUETA con las competencias e indicadores que evalúa
                                            │
                                            ▼
              materia → competencia → indicadores → nivel de rúbrica
```

⚠️ **Consecuencia enorme, y hay que decirla en voz alta: `GradeCalculator` no
se toca, `activity_grades` no se toca, `moment_grades` y `final_grade_books` no
se tocan.** Toda la aritmética del Art. 108 y del 111 sigue exactamente igual.
Lo nuevo es el PLAN y su etiquetado, que son datos descriptivos.

⚠️ **Y con eso desaparecen tres riesgos que este spec traía anotados:**

```
   ✗  GradeCalculator borraba las notas de primaria    en primaria SÍ hay
      («borrar_nota_de_lapso if activities.empty?»)     actividades: no aplica
   ✗  «Quién no cargó notas» se quedaba ciego          sigue funcionando igual
   ✗  origen: :por_competencias                        no hace falta
```

⚠️ **El nivel de una COMPETENCIA sale de las actividades que la evalúan.** Si la
evalúa una sola, es directo. Si la evalúan varias, es el **mismo promedio
ponderado que ya calcula el sistema** — no es una regla inventada, es la del
Art. 111 aplicada a un subconjunto de actividades.

⚠️ **Los indicadores describen; no se puntúan.** El pedido de `MOR-216` —que los
padres entiendan mejor— se resuelve imprimiéndolos. Su nivel es el de su
competencia.

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

**Cargar las notas: la planilla que YA EXISTE.** El profesor sigue escribiendo
números, con el guardado incremental de hoy. No se construye pantalla nueva.

```
   ┌─ TELÉFONO ────────────────────────────────────┐
   │ ←  Prueba de fracciones · 30 %                │
   │    5to Grado B · Matemática · 1er Lapso       │
   │    Evalúa: Resuelve situaciones con           │  ← lo ÚNICO nuevo
   │            fracciones… (2 indicadores)        │     de esta pantalla
   ├───────────────────────────────────────────────┤
   │  (o) ACOSTA PÉREZ, Luis            [ 17 ]  ✓  │
   │  (o) BRICEÑO LARA, Ana Sofía       [ 19 ]  ✓  │
   │  (o) DELGADO GUZMÁN, Camila        [    ]  —  │
   └───────────────────────────────────────────────┘
```

**Al crear la evaluación, se elige qué evalúa.** Es el enganche entre el plan y
la nota, y es un paso más en un formulario que ya existe:

```
   ┌───────────────────────────────────────────────┐
   │  Registrar evaluación · 5to Grado B           │
   │  Matemática · 1er Lapso                       │
   │                                               │
   │  Descripción  [ Prueba de fracciones      ]   │
   │  Peso         [ 30 ] %      (falta 40 %)      │
   │  Fecha        [ 15/11/2026 ]                  │
   │                                               │
   │  Qué evalúa  ── del plan de esta sección ──   │
   │   ☑ Resuelve situaciones con fracciones…      │
   │       ☑ Suma y resta con igual denominador    │
   │       ☐ Compara fracciones                    │
   │   ☐ Resuelve problemas de proporcionalidad…   │
   └───────────────────────────────────────────────┘
```

**Y la boleta** — donde por fin se ven las competencias, que es para lo único
que existen:

```
   Matemática                                    PA
     Resuelve situaciones con fracciones…        PA
       · Suma y resta con igual denominador
       · Compara fracciones
     Resuelve problemas de proporcionalidad…     PC
       · Calcula porcentajes en contextos reales
```

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
      quedan iguales y **editar una no afecta a la otra**.
- [ ] Dado que limpia el plan, entonces se borra **solo si ninguna evaluación
      está etiquetada** con esas competencias; si las hay, se dice qué se
      perdería.
- [ ] Dado un director que arranca, cuando define su rúbrica de tres niveles,
      entonces la boleta usa esos tres — y **ninguna nota guardada cambia**.
- [ ] Dado que un colegio cambia el `valor` de un nivel, entonces **ninguna nota
      guardada cambia**: solo cambia cómo se lee.
- [ ] Dado un alumno con 17 en Matemática, entonces la boleta dice **PA** y el
      alumno sigue teniendo 17 por dentro.
- [ ] Dado un alumno **sin nota** en una evaluación, entonces la boleta escribe
      «Sin evaluar» en letras — nunca NP y nunca cero.
- [ ] Dado un colegio SIN plan de competencias, entonces el boletín sale como
      hoy: **primaria sin competencias sigue funcionando**.
- [ ] Dado bachillerato, entonces todo sigue funcionando exactamente igual.

## 7 · Lo que se puede romper

⚠️ **El boletín de primaria puede salir VACÍO, y no es culpa de este issue.**
`Enrollment#materias_del_boletin` sale de `teacher_sections` o de las
actividades. En primaria **una sola maestra dicta todo**: si el colegio no crea
sus siete `TeacherSection`, los dos términos dan vacío y el boletín queda en
blanco **sin un solo error**. Es lo primero que hay que comprobar contra un
colegio de primaria de verdad.

⚠️ **El guarda de aislamiento NO agarra una tabla sin `school_id`.**
`aislamiento_estructural_test` pregunta «¿qué tablas *tienen* `school_id` y les
falta RLS?». Una tabla **sin la columna** pasa en verde y la lee todo el mundo.
El RLS evalúa columnas de la fila, no asociaciones — es `MOR-85` otra vez.

⚠️ **`validates_same_school` en las DOS asociaciones, no en una.** La
competencia cuelga de una sección y la evaluación de otra: sin la validación
cruzada se etiqueta una actividad con el plan de otro colegio, y queda escrito.
La fuga de lectura se corta arreglando un filtro; el dato cruzado hay que salir
a buscarlo.

⚠️ **Borrar una competencia etiquetada rompe la boleta hacia atrás.** Va
`dependent: :restrict_with_error` y el aviso dice qué se perdería, como
`shared/_borrar`.

⚠️ **Las competencias e indicadores entran al `snapshot` del boletín.** Un
boletín emitido en diciembre tiene que decir lo mismo si se reimprime en marzo,
aunque el texto se haya corregido. Es la misma razón por la que el correo va
congelado en el `Mensaje` (`MOR-186`). Cuesta ~5-10 KB más por boletín.

⚠️ **La rúbrica también entra al snapshot.** Si el colegio la cambia en marzo,
el boletín de diciembre tiene que seguir diciendo «PA» aunque hoy ese 17 se lea
distinto.

⚠️ **Tres comentarios del código quedan mintiendo** el día que esto exista:
`report_card_pdf.rb:203`, `application_helper.rb:67` y `escala_literal.rb` dicen
los tres «hasta que exista MOR-136 se muestra el número». Son promesas escritas;
se cobran en el mismo PR.

⚠️ **Un bug adyacente que este trabajo destapa y no es suyo:**
`report_card_data.rb` usa `grade.escala` y la certificación 31059 usa
`Subject#escala_en(grado)`. «Orientación y Convivencia» de 4to Año sale **en
número en el boletín y en letra en la 31059** — el mismo alumno, dos papeles que
no coinciden. Va en su propio issue, no acá.

## 8 · Cómo se verifica

- `bin/ci` completo antes del PR. ⚠️ **Los 1.159 tests de hoy tienen que pasar
  sin tocar ninguno**: si alguno cambia, es señal de que se tocó la aritmética,
  que es justo lo que este diseño evita.
- Un test que reconstruya **la boleta real de 5to Grado B**: 12 áreas, 31
  competencias con sus niveles, y la nota de promoción. Si el PDF que sale no se
  parece al que el colegio usa hoy, no sirve.
- Un test con **rúbrica de tres niveles**, que es el caso que Cyndi nombró y el
  que rompe cualquier implementación que asuma cinco.
- Test de sistema (Chrome de verdad) para lo que no se ve leyendo el HTML: que
  copiar el plan a otra sección no ate las dos, y que la boleta con competencias
  no desborde a 390 px.
- A mano, con Cyndi delante: cargar un lapso completo y comparar el boletín
  contra el que emite su sistema actual.

## 9 · Lo que quedó cerrado, y cómo

Este spec nació con dos preguntas abiertas. Las dos las cerró Daniel el 4 de
septiembre, y la segunda **redujo el trabajo a la mitad**.

```
   ¿número o nivel?         ──►  NÚMERO. «Los profesores califican con números»
   ¿la nota sale de las     ──►  NO. Sale de las evaluaciones con su peso,
    competencias?                como hoy. Las competencias son para la BOLETA
```

**Lo que eso significa en una línea:** esto **no es** un módulo de evaluación
nuevo. Es el módulo que ya existe, más un **plan descriptivo** que se cuelga de
la sección y se imprime.
