# Cómo se trabaja un issue

Daniel, 3 de septiembre de 2026:

> *«Quisiera que tuviéramos una metodología de trabajo en la que, antes de echar
> la primera línea de código, pensemos muy bien lo que vamos a ejecutar y tengamos
> total claridad de lo que se quiere… de modo que cuando llegue el momento de
> escribir, ya esté trazada la hoja de ruta del issue.»*

```
   1  ISSUE en Linear        el PROBLEMA, no la solución
              │
   2  SPEC en docs/specs/    qué se construye y cómo se sabrá que quedó bien
              │              ├─ se discute
              │              └─ se CONGELA  ← antes de la primera línea
   3  RAMA + PR              el código que cumple el spec
              │              └─ bin/ci en verde antes de abrirlo
   4  MERGE + DESPLIEGUE
```

## Por qué el spec, y no solo el issue

Un issue dice *qué molesta*. Un spec dice *qué se va a construir, qué queda
afuera, y cómo se sabrá que quedó bien*. La diferencia se paga en las decisiones:
sin spec se toman mientras se escribe el código —apuradas, por quien está
tecleando— y quedan enterradas en un commit.

⚠️ **La sección que más tiempo ahorra es «Lo que se puede romper».** Casi todo lo
que costó tiempo en este proyecto no fue escribir la función nueva: fue lo que
esa función movió sin que nadie lo previera —una validación que ya no aplica, un
test que dejó de probar, una regla de CSS que quedó apuntando a una clase que se
borró.

## Cuándo NO hace falta un spec

Cuidado con el otro extremo: un spec para todo es burocracia y se deja de leer.

```
   CON SPEC                        SIN SPEC
   ────────                        ────────
   una funcionalidad nueva         un texto que se corrige
   un cambio de modelo             un color, un margen
   algo que toca varias pantallas  un bug con causa evidente
   una decisión de producto        lo que sale del QA en vivo
```

Regla práctica: **si hay una decisión que tomar, hay spec.** Si solo hay algo
que arreglar, hay PR.

## El PR

Una funcionalidad, una rama, un PR. La rama se nombra por el issue:
`mor-208-registro-fundido`.

El PR enlaza su spec y dice qué criterios de aceptación quedaron cumplidos. Si
alguno no se cumplió, se dice — no se borra del spec.

⚠️ **`bin/ci` en verde ANTES de abrir el PR**, incluidos los tests de sistema:
son los únicos que ven lo que el HTML no muestra.
