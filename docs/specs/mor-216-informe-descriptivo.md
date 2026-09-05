# MOR-216 · El informe descriptivo del docente

> **Estado:** **propuesto** — 5 de septiembre de 2026, 00:35
> **Issue:** [MOR-216](https://linear.app/morosdevelopment/issue/MOR-216) · proyecto «SIGA · Módulo de evaluación»
> **Depende de:** `MOR-136`, ya implementado
>
> ⚠️ Daniel duerme. Las tres decisiones de abajo están tomadas **con la
> evidencia que ya hay** y marcadas para que las confirme o las corrija; la
> forma del modelo aguanta las dos respuestas en dos de las tres.

---

## 1 · El problema

La boleta dice **cuánto** sacó el niño. No dice **cómo le fue**.

Cyndi, describiendo lo que su sistema actual ya hace:

> *«A cada estudiante le agregamos… tiene una parte por donde uno coloca el
> informe descriptivo. Al final de la boleta tiene algo descriptivo que uno le
> escribe. Esa es la parte que genera con las calificaciones, y luego el informe
> descriptivo de su rendimiento del lapso.»*

Y de la jornada del 3 de septiembre:

> *«Se podría incluir un apartado de comentarios del docente para brindar
> retroalimentación más personalizada.»*

**Es lo que hace que una boleta de primaria se lea como un boletín y no como
una factura.** Un «PA» le dice a una madre en qué banda cayó su hijo; el
informe le dice que se distrae al final de la mañana pero que lee mejor que en
octubre.

## 2 · Las tres decisiones

| # | Pregunta | Decisión | Con qué evidencia |
|---|----------|----------|-------------------|
| 1 | ¿Uno por lapso o uno por materia? | **Uno por lapso** | *«el informe descriptivo de su rendimiento del lapso»* — Cyndi, en singular. Y en la boleta real del Teresiano va **uno, al final** |
| 2 | ¿Quién lo escribe? | **El profesor guía de la sección** | En primaria una sola maestra dicta todo, así que es ella. En bachillerato son doce profesores y ninguno ve al alumno entero — el guía sí. Ya existe: `Section#leader_teacher` (MOR-209) |
| 3 | ¿El indicador lleva su propio nivel? | **No: describe** | Cerrado en `MOR-136`. Su nivel es el de su competencia, y ya está implementado |

⚠️ **La 1 y la 2 son de Daniel y él duerme.** La 1 aguanta un cambio barato —de
uno por lapso a uno por materia es agregar `subject_id` a la clave— y la 2
también: `escrito_por` ya se guarda, así que ampliar quién puede escribirlo es
una línea en el controller. La 3 ya está decidida por él.

## 3 · Qué NO entra

```
   ENTRA                                NO ENTRA
   ─────                                ────────
   escribirlo por sección, en una       plantillas o frases sugeridas
     planilla como la de notas          corrección de estilo automática
   verlo en la boleta y en el PDF       un informe por materia (ver decisión 1)
   verlo la familia en su portal        adjuntos, fotos, audios
   que quede congelado al emitir        el informe de Educación Inicial → MOR-218
```

⚠️ **Educación Inicial NO entra**, aunque suene igual. Ahí el informe **sustituye
a la calificación** —no la acompaña— y se escribe por áreas de formación sin
mencionar los componentes. Eso es `MOR-218` y es otra pantalla.

## 4 · El modelo

```
   enrollments ──┐
                 ├──► informes            (uno por alumno y lapso)
   evaluation_   ┘        · cuerpo
     moments               · escrito_por  → users
                           · school_id    → RLS

⚠️ **Se llama `informes`, de una sola palabra.** `informes_del_lapso` no
sirve: `"informe_del_lapso".pluralize` da «informe_del_lapsos» —Rails pluraliza
la última palabra y acá manda la primera—. Un nombre de una palabra lo evita
sin agregarle una inflexión irregular al proyecto.
```

⚠️ **Tabla propia y no una columna en `report_cards`.** El boletín se EMITE y
queda congelado; el informe se escribe **durante** el lapso y se corrige hasta
que se emite. Meterlo en el boletín obligaría a emitir para poder escribir.

⚠️ **`school_id` explícito**, como todo: el RLS evalúa columnas de la fila, no
asociaciones. Y el guarda de aislamiento **no detecta una tabla sin la
columna** — pregunta «¿qué tablas tienen `school_id` y les falta RLS?», así que
una tabla sin ella pasa en verde y la lee todo el mundo.

## 5 · Cómo se ve

**Escribirlo** — una planilla por sección, como la de notas:

```
   ┌─ Informes descriptivos · 4to Grado A · 1er Lapso ──────────────┐
   │                                                                │
   │  ACOSTA PÉREZ, Luis                            PA · 17         │
   │  ┌──────────────────────────────────────────────────────────┐  │
   │  │ Luis mejoró mucho su lectura en voz alta este lapso.     │  │
   │  │ Se distrae al final de la mañana; conviene sentarlo      │  │
   │  │ adelante.                                          ✓     │  │
   │  └──────────────────────────────────────────────────────────┘  │
   │                                                                │
   │  BRICEÑO LARA, Ana Sofía                       PC · 19         │
   │  ┌──────────────────────────────────────────────────────────┐  │
   │  │ Escribe aquí cómo le fue en el lapso…                    │  │
   │  └──────────────────────────────────────────────────────────┘  │
   └────────────────────────────────────────────────────────────────┘
```

⚠️ **El promedio del alumno va al lado**, y no es decorado: la maestra escribe
veinticinco informes seguidos y necesita recordar de quién habla sin salir de
la pantalla.

**En la boleta**, al final, después de las materias — como en la del Teresiano.

## 6 · Criterios de aceptación

- [ ] El guía de la sección escribe un informe por alumno y lapso, y se guarda
      solo mientras escribe (como la planilla de notas).
- [ ] Un profesor que NO es guía de esa sección no llega a la pantalla.
- [ ] La dirección sí llega, y puede escribir: una sección sin guía tiene que
      poder tener informes.
- [ ] El informe sale en la boleta y en el PDF, al final.
- [ ] La familia lo ve en su portal.
- [ ] Un boletín emitido **congela** el informe: corregirlo después no cambia el
      papel que ya se entregó.
- [ ] Una sección sin informes saca la boleta como hoy.
- [ ] El informe de otro colegio no se lee ni se escribe.
