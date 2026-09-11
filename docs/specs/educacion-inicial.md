# Educación Inicial: se describe, no se califica

> **Estado:** **propuesto** — 10 de septiembre de 2026
> **Depende de:** `MOR-216` (informe descriptivo, implementado) · la vista del
> profesor (implementada)
> **Pedido por Daniel:** *«vamos con la vista de evaluación de Educación Media e
> Inicial»*. Media se resolvió el mismo día; esto es la otra mitad.

---

## 1 · El problema

Un colegio venezolano con los tres niveles tiene **diez secciones de Educación
Inicial** —1er, 2do y 3er Nivel— y hoy sus maestras entran a la misma pantalla
que un profesor de Matemática de bachillerato.

```
   LO QUE VE HOY LA MAESTRA DE 1ER NIVEL

   ┌─ 1er Nivel · Sección A · Formación Personal y Social ─────────┐
   │  Calificar · Planificar · Alumnos                             │
   │                                                               │
   │  PONDERACIÓN · 1ER LAPSO            0 % · 100 % sin repartir  │
   │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │
   │                                                               │
   │  Empieza por las evaluaciones: cada una con su peso y su      │
   │  fecha. Entre todas tienen que repartir el 100 % del lapso.   │
   └───────────────────────────────────────────────────────────────┘
```

**Nada de eso existe en Educación Inicial.** No hay evaluaciones, no hay
ponderación, no hay nota del 1 al 20 y no hay promedio. Hay un **informe
descriptivo por área**, y ese es todo el registro de evaluación del nivel.

⚠️ La pantalla no está «incompleta»: está **pidiendo datos que no deben
existir**. Una maestra que la tome en serio va a inventar un «Examen 40 %» para
un niño de cuatro años, y eso queda en la base y sale en la boleta.

## 2 · Qué NO entra

```
   ENTRA                                NO ENTRA
   ─────                                ────────
   las pestañas de la sección           el boletín de Inicial en PDF
   la planilla de informes              la rúbrica por áreas de desarrollo
   el menú del profesor                 el portal del representante
   qué ve la dirección                  migrar los datos que ya existan
```

⚠️ **El boletín en PDF queda fuera a propósito.** Es papel con formato del
MPPE, se discute con un colegio delante y merece su propio issue; lo de acá es
que la maestra pueda REGISTRAR. Sin registro, el papel no tiene qué imprimir.

⚠️ Y **no hay datos que migrar**: en los seeds hay 10 secciones de Inicial con
**0 evaluaciones y 0 informes**. Es un nivel que todavía nadie usó.

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Cómo se evalúa? | **Solo informe descriptivo.** Sin notas, sin ponderación, sin promedio | Daniel |
| 2 | ¿El informe es uno por alumno o uno por área? | **Uno por ÁREA** — ver § 4 | ⚠️ falta |
| 3 | ¿Qué pestañas tiene la sección? | **Informes · Asistencia · Alumnos.** Desaparecen Calificar y Planificar | Daniel |
| 4 | ¿Quién lo escribe? | La maestra de la sección y la dirección, como en `MOR-216` | Claude |
| 5 | ¿Y el menú del profesor? | Una sección de Inicial lleva a Informes, no a Calificar | Claude |

## 4 · El dominio

**El currículo de Educación Inicial de Venezuela tiene tres áreas**, y el pensum
del colegio ya las trae cargadas:

```
   FORMACIÓN PERSONAL Y SOCIAL
   RELACIÓN CON EL AMBIENTE
   COMUNICACIÓN Y REPRESENTACIÓN
```

⚠️ **Acá está la única decisión abierta, y es la que ordena el modelo.**

El `Informe` de hoy (`MOR-216`) es **uno por (inscripción, lapso)** — hay un
índice único que lo garantiza. Nació para primaria y bachillerato, donde el
informe lo escribe el **guía**, que es uno solo y ve al alumno entero.

En Inicial la maestra escribe sobre las tres áreas, y hay dos formas:

```
   A · UNO SOLO, como hoy              B · UNO POR ÁREA
   ────────────────────                ────────────────
   «Valeria se integró al grupo        Formación Personal y Social
    con facilidad, reconoce los          «Valeria se integró al grupo…»
    colores primarios y…»              Relación con el Ambiente
                                         «Reconoce los colores…»
   un texto, tres áreas mezcladas      Comunicación y Representación
   el modelo NO cambia                   «Se expresa con frases de…»

                                       el modelo cambia: el índice único
                                       pasa a (inscripción, lapso, área)
```

⚠️ **La boleta del MPPE tiene las tres áreas separadas.** Con la opción A, al
imprimir hay que partir un texto que nadie escribió para ser partido — o
imprimir el mismo párrafo tres veces.

⚠️ Y al revés: con la opción B son **tres campos por niño y lapso**, o sea
**setenta y cinco textos** por sección y lapso en vez de veinticinco. Es lo que
la ley pide y es mucho trabajo; la planilla de `MOR-216` está pensada para eso
—todos en una pantalla, guardado incremental— pero no lo hace menos.

**La decisión es de Daniel** porque depende de qué boleta emite su colegio.

## 5 · Cómo se ve

```
   ┌─ 1er Nivel · Sección A ───────────────────────── Educación Inicial ─┐
   │  Informes · Asistencia · Alumnos                                    │
   │   ▲ sin Calificar ni Planificar: en Inicial no hay notas            │
   │                                                                     │
   │  LAPSO   [1er Lapso] 2do Lapso  3er Lapso                           │
   │                                                                     │
   │  ┌───────────────────────────────────────────────────────────────┐ │
   │  │ Bastidas Bermúdez, Valeria                                    │ │
   │  │                                                               │ │
   │  │ FORMACIÓN PERSONAL Y SOCIAL                                   │ │
   │  │ ┌───────────────────────────────────────────────────────────┐ │ │
   │  │ │ Valeria se integró al grupo con facilidad y comparte los  │ │ │
   │  │ │ materiales sin que haya que pedírselo.                    │ │ │
   │  │ └───────────────────────────────────────────────────────────┘ │ │
   │  │ RELACIÓN CON EL AMBIENTE                                      │ │
   │  │ ┌───────────────────────────────────────────────────────────┐ │ │
   │  │ │ escribe el informe…                                       │ │ │
   │  │ └───────────────────────────────────────────────────────────┘ │ │
   │  └───────────────────────────────────────────────────────────────┘ │
   │  guardado automático · 25 niños en una pantalla                     │
   └─────────────────────────────────────────────────────────────────────┘
```

Y el vacío de una sección de Inicial a la que se llegue por otra vía:

```
   Todavía no hay informes en 1er lapso

   En Educación Inicial no hay calificaciones: lo que queda registrado es
   un informe descriptivo por área.  [→ Escribir los informes]
```

## 6 · Criterios de aceptación

- [ ] Dada una sección de Educación Inicial, cuando un profesor la abre,
      entonces ve **Informes · Asistencia · Alumnos** y ninguna pestaña de
      notas.
- [ ] Dada esa sección, cuando alguien pide `/secciones/:id/planificar` o
      `/secciones/:id` a mano, entonces va a Informes — no a una pantalla que
      pide ponderación.
- [ ] Dada una sección de Inicial, entonces **no se puede crear una evaluación**
      en ella, ni desde la pantalla ni por POST directo.
- [ ] Dado el menú del profesor, cuando dicta en Inicial, entonces su sección
      lleva a Informes.
- [ ] Dado un grado de Inicial, entonces su `escala` deja de ofrecerse: no se
      califica, así que no hay escala que elegir.
- [ ] Dadas primaria y Media, entonces **nada cambia**.

## 7 · Lo que se puede romper

⚠️ **La sección que más tiempo ahorra.**

- **`Grade#por_competencias?` es `primaria?`**, así que hoy Inicial y Media
  caen juntas en el mismo `false`. Cualquier `if` que hoy diga «no es primaria»
  y asuma bachillerato **se equivoca con Inicial**. Hace falta una pregunta
  propia —`solo_descriptivo?`— y no un `unless primaria?`.
- **El boletín y la certificación 31059 leen `MomentGrade`**, que en Inicial no
  va a existir. Hay que comprobar qué hacen esas pantallas con una sección sin
  ninguna nota: si revientan, el colegio no puede emitir NADA del año.
- **`Subscription.matricula_de` cuenta inscripciones**, y las de Inicial cuentan
  igual: esto no puede tocar la facturación.
- **Los promedios y `GradeCalculator`** no deben correr para Inicial. Un job que
  intente calcular un promedio sin notas debe no hacer nada, no fallar.
- **El portal del representante** muestra «Calificaciones de 1er lapso». Para un
  niño de Inicial ese título es falso: no hay calificaciones. Queda fuera del
  alcance (§ 2) pero **hay que verificar que no reviente**.

## 8 · Cómo se verifica

`bin/ci` completo, y un recorrido con navegador sobre la base de desarrollo —que
ya tiene diez secciones de Inicial— entrando como profesor y como director:

```
   /secciones/:inicial            →  Informes, sin pestañas de notas
   /secciones/:inicial/planificar →  redirige a Informes
   POST /evaluaciones             →  rechazado para una sección de Inicial
   /boletines                     →  no revienta con una sección de Inicial
   /representante/hijo/:id        →  no revienta
```
