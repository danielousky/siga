# Sistema de diseño · un solo hilo para los cuatro roles

> **Estado:** **congelado** — 8 de septiembre de 2026
> **PR:** —
> **Alcance:** la etapa ① de las cuatro acordadas. Las otras tres van en specs
> propios: la cabecera única (②), la vista del profesor (③) y los documentos de
> identidad (④).

---

## 1 · El problema

Daniel, 8 de septiembre de 2026:

> *«Ayer hice una captura de por lo menos cinco tipos de títulos principales.
> Eso es inconcebible. Debemos definir un único tipo de títulos tanto para
> administradores, profesores, estudiantes y representantes… Un framework vale,
> nuestro propio framework, con las bondades de Bootstrap pero no tan extenso y
> pesado, más adaptado a lo que realmente usamos. Que ya automáticamente diga
> `%table.table.table-condense` y coloque la tabla como es. No tengas que estar
> pensando tú: cómo hago la tabla, qué borde le pongo, ¿será que le gustará el
> estilo de mi propuesta? No, eso ya está definido en el framework.»*

**La auditoría le da la razón, y por más.** Contó cinco tipos de título; hay
siete, más dos escritos a mano con `style:` inline:

```
  FORMA                          USOS   QUÉ TRAE
  ──────────────────────────────────────────────────────────────────────
  card-academic-header > %h1      110   nada. Un %h1 pelado dentro de un div
  cabecera-de-lista-titulo         14   título + detalle + buscador + filtros
                                        + importar + [+ Agregar] con tooltip
  acceso-titulo                     6   las pantallas de Devise
  arranque-listo-titulo             5   el arranque
  ficha-nombre                      4   las fichas de persona
  solicitud-titulo                  2   el sitio público
  portada-tesis                     1   el PDF
  %h1{style: "font-family:Georgia…  2   los dos son de MAILERS ⇒ correcto
```

⚠️ **Corrección sobre la auditoría inicial:** los dos `%h1` con `style:` inline
resultaron ser **los dos de correos**, y ahí el inline es lo correcto — Gmail y
Outlook descartan las hojas externas y no soportan flex ni grid. La deuda real
de estilos escritos a mano eran **otras siete líneas, en cinco vistas**, y esas
sí se cerraron.

**El diagnóstico no es que falte el framework. Es que el que hay es OPCIONAL.**

La cabecera correcta —con buscador, filtros, importador y el `[+ Agregar]` con
su tooltip— existe desde `MOR-192` y **la usan 14 pantallas de 84**. Nadie
eligió divergir: la pieza correcta existía, no era obligatoria, y el camino
corto era escribir `%h1`.

---

## 2 · Qué NO entra

```
   ENTRA                              NO ENTRA
   ─────                              ────────
   los seis tonos de botón, y         la cabecera única — es la etapa ②,
   retirar `btn-primary`              son 84 vistas y merece su propio PR

   /siga/estilo, el catálogo vivo     rediseñar nada. Este spec CONSOLIDA
                                      lo que ya existe; no cambia paletas,
   el test que impide saltárselo      ni tipografías, ni espaciados

   los dos `style=` inline            adoptar Bootstrap o Tailwind —
   (son dos líneas y son el                descartado por Daniel: «demasiado
    caso más grave)                        pesados y más difícil de adaptar»
```

⚠️ **La cabecera única (②) queda fuera a propósito.** Tocar las 84 pantallas en
el mismo PR que cambia los tonos hace imposible revisar ninguna de las dos
cosas. Y este spec deja el catálogo puesto, que es contra lo que se migra.

---

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿De qué color es el botón que lleva al alta? | **Verde**, el mismo del submit | Daniel |
| 2 | ¿Qué significa entonces el verde? | **«Esto queda guardado»** — no «esto crea». Así `[Guardar cambios]` en una edición deja de ser una excepción incómoda: es exactamente lo que el verde promete | Claude, aceptado |
| 3 | ¿Qué distingue el alta del submit? | El **`+`**, y nada más. Es lo único que dice «y además nace algo nuevo» | Daniel |
| 4 | ¿Qué pasa con `btn-primary`? | **Se retira.** Al mover crear y guardar al verde se queda sin trabajo, y «primario» nunca fue un trabajo: es jerarquía visual, justo lo que `MOR-172` reemplazó por *qué hace el botón* | Claude, aceptado |
| 5 | ¿Quién ve el catálogo? | **Solo el equipo de SIGA.** Vive en `/siga/estilo` y hereda la puerta de `Siga::BaseController`; está en producción y se puede mirar desde el teléfono, pero ningún colegio lo ve | Daniel |
| 6 | ¿Texto del botón de alta? | **«+ Agregar»** a secas. «Nuevo» no agrega información a «agregar», y el tooltip ya dice de qué | Propuesto por Claude, **confirmado por Daniel** el 8 de septiembre |

---

## 4 · El dominio

No hay ley del MPPE acá: es una decisión de producto, y su razón es la
transferencia de conocimiento. Daniel sostiene SIGA solo. **Un sistema donde
cada pantalla decide su propia forma es un sistema que hay que volver a
entender cada vez que se abre.**

⚠️ **Lo que parece razonable y está mal:** «pongamos Bootstrap y listo».
Descartado por Daniel, y con razón — un framework externo trae 200 KB de
decisiones que no son las nuestras y hay que pelearle a cada una. SIGA tiene
709 clases propias en 9.548 líneas y **ya son un framework**; lo que falta es
que sea obligatorio.

⚠️ **Y lo segundo que parece razonable y está mal:** que el color distinga
*navegar* de *escribir*. Un profesor no piensa en HTTP: piensa «esto crea algo
nuevo». Por eso el verde cruza los dos.

---

## 5 · Cómo se ve

### Los seis tonos

```
  TONO         COLOR       QUÉ HACE                 EJEMPLOS
  ─────────────────────────────────────────────────────────────────────────
  guardar      verde       queda guardado           [+ Agregar]  [Crear]
                                                    [Guardar cambios]
  accion       índigo      mucho de una vez         [Copiar de otro año]
                                                    [Confirmar importación]
                                                    [Cargar notas]
  documento    petróleo    algo sale                [Descargar] [Emitir]
  ver          azul suave  mirar sin tocar          [Ver] [Abrir]
  secondary    neutro      volver atrás             [Volver] [Cancelar]
  danger       sin tono    destruye                 [Eliminar]
```

### Dónde va cada uno de los dieciséis `btn-primary` de hoy

```
  A GUARDAR (verde) ───────────────────────────────────────────────────────
    _cabecera_de_lista        [+ Agregar]              lleva al alta
    _medida_por               [+] evaluación           lleva al alta
    _form (evaluación)        [+] competencia          lleva al alta
    students/show:67          registrar representante  lleva al alta
    carga_de_notas            «Crear el año escolar»   lleva al alta
    _lista_vacia              el paso que falta        lleva al paso
    _precondicion             el paso que falta        lleva al paso
    _acciones_de_lista_vacia  el default               lleva al paso
    asistencias/show          «Guardar»                escribe
    importaciones/show        «Cambiar el tipo»        escribe

  A ACCION (índigo) ───────────────────────────────────────────────────────
    importaciones/previsualizar  «Confirmar»       360 filas de una vez
    siga/colegios/show           «Entrar»          cambia el contexto entero
    dashboards (×3)              «Cargar notas»    treinta notas de una vez

  A DOCUMENTO (petróleo) ──────────────────────────────────────────────────
    students/show:163         «Emitir el documento»   ⚠️ ESTABA MAL: sale un
                                                      papel y era azul

  A VER (azul suave) ──────────────────────────────────────────────────────
    demo_requests/success     «Escribirnos por WhatsApp»   sale de SIGA
    dashboards                «Ir a mis evaluaciones»

  A SECONDARY (neutro) ────────────────────────────────────────────────────
    verificaciones/no_encontrado  «Probar con otro código»   vuelve atrás
```

### El alta, invariable en las 84 pantallas

```
   visible      [+ Agregar]         siempre que quepa
                [+]                 solo si no cabe (teléfono angosto)

   tooltip      «Registrar profesor»    OBLIGATORIO
   aria-label   el mismo texto
   icono        :agregar, 18 px
   tono         guardar (verde)

   ⚠️ el tooltip no es decoración: en el teléfono NO HAY HOVER, y
      «Agregar» a secas no dice de qué (MOR-173).
```

### El catálogo

```
  /siga/estilo                       ← tras la puerta de Siga::BaseController
  ┌────────────────────────────────────────────────────────────────┐
  │  Catálogo                                                      │
  │  ────────────────────────────────────────────────────────────  │
  │  Tonos  ·  Títulos  ·  Tablas  ·  Formularios  ·  Avisos       │
  │                                                                │
  │  TONOS                                                         │
  │  ┌──────────────────────┬───────────────────────────────────┐  │
  │  │ [+ Agregar]          │ = boton "Agregar", ruta,          │  │
  │  │                      │         icono: :agregar,          │  │
  │  │ queda guardado       │         tono: :guardar            │  │
  │  ├──────────────────────┼───────────────────────────────────┤  │
  │  │ [Copiar de otro año] │ … tono: :accion                   │  │
  │  │ mucho de una vez     │                                   │  │
  │  └──────────────────────┴───────────────────────────────────┘  │
  └────────────────────────────────────────────────────────────────┘
       el componente vivo         y su Haml al lado, para copiar
```

⚠️ **El catálogo se dibuja desde los MISMOS helpers**, no con HTML escrito a
mano. Un catálogo copiado es una octava forma de hacer las cosas — la peor,
porque además dice ser la buena.

---

## 6 · Criterios de aceptación

- [ ] Dado cualquier `.btn` de la app, cuando se mira su clase, entonces lleva
      uno de los seis tonos — y `btn-primary` no existe ni en el CSS ni en las
      vistas.
- [ ] Dado el helper `boton`, cuando se llama sin `tono:`, entonces revienta:
      el tono es obligatorio y no tiene default.
- [ ] Dado un usuario de colegio, cuando pide `/siga/estilo`, entonces rebota
      con «No tienes acceso a esta sección» — igual que el resto de `/siga`.
- [ ] Dado un `SigaStaff`, cuando abre `/siga/estilo`, entonces ve los seis
      tonos, los cuatro niveles de título y la tabla, **dibujados por los
      helpers de verdad**.
- [ ] Dada cualquier vista, cuando contiene `style="…"` inline, entonces el
      test falla.
- [ ] Dada cualquier vista, cuando contiene una `<table>` sin
      `.table-academic`, entonces el test falla.
- [ ] Dado el botón de alta de cualquier listado, cuando se lee su marcado,
      entonces tiene `data-tooltip` y `aria-label` con el mismo texto.

---

## 7 · Lo que se puede romper

- **`test/integration/hoja_de_estilos_test.rb`** — no cambia, pero conviene
  saber que ya cuida las variables CSS; el test nuevo es su hermano y va en el
  mismo archivo o al lado.
- **Cualquier test que apunte a `.btn-primary`.** Es el caso exacto que la
  plantilla llama «guardas que dejan de guardar en silencio»: un
  `assert_select ".btn-primary"` que ya no encuentra nada **falla**, y está
  bien; uno que cuente `count: 0` **pasa sin probar nada**. Hay que grepear los
  dos.
- **Los system tests que hacen `click_on` por texto** no se ven afectados: el
  texto no cambia, solo el color.
- **`boton` sin default de tono** rompe siete llamadas. Son siete y hay que
  clasificarlas a mano — no hay respuesta automática, que es justamente el
  punto.

---

## 7.b · Lo que apareció construyendo esto

Cuatro cosas que no estaban en el plan y salieron al mover los tonos:

1. **`students/show:163` estaba en el tono equivocado.** «Emitir el documento»
   era azul cuando de ahí sale un papel: es `documento` (petróleo), igual que
   «Emitir y descargar» del boletín. Llevaba así desde que existe, y lo destapó
   tener que clasificar los dieciséis a mano.

2. **Un botón de dos palabras se desbordaba.** `.btn` tiene `line-height: 1` y
   `min-height: 36px`, así que «Copiar de otro año» partía en dos renglones y la
   segunda línea se salía por debajo del borde. Se vio recién con los seis tonos
   uno encima del otro, en el catálogo. Va con `white-space: nowrap` — y en el
   teléfono se revierte a `normal`, donde el botón mide 56 px y sí puede
   envolver.

3. **`.dato-secundario` ya existía**, y al escribir las clases nuevas la
   redefiní con otro color. Es la colisión de `.contexto-fijo` de la semana
   pasada, otra vez: dos definiciones del mismo nombre en la misma hoja, gana la
   de más abajo y la otra se aplica a medias, en silencio.

4. ⚠️ **La hoja tiene 108 selectores duplicados**, y eso NO se tocó acá.
   Noventa y ocho repiten el mismo cuerpo —redundancia inofensiva— y diez
   difieren, pero nueve de esos diez son refinamientos deliberados en cascada
   (`.btn-danger` es el ejemplo: MOR-207 lo redefine más abajo a propósito).
   Desenredarlo es un PR propio; mezclarlo con el cambio de tonos haría
   imposible revisar ninguno de los dos.

⚠️ **Y el propio test tenía un agujero.** Buscaba `boton "` con la comilla, así
que se le escapaban las tres llamadas que pasan una variable
(`boton paso.verbo, …`). El CI las encontró igual, pero reventando en cinco
tests de pantallas que no tenían nada que ver — que es exactamente el costo de
una guarda incompleta.

---

## 8 · Cómo se verifica

`bin/ci` completo. Además:

- El catálogo se **mira**, en `/siga/estilo`, con `soporte@siga.app` (el
  `SigaStaff` de los seeds) — es el único criterio que no se puede escribir
  como aserción: que los seis tonos se distingan entre sí a simple vista.
- Un test de sistema comprueba la puerta (un director rebota) y que la página
  dibuja los seis tonos.
