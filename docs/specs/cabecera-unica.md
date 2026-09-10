# Cabecera única · etapa ② del sistema de diseño

> **Estado:** **congelado** — 8 de septiembre de 2026
> **PR:** —
> **Depende de:** [`sistema-de-diseno.md`](sistema-de-diseno.md) (etapa ①, entregada)

---

## 1 · El problema

Daniel: *«ayer hice una captura de por lo menos cinco tipos de títulos
principales. Eso es inconcebible»*. La etapa ① dejó los tonos de botón
resueltos y el catálogo puesto; **los títulos siguen siendo siete formas**.

Y la auditoría de la ② encontró algo peor que siete formas: la mayoritaria
—`card-academic-header`, 110 usos— **sirve para dos cosas distintas**, y lo
único que las separa es qué etiqueta escribió cada quien.

```
   43×  card-academic-header > %h2    ← título de TARJETA   (18 px)
   32×  card-academic-header > %h1    ← título de PANTALLA  (26 px)
   35×  … + acciones                  botones, badges, chips
```

Nada obliga a acertar. Poner `%h2` donde iba `%h1` no falla, no se ve en
revisión, y deja una pantalla con el título del tamaño de un subtítulo.

## 2 · Qué NO entra

```
   ENTRA                              NO ENTRA
   ─────                              ────────
   card-academic-header    110        acceso-titulo        6  ← otro layout
   cabecera-de-lista        14        solicitud-titulo     2  ← sitio público
   ficha-nombre              4        portada-tesis        1  ← es PAPEL
   ─────────────────────────────
   128 usos, en la app autenticada
```

⚠️ **Las tres que quedan fuera no son deuda: son contextos distintos.** Las
pantallas de Devise viven en el layout de acceso —sin barra, sin menú, centrado
en una tarjeta—; el sitio público es marketing; y la portada del PDF es papel.
Forzarlas al mismo partial sería el error inverso al que este spec corrige.

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Un partial o un helper? | **Partial**, `shared/_cabecera`. Ya existe `_cabecera_de_lista` con toda la lógica buena; esto la generaliza en vez de escribir una pieza nueva al lado | Claude |
| 2 | ¿Cómo se distingue pantalla de tarjeta? | Un parámetro **`nivel:`** — 1 (pantalla, por defecto) o 2 (tarjeta). Deja de depender de qué etiqueta escribió cada quien | Claude |
| 3 | ¿Y las acciones de la derecha? | Un **bloque**: `render layout: "shared/cabecera" do`. Los 35 casos con botones tienen contenido arbitrario y enumerar sus formas sería reinventar el HTML | Claude |
| 4 | ¿`cabecera_de_lista` desaparece? | **Sí, se renombra.** Dejar las dos convivir es exactamente cómo se llegó a 14 de 84: la buena existía y no era obligatoria | Claude |
| 5 | ¿Qué pasa con las 110 vistas? | Se migran **todas en este PR**. Media migración deja tres formas donde había dos | Claude |

## 4 · El dominio

No hay ley acá. La razón es la de siempre en SIGA: **Daniel sostiene el
producto solo**, y una pantalla que decide su propia forma es una pantalla que
hay que volver a entender cada vez que se abre.

⚠️ **Lo que parece razonable y está mal:** migrar solo los casos simples y
dejar los 35 con acciones «para después». Eso deja *tres* formas conviviendo
—la vieja, la nueva simple y la nueva con bloque— y la próxima pantalla copia
la que tenga más cerca.

## 5 · Cómo se ve

```
   ANTES — cuatro maneras de escribir lo mismo

   .card-academic                        .card-academic
     .card-academic-header                 .card-academic-header
       %h1 Editar sección                    %h2 Asistencia

   .card-academic                        = render "shared/cabecera_de_lista",
     .card-academic-header                        titulo: "Alumnos",
       %h1= @seccion.nombre                       ruta: students_path,
       = boton "Volver", …                        alta: { … }


   DESPUÉS — una

   = render "shared/cabecera", titulo: "Editar sección"
   = render "shared/cabecera", titulo: "Asistencia", nivel: 2

   = render layout: "shared/cabecera", locals: { titulo: @seccion.nombre } do
     = boton "Volver", secciones_path, icono: :volver, tono: :secondary

   = render "shared/cabecera", titulo: "Alumnos", ruta: students_path,
            pista: "Nombre, apellido, cédula…",
            alta: { ruta: new_student_path, nombre: "Registrar alumno" }
```

### Lo que recibe

```
   titulo              obligatorio
   nivel               1 pantalla (por defecto) · 2 tarjeta
   detalle             el contexto: «1er Grado A · Matemática»
   detalle_destacado   invierte el peso: el detalle manda sobre el título
   ─────────────────── de acá para abajo, solo los listados ──────────────
   ruta                destino del buscador y de «Limpiar»
   marco               el turbo_frame que se refresca
   pista               el placeholder del buscador
   extra               filtros: :select, :select_agrupado, :date
   alta                { ruta:, nombre: }  → el [+ Agregar]
   importar            el tipo de planilla
   alta_en_linea       para listas cortas: el campo va en la cabecera
   ─────────────────── y el bloque ───────────────────────────────────────
   yield               las acciones de la derecha
```

## 6 · Criterios de aceptación

- [ ] Dada cualquier vista de la app autenticada, cuando declara su título,
      entonces lo hace con `shared/cabecera` — y `card-academic-header` no
      aparece escrito a mano en ninguna.
- [ ] Dado `shared/cabecera` con `nivel: 2`, entonces emite un `<h2>`; sin
      `nivel`, un `<h1>`.
- [ ] Dada una pantalla con acciones, cuando se le pasa un bloque, entonces
      los botones salen a la derecha del título y envuelven debajo en el
      teléfono.
- [ ] Dado un listado con buscador, alta e importador, entonces se comporta
      exactamente como hoy: mismo marcado, mismo tooltip, mismo turbo_frame.
- [ ] Dada cualquier vista, cuando escribe `%h1` fuera de la cabecera,
      entonces el test falla.

## 7 · Lo que se puede romper

⚠️ **La sección que más tiempo ahorra.**

- **Todo test que apunte a `.card-academic-header`.** Son navegación estructural
  y hay que grepearlos: un `assert_select` que ya no encuentra nada **falla** y
  está bien; uno con `count: 0` **pasa sin probar nada**.
- **`.cabecera-de-lista` como selector CSS** se queda —el marcado no cambia—,
  pero el nombre del partial sí. Los `render "shared/cabecera_de_lista"` que
  queden sueltos revientan con `Missing partial`, que es ruidoso y por eso
  seguro.
- **Los `%h1` sueltos que quedan fuera de alcance** (Devise, público, PDF) tienen
  que quedar EXPLÍCITAMENTE permitidos en el test, o lo romperán sin ser deuda.
- **El nivel del encabezado importa para lectores de pantalla.** Una pantalla con
  dos `<h1>` —el de la cabecera y el de una tarjeta migrada mal— es un defecto
  de accesibilidad que no se ve mirando.

## 8 · Cómo se verifica

`bin/ci` completo. Y el catálogo de `/siga/estilo` gana su sección de títulos:
deja de ser el inventario de deuda de la etapa ① y pasa a mostrar los dos
niveles de verdad, dibujados por el partial.
