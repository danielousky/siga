# Control de Estudio cierra el lapso

> **De dónde sale:** la prueba de campo con Cyndi, puntos 2 y 6 de su lista.
> **Depende de:** `MOR-216` (informe descriptivo) · la revisión de boletines.
> **Decidido por:** Daniel, 18 de septiembre de 2026.

---

## 1 · El problema

Las notas de un lapso nunca terminaban de estar terminadas. El profesor
cargaba, la oficina emitía boletines cuando se acordaba, y **nada decía que el
proceso hubiera cerrado**: una nota se podía cambiar en marzo y el boletín que
la familia descargó en diciembre decía otra cosa.

Y del otro lado, la familia se enteraba por WhatsApp de que había notas.

## 2 · La decisión

Daniel, en dos mensajes que dicen lo mismo:

> *«Admin debe validar que todas las boletas están completas y dar el visto
> bueno antes de que sean liberadas y el representante reciba el correo y pueda
> verlas.»*
>
> *«CE mira las boletas y da por "cerrado" el proceso de carga y completación de
> la calificación. Al dar el visto bueno se envía el correo al representante y
> ya puede entrar a ver sus notas, y a su vez el profe ya no puede modificar las
> notas. Debería ser un campo de la sección: por defecto está en "Por
> calificar", cuando el profe califica pasa a calificada y cuando CE corrobora
> pasa a "Cerrada".»*

```
   POR CALIFICAR   falta alguna nota de lapso            se DEDUCE
   CALIFICADA      todas las notas, todos los alumnos    se DEDUCE
   CERRADA         Control de Estudio dio el visto bueno se GUARDA
```

## 3 · Qué dispara el cierre

```
   1 · se EMITEN los boletines que falten      con su foto de las notas
   2 · se LIBERAN todos                        → la familia los ve
   3 · sale el correo a cada representante
   4 · el profesor deja de poder tocar las notas del lapso
```

## 4 · Las decisiones que ordenan el modelo

| # | Pregunta | Respuesta | Por qué |
|---|---|---|---|
| 1 | ¿Se guardan los tres estados? | **Solo «cerrada»** | Los otros dos los contestan las notas. Guardarlos sería un segundo lugar donde vive la misma verdad: entra la nota que faltaba y la columna sigue diciendo «por calificar». |
| 2 | ¿Es una columna de `sections`? | **No: una fila por (sección, lapso)** | Una sección tiene tres lapsos y cada uno cierra por su cuenta. Una columna obligaría a tres, y a renombrarlas el día que un colegio use dos semestres. |
| 3 | ¿Se puede cerrar con notas faltando? | **No** | Revierte el criterio de «liberar», que dejaba salir lo emitido. Cerrar no es entregar veinte boletines: es declarar terminado el lapso. |
| 4 | ¿Exige el informe descriptivo? | **Sí** | Revisado el 19 de septiembre. Salió como aviso —el informe es opcional por diseño (`MOR-216`)— y Daniel lo cerró: *«sí, el informe debe ser obligatorio para cerrar»*. Una boleta sin una línea del docente es una factura: el «PA» dice en qué banda cayó el niño; el informe dice que lee mejor que en octubre. ⚠️ Sigue siendo opcional en el MODELO: un lapso a medias tiene alumnos sin informe y eso no es un error. Lo que no se puede es darlo por TERMINADO. |
| 5 | ¿Se puede reabrir? | **Sí** | Un error en una nota se descubre DESPUÉS de cerrar. Sin esa puerta, la única salida es tocar la base. ⚠️ Lo que no deshace es el correo que ya salió, y el aviso lo dice. |
| 6 | ¿El alumno retirado bloquea? | **No cuenta** | No tiene notas y nunca las va a tener: contándolo, la sección se queda en «por calificar» para siempre. Tampoco se le emite boletín. |

## 5 · Dónde vive el límite

⚠️ **En el MODELO, no en la pantalla.** Un límite que solo existe en un
controller no es un límite: la próxima pantalla que escriba notas —un
importador, una acción en lote— no se entera.

```
   ActivityGrade        se_cierra_con_el_lapso :evaluation_activity
   EvaluationActivity   se_cierra_con_el_lapso
```

⚠️ **Y también al BORRAR.** Vaciar el campo de la planilla es un `destroy`, así
que sin la guarda en `before_destroy` el cierre se saltaba entero con la tecla
de borrar.

⚠️ **Educación Inicial es la excepción, y está razonada.** Ahí la valoración ES
la calificación y se guarda en `MomentGrade` — la misma tabla donde
`GradeCalculator` escribe los promedios de primaria y media. Una validación en
ese modelo chocaría con el recálculo, que es automático y no es «el profe
modificando notas». Por eso su guarda vive en `ValoracionesController`.

## 6 · Lo que se ve

```
   ┌─ Cuando esté todo revisado ──────────────────────────────┐
   │  1er Lapso no se puede cerrar todavía:                   │
   │  2 alumnos tienen materias sin nota.                     │
   │                                                          │
   │    López Guzmán, María          2 materias               │
   │    Pérez Silva, Juan            1 materia                │
   └──────────────────────────────────────────────────────────┘
```

Y con el 100 % cargado:

```
   ┌─ Cuando esté todo revisado ──────────────────────────────┐
   │  Al cerrar: se emiten los boletines que falten, las      │
   │  familias los ven, A CADA UNA LE LLEGA UN CORREO y el    │
   │  profesor deja de poder cambiar las notas.               │
   │                                                          │
   │  ⚠ 3 alumnos salen sin informe descriptivo. Escribirlos  │
   │                                                          │
   │  [ Cerrar 1er Lapso · 4to Grado A ]                      │
   └──────────────────────────────────────────────────────────┘
```

⚠️ El bloque está **siempre**, también cuando no se puede cerrar: esconderlo
dejaría a quien revisa sin saber qué falta, que es justo la pregunta que lo
trajo a esta pantalla.

## 7 · Lo que NO entra

- **Cerrar el año completo.** Son tres lapsos y cada uno cierra por su cuenta;
  el anual es otra conversación y otra pantalla.
- **Cerrar varias secciones de una vez.** La coordinadora de primaria revisa lo
  suyo; un botón que cierra diecinueve secciones cierra también las que no miró.

## 8 · La consecuencia que hay que mirar

⚠️ Con el informe obligatorio, **un guía de bachillerato escribe treinta textos
por lapso**, noventa al año, para poder cerrar. En primaria es la misma maestra
que ya conoce a sus veinticinco y el texto sale solo; en Media son doce
profesores y el guía es el único que ve al alumno entero.

No es una objeción a la regla —Daniel la decidió sabiendo lo que pide— sino lo
que hay que mirar en la primera prueba de campo: si el cierre se atasca ahí, la
salida no es aflojar la regla, es hacer que escribir treinta informes cueste
menos (la planilla ya guarda sola; lo que falta sería sugerir un borrador).
