# Educación Inicial: se describe, no se califica

> **Estado:** **congelado** — 10 de septiembre de 2026
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
| 1 | ¿Cómo se evalúa? | **La calificación de cada área es un TEXTO.** Ni 1–20, ni A/B/C, ni la rúbrica PC/PA/PI | Daniel |
| 2 | ¿Hay que planificar? | **No.** No hay evaluaciones ni ponderación: se califica directo | Daniel |
| 3 | ¿Y el resultado del año? | **Aprobó, directo.** «Prácticamente con asistir al colegio» | Daniel |
| 4 | Si hay una condición particular, ¿dónde se dice? | **En el mismo texto.** El docente lo sugiere ahí; no hay marca aparte | Daniel |
| 5 | ¿Qué pestañas tiene la sección? | **Asistencia · Calificar · Alumnos.** Desaparece Planificar | Daniel |
| 6 | ¿Se sigue llamando «Calificar»? | **Sí por ahora** | Daniel |
| 7 | ¿Dónde se guarda ese texto? | **En `moment_grades`**, con la nota numérica nullable — ver § 4 | Daniel |
| 8 | ¿Y el informe descriptivo de la boleta? | **No se toca.** Uno por inscripción y lapso, opcional, sin área | Daniel |

## 4 · El dominio

**En Educación Inicial la calificación es descriptiva.** Daniel, 10 de
septiembre: *«los niños en Inicial no sacan ni A, ni B, ni C, ni PC, ni AP, ni
5, ni 20, entonces la calificación es descriptiva»*.

```
   LO QUE NO HAY                      LO QUE SÍ HAY
   ─────────────                      ─────────────
   ponderación                        un TEXTO por área y lapso
   evaluaciones con peso              el resultado del año: aprobó
   escala de ningún tipo                ▲ directo, «prácticamente con
   promedio                               asistir al colegio»
```

⚠️ **Y el informe descriptivo de la boleta es OTRA cosa, y ya existe.** Es uno
por `(inscripción, lapso)`, opcional, sin área, escrito por el guía — el mismo
para los tres niveles, tal como está desde `MOR-216`. Lo confirmó Daniel: *«es
un campo por inscripción por lapso el cual NO ESTÁ ASOCIADO AL ÁREA»*.

Su origen es una boleta real de Cyndi, de primaria, donde ese bloque ya existe.

```
   informes ──  enrollment · lapso · cuerpo        ← NO SE TOCA
                  ▲ el general, opcional, de la boleta

   moment_grades ──  enrollment · lapso · área · …  ← acá va lo de Inicial
```

### El texto vive en `moment_grades`, con la nota nullable

```
   HOY                                   QUEDA
   ───                                   ─────
   final_moment_score  NOT NULL          final_moment_score  nullable   1..20
                                         descripcion         nullable   texto
                                           ▲ uno u otro, según el nivel
```

⚠️ **Una sola tabla y no una aparte para Inicial**, porque la boleta, el
historial, la promoción y la certificación 31059 leen `moment_grades`: con dos
tablas, cada una de esas pantallas tendría que preguntar de qué nivel es el
alumno antes de saber dónde mirar.

⚠️ **El precio, y es el riesgo real:** una columna que hoy NUNCA es nula pasa a
poder serlo. Todo lo que hace cuentas con `final_moment_score` sin comprobar
que existe se rompe con el primer alumno de Inicial. Es grepeable, y está en § 7.

⚠️ Curiosidad del esquema que conviene saber: el `CHECK` **ya contempla el
nulo** —`score IS NULL OR score BETWEEN 1 AND 20`— y era la columna la que lo
prohibía. La migración solo quita el `NOT NULL`.

## 5 · Cómo se ve

```
   ┌─ 1er Nivel · Sección U ─────────────────────── Educación Inicial ──┐
   │  Asistencia · Calificar · Alumnos                                  │
   │   ▲ sin Planificar: no hay nada que ponderar                       │
   │                                                                    │
   │  LAPSO   [1er Lapso] 2do Lapso  3er Lapso                          │
   │                                                                    │
   │  Bastidas Bermúdez, Valeria                                        │
   │    FORMACIÓN PERSONAL Y SOCIAL                                     │
   │    ┌─────────────────────────────────────────────────────────────┐│
   │    │ Se integró al grupo con facilidad y comparte los materiales.││
   │    └─────────────────────────────────────────────────────────────┘│
   │    RELACIÓN CON EL AMBIENTE                                        │
   │    ┌─────────────────────────────────────────────────────────────┐│
   │    │ escribe la valoración…                                      ││
   │    └─────────────────────────────────────────────────────────────┘│
   │    COMUNICACIÓN Y REPRESENTACIÓN                                   │
   │    ┌─────────────────────────────────────────────────────────────┐│
   │    │ …                                                           ││
   │    └─────────────────────────────────────────────────────────────┘│
   │                                                                    │
   │  Blanco Mendoza, Diego                                             │
   │    …                                                               │
   │  guardado automático · 16 niños en una pantalla                    │
   └────────────────────────────────────────────────────────────────────┘
```

⚠️ **Todos los niños en UNA pantalla**, como la planilla de notas y la de
informes. Con una pantalla por niño son treinta y dos clics de navegación
además de lo que escribe, y el trabajo se abandona a la mitad.

## 6 · Criterios de aceptación

- [ ] Dada una sección de Educación Inicial, cuando un profesor la abre,
      entonces ve **Asistencia · Calificar · Alumnos** y ninguna pestaña de
      planificación.
- [ ] Dada esa sección, cuando alguien pide `/secciones/:id/planificar` a mano,
      entonces va a Calificar — no a una pantalla que pide ponderación.
- [ ] Dada una sección de Inicial, entonces **no se puede crear una evaluación**
      en ella, ni desde la pantalla ni por POST directo.
- [ ] Dada la pestaña Calificar de Inicial, entonces se ve **un campo de texto
      por alumno y por área**, y ningún campo numérico.
- [ ] Dada una valoración escrita, cuando se recarga la pantalla, entonces sigue
      ahí — guardado incremental, como la planilla de notas.
- [ ] Dado un grado que NO es de Inicial, entonces su nota sigue siendo
      obligatoria y entre 1 y 20.
- [ ] Dadas primaria y Media, entonces **nada cambia**.

## 7 · Lo que se puede romper

⚠️ **La sección que más tiempo ahorra.**

- **`final_moment_score` pasa a ser nullable**, y hoy NUNCA lo es. Todo lo que
  haga cuentas con esa columna sin comprobar que existe se rompe con el primer
  alumno de Inicial: `GradeCalculator`, el boletín, la certificación 31059, el
  panel del alumno, «quién no cargó notas» y la promoción. Es grepeable y hay
  que recorrerlo entero.
- **`Grade#por_competencias?` es `primaria?`**, así que Inicial y Media caen
  juntas en el mismo `false`. Cualquier `if` que diga «no es primaria» y asuma
  bachillerato **se equivoca con Inicial**. Hace falta una pregunta propia
  —`califica_con_texto?`— y no un `unless primaria?`. Esa misma trampa mordió
  dos veces el 10 de septiembre, con el filtro de competencias.
- **El promedio del lapso y el del año** no deben calcularse en Inicial. Un job
  que intente promediar textos debe no hacer nada, no fallar.
- **`Subscription.matricula_de` cuenta inscripciones**, y las de Inicial cuentan
  igual: esto no puede tocar la facturación.
- **El portal del representante** dice «Calificaciones de 1er lapso». Para un
  niño de Inicial hay que ver qué muestra ahí: queda fuera del alcance (§ 2)
  pero **no puede reventar**.
- **La promoción al año siguiente** deduce de las notas definitivas. En Inicial
  aprueban todos: hay que comprobar que no queden en «SIN DATOS» para siempre.

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
