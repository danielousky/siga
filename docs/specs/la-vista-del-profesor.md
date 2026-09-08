# La vista del profesor · etapa ③

> **Estado:** **borrador** — 8 de septiembre de 2026
> **PR:** —
> **Depende de:** [`sistema-de-diseno.md`](sistema-de-diseno.md) (①, entregada) ·
> [`cabecera-unica.md`](cabecera-unica.md) (②, entregada)
>
> ⚠️ **No se congela hasta que Daniel responda las cuatro preguntas abiertas de
> la sección 3.** Todo lo demás ya está decidido en la conversación del 8 de
> septiembre.

---

## 1 · El problema

Daniel, pensando en voz alta sobre el ciclo de vida del docente:

> *«Yo, haciendo un modelo mental, notaba que pareciera que el pivot o el
> elemento central son sus secciones, y el trabajo de él es por sección.»*
> *«Ten presente que lo más importante para los profesores son sus
> estudiantes.»*

Y antes, sobre el menú: *«lo mismo con ese chorrero de secciones, hay que
dividirlas por nivel»*.

**El chorrero es literal, y los datos lo confirman.** De los seeds:

```
  PROFESOR              ASIGNAC.  ÁREAS  GUÍA DE   NIVELES     ¿QUÉ LO DIVIDE?
  ──────────────────────────────────────────────────────────────────────────
  Colmenares, Yubisay        3      3       1      Inicial      nada — 1 sección
  Ochoa, Belkis              5      2       0      Primaria     el área
  García, Carlos            16      1       1      3 niveles    el GRADO, no el área
  Moreno, Sofía             19      3       4      2 niveles    el área Y el grado
```

⚠️ **Cuatro formas distintas, y el árbol que le sirve a uno le estorba al
otro.** Carlos García dicta **una sola área** en dieciséis secciones: para él una
rama «Matemática» es un renglón que no decide nada. Sofía Moreno dicta tres
áreas, guía cuatro secciones — y **guía 1er Grado A y también dicta ahí**, y
guía 1er Año B donde además dicta *dos* áreas.

Hoy los dos ven la misma lista plana de quince o dieciséis renglones seguidos.

## 2 · Qué NO entra

```
   ENTRA                                NO ENTRA
   ─────                                ────────
   el sidebar con la regla de colapso   el modelo. Nada de esto cambia una
   la pantalla de sección y sus         tabla: es cómo se MUESTRA lo que ya
     pestañas                           existe

   la vista de calificar con los tres   las estadísticas por edad y sexo —
     estados de columna                 «de último, es un plus» (Daniel).
                                        Y cruzar rendimiento con sexo en la
   el móvil: la planilla como           pantalla de un docente es una lectura
     entrada natural                    que un colegio no quiere impresa

   replicar la planificación a las      los documentos de identidad — es la
     secciones hermanas (falta para     etapa ④, transversal a los 4 roles
     evaluaciones; ya existe para
     competencias)                      la rúbrica: se deja aparte por ahora
```

⚠️ **Una cosa sí toca estructura, y es pequeña:** si el camino principal es el
área, el destino deja de ser `/secciones/:id` y pasa a ser **la asignación**
(sección × área). Es una ruta nueva, no una tabla nueva.

## 3 · Las decisiones

### Tomadas

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿La fecha de una evaluación cierra su columna? | **No. Ordena y da foco, nunca bloquea.** Un campo que se cierra al pasar su fecha deja fuera al profesor que carga tarde — que es el caso normal, y lo descubre un domingo a las nueve | Claude propuso, **Daniel de acuerdo** |
| 2 | ¿Molesta que una sección aparezca en «guía» y en «dicto»? | **No.** Son dos trabajos distintos: como guía entro a la SECCIÓN (asistencia, boletín); como docente de un área entro a una ASIGNACIÓN | Daniel: *«no importa que se dupliquen, es entendible y no se siente como un bug»* |
| 3 | ¿Cómo se llega a una sección? | **Navegando por el ÁREA.** La rama «lo que dicto» es el camino principal, y el clic trae área y sección juntas | Daniel |
| 4 | ¿Las estadísticas? | **De último. Es un plus, no bloquea nada** | Daniel |
| 5 | ¿Replicar a las hermanas? | **Sí.** Ya existe para competencias; falta para evaluaciones | Daniel |
| 6 | ¿Documentos de identidad? | **Sí, y probablemente para los cuatro roles.** Docente: cédula, foto de perfil y **RIF**. Va en la etapa ④ | Daniel |

### ⚠️ Abiertas — el spec no se congela sin estas

| # | Pregunta | Por qué importa |
|---|----------|-----------------|
| A | ¿Cómo se llaman las dos ramas del sidebar? Propuesta: **«Soy guía de»** y **«Dicto»** | Son las dos palabras que el docente va a leer todos los días. «Mi grupo», «Mi sección», «Mis áreas» son alternativas |
| B | Un profesor **sin ninguna sección guía** (Ochoa, Quintero, Silva) ¿ve la rama vacía, o no la ve? | Esconderla es un menú que cambia de forma entre dos docentes del mismo colegio; mostrarla vacía es un renglón que no lleva a nada |
| C | Las pestañas de la sección: **Calificar · Asistencia\* · Planificación · Alumnos**. ¿Ese orden? ¿Falta alguna? | El orden es la frecuencia de uso, y la de asistencia solo aparece para el guía |
| D | ¿El profesor puede ver **años anteriores** de sus secciones? | Hoy no tiene selector de año, y fue decisión tuya: *«los docentes no deberían necesitar ni siquiera ver algo anterior, solo lo que están calificando»*. Con el sidebar nuevo la pregunta vuelve |

## 4 · El dominio

- **Quién califica:** el profesor del área. *«Califica el profe de la materia.
  Incluso el guía, al final, deben asignársele las áreas… ese comportamiento es
  igual que en la educación media: guía + áreas asignadas»* (Daniel, ratificado
  con Cyndi). O sea que «¿qué califica esta persona?» ya tiene respuesta en el
  modelo: sus `teacher_sections`.
- **Quién pasa lista:** solo el **guía**, y de la sección entera — sin área.
- **La unidad de trabajo NO es la sección: es (sección × área × lapso).** Sofía
  dicta dos áreas en 1er Año B, y su planificación y su calificación son
  distintas en cada una.

⚠️ **Lo que parece razonable y está mal:** que «el pivote es la sección» a
secas. La sección es el pivote de **navegación**; la unidad de trabajo lleva el
área adentro. Decir solo lo primero deja viva la ambigüedad que hoy obliga a la
libreta a volver a preguntar el área con pastillas.

⚠️ **Y lo segundo:** encadenar planificación → asistencia. La asistencia empieza
el primer día de clases, esté o no la planificación lista. Son 2‖3, no 2→3.

## 5 · Cómo se ve

### El sidebar, con la regla de colapso

> **un escalón aparece solo si divide algo.** Con una opción no decide nada y
> agrega un renglón que hay que leer. Es la misma regla de las pastillas y del
> selector de nivel.

```
  CARLOS GARCÍA                SOFÍA MORENO                YUBISAY COLMENARES
  1 área · 16 secciones        3 áreas · 19 asignaciones   1 sección · 3 áreas
  ─────────────────────        ─────────────────────────   ───────────────────
  ▾ SOY GUÍA DE                ▾ SOY GUÍA DE               ▾ SOY GUÍA DE
      4to Grado – A ✓              1er Grado – A ◷             1er Nivel – A ◷
                                   5to Grado – A ✓
  ▾ DICTO                          1er Año  – B !          (sin «DICTO»: es la
    ┌ el área colapsa:             4to Año  – A ▤           misma sección)
    │ solo dicta una ┐         ▾ DICTO
      ▸ 1er Grado  A  B            ▾ Educación Estética
      ▸ 2do Grado  A  B                ▸ 1er Grado  A  B
      ▸ 3er Grado  A                   …
      ▾ 4to Grado                  ▾ Arte y Patrimonio
          A ✓   B ◷                    ▾ 1er Año
      ▸ 5to Grado  A                       A ◷   B !
      ▸ 6to Grado  A               ▾ Grupo de Creación…
                                       ▸ 1er Año   A  B
  (nivel = Primaria, arriba)
```

Los iconos son los de la etapa anterior: ✓ al día · ◷ le faltan · **!** sin
ninguna nota · ▤ sin evaluaciones todavía.

**Lo que cuesta hoy vs lo que costaría:**

```
  Carlos → calificar 4to Grado A
     hoy   1 clic entre 16 renglones seguidos + pestaña + pastilla de lapso
     nuevo 2 clics (4to Grado → A), y llega con área y sección puestas

  Sofía → calificar Arte y Patrimonio en 1er Año B
     hoy   1 clic entre 15 + pestaña + pastilla ÁREA + pastilla lapso = 4,
           y tiene que saber de memoria que ahí dicta dos áreas
     nuevo 3 clics, sin ambigüedad posible
```

### La sección

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Ed. Estética · 4to Grado – A            [ Volver ]  [ 22 alumnos ]  │
  │  ──────────────────────────────────────────────────────────────────  │
  │   Calificar │ Asistencia │ Planificación │ Alumnos                   │
  │   ─────────    ▲                                                     │
  │                └── SOLO si soy guía de esta sección                  │
  │                                                                      │
  │   LAPSO   [ 1er Lapso ] 2do Lapso   3er Lapso                        │
  │                                                                      │
  │   ┌────────────────┬─────────┬─────────┬─────────┬─────────┬──────┐  │
  │   │                │ Diag.   │ Taller  │ Examen  │ Proy.   │      │  │
  │   │  ALUMNO        │ 10 %    │ 30 %    │ 40 %    │ 20 %    │LAPSO │  │
  │   │                │ 15 sep  │ 04 oct  │ 08 nov  │ 02 dic  │      │  │
  │   │                │ ✓ 22/22 │ ◷ 14/22 │ ▤  hoy  │ ▫ 25 d. │      │  │
  │   ├────────────────┼─────────┼─────────┼─────────┼─────────┼──────┤  │
  │   │ Aponte, Eduardo│   20    │   18    │  [  ]   │    —    │  19  │  │
  │   │ Cabrera, Tomás │   14    │   16    │  [  ]   │    —    │  15  │  │
  │   └────────────────┴─────────┴─────────┴─────────┴─────────┴──────┘  │
  │                        ▲                   ▲          ▲              │
  │           atrasada: lo más ────┘           │          └── futura,    │
  │           visible, NO cerrada        la de hoy            atenuada   │
  └──────────────────────────────────────────────────────────────────────┘
```

### Los tres estados de columna (decisión 1)

```
   PASADA sin cargar   ▤   la más visible — es lo que hay que hacer HOY
   EN CURSO            ◐   abierta, resaltada
   FUTURA              ▫   atenuada y con la cuenta de días, pero ESCRIBIBLE
                           (una evaluación se puede adelantar)
```

### El teléfono

```
  ESCRITORIO                        TELÉFONO
  ──────────                        ────────
  alumno × evaluación               UNA evaluación, todos los alumnos
  para MIRAR y ajustar              para CARGAR
                                    ┌───────────────────────┐
  la libreta, que ya existe         │ ◂ Examen · 08 nov     │
                                    │   40 % · 14 de 22     │
                                    ├───────────────────────┤
                                    │ Aponte, Eduardo  [18] │
                                    │ Cabrera, Tomás   [16] │
                                    └───────────────────────┘
                                    la planilla, que ya existe
```

⚠️ **Las dos ya están construidas.** El trabajo no es inventarlas: es que el
teléfono entre por la planilla y el escritorio por la libreta, y que un toque en
una columna lleve a la planilla de esa evaluación.

## 6 · Criterios de aceptación

- [ ] Dado un profesor de una sola área, cuando abre el menú, entonces **no**
      ve una rama de área: ve sus grados directamente.
- [ ] Dado un profesor de tres áreas, entonces ve las tres como ramas.
- [ ] Dado un profesor con una sola sección, entonces no ve ningún escalón
      intermedio: ve la sección.
- [ ] Dado un profesor que guía una sección y además dicta ahí, entonces esa
      sección aparece en las dos ramas, y cada una lleva a una pantalla que
      dice cuál de los dos trabajos es.
- [ ] Dado que entro por «Dicto → Matemática → 4to Grado → A», entonces la
      pantalla llega con el área puesta y **no** vuelve a preguntarla.
- [ ] Dado que no soy guía de una sección, entonces esa pantalla **no** tiene
      pestaña de Asistencia.
- [ ] Dada una evaluación cuya fecha ya pasó y no está completa, entonces su
      columna es la más visible — y **se puede escribir en ella**.
- [ ] Dada una evaluación futura, entonces su columna está atenuada y **se
      puede escribir en ella**.
- [ ] Dado un teléfono de 390 px, entonces la página **no** se corre de lado.

## 7 · Lo que se puede romper

⚠️ **La sección que más tiempo ahorra.**

- **`MenuHelper#grupo_de_mis_secciones`** cambia de forma entera. Sus tests
  —`menu_del_profesor_test`— asumen una lista plana agrupada por nivel.
- **`enlace_activo?`** compara el `:id` de la ruta desde el 7 de septiembre. Con
  un destino que ya no es `/secciones/:id` sino una asignación, hay que revisar
  que siga marcando UNA sola entrada.
- **El avance por sección** (`estado_de_calificacion`) hoy toma **el peor de sus
  áreas**. Con el árbol por área, cada hoja tiene su propio estado y el de la
  sección deja de tener sentido en la rama «Dicto» — pero lo sigue teniendo en
  «Soy guía de».
- **`LibretaDeLaSeccion`** ya recibe `(seccion, materia, lapso)`: no cambia. Lo
  que cambia es quién se los pasa.
- **Guardas que pueden dejar de guardar en silencio:** cualquier test que
  navegue a `section_path(...)` y espere encontrar las pastillas de área. Si el
  área viene en la ruta, esas pastillas desaparecen y un `assert_select` con
  `count: 0` pasaría sin probar nada.

## 8 · Cómo se verifica

`bin/ci` completo, y además:

- **Los cuatro perfiles reales de los seeds**, uno por uno: Colmenares (1
  sección), Ochoa (2 áreas, sin guía), García (1 área, 16 secciones, 3 niveles)
  y Moreno (3 áreas, 4 guías). Son las cuatro formas del árbol, y ninguna es
  hipotética.
- **En navegador**, porque el árbol plegable es Stimulus y en este proyecto
  Stimulus ya falló dos veces en silencio.
- **A 390 px**, con el test de desborde que ya existe.
