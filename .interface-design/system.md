# SIGA Design System
**Sistema Integrado de Gestión Académica**

## Direction & Feel

**Product Context:** Sistema académico institucional para administradores, profesores y estudiantes. Gestiona registros oficiales, calificaciones, inscripciones, historiales académicos.

**Feel:** Registro académico digital — formal pero accesible, organizado y confiable. Transmite autoridad académica institucional sin ser intimidante. Se siente como documentos oficiales digitalizados, no como startup tech.

**Domain:** Documentos formales, libros de actas, organización temporal (períodos, semestres), jerarquía educativa (departamentos, grados, secciones), trayectoria estudiantil, credenciales oficiales.

**Color World:** Papel crema (documentos administrativos), tinta sepia/gris oscuro (texto formal), azul institucional (uniformes, credenciales), verde academia (pizarrones), tonos cálidos neutros (mobiliario institucional).

## Signature Element

**Barra de Contexto Académico** — Indicador del período académico activo siempre visible (`.academic-context`). Da sensación de temporalidad institucional, ubicando al usuario en el ciclo académico. Color: fondo azul muy suave (`--brand-subtle`).

## Depth Strategy

**Borders-only** — Los documentos oficiales usan líneas y separaciones, no sombras. Separación mediante bordes sutiles rgba y cambios muy suaves de tono de superficie.

- Sin sombras dramáticas
- Bordes con progresión: `--border-subtle` → `--border-standard` → `--border-emphasis` → `--border-strong`
- Cambios de superficie: canvas crema → papel blanco elevado

## Color Palette

### Base Colors
```css
--surface-canvas: #faf8f5          /* Papel crema - base */
--surface-elevated: #ffffff        /* Papel blanco - elevado */
--surface-input: #f5f3f0           /* Inputs - área escritura */
--surface-hover: #f0ede8           /* Hover state */
```

### Text Hierarchy
```css
--text-primary: #2c2c2c            /* Tinta carbón */
--text-secondary: #5a5a5a
--text-tertiary: #878787
--text-muted: #a8a8a8
```

### Brand (Institutional Blue)
```css
--brand-primary: #1e4a7a           /* Azul institucional */
--brand-hover: #163854
--brand-active: #0f2538
--brand-subtle: #e8eef5            /* Fondo azul muy suave */
```

### Semantic
```css
--success-text: #2d5a3d            /* Verde academia */
--success-bg: #e8f4ec
--success-border: #c3e6d0

--danger-text: #7a2828             /* Rojo discreto */
--danger-bg: #fdeaea
--danger-border: #f5c6c6

--warning-text: #8b6914
--warning-bg: #fef9e7
--warning-border: #f9e79f
```

### Borders
```css
--border-subtle: rgba(44, 44, 44, 0.08)
--border-standard: rgba(44, 44, 44, 0.12)
--border-emphasis: rgba(44, 44, 44, 0.18)
--border-strong: rgba(44, 44, 44, 0.24)
```

## Typography

**Headings:** Serif (Georgia) — carácter institucional, documentos formales
- `font-family: var(--font-serif)`
- `font-weight: 600`
- `letter-spacing: -0.01em`
- Tamaños: h1 (28px), h2 (22px), h3 (18px)

**Body & Data:** Sans-serif (system fonts) — legibilidad administrativa
- `font-family: var(--font-sans)`
- Body: 15px, line-height 1.6
- Labels: 14px, font-weight 500
- Table headers: 13px, uppercase, letter-spacing 0.03em

**Codes:** (materia codes, carnets)
```css
font-family: var(--font-sans);
background: var(--surface-canvas);
padding: 2px 6px;
border-radius: 3px;
font-size: 13px;
```

## Spacing Scale

Base unit: **8px**

```css
--space-micro: 4px      /* Icon gaps */
--space-xs: 8px         /* Component internals */
--space-sm: 12px
--space-md: 16px        /* Standard spacing */
--space-lg: 24px        /* Section spacing */
--space-xl: 32px        /* Major separation */
--space-2xl: 48px       /* Page padding */
```

## Border Radius

```css
--radius-sm: 3px        /* Inputs, buttons */
--radius-md: 6px        /* Cards */
--radius-lg: 8px        /* Modals */
```

## Animation

```css
--transition-fast: 120ms cubic-bezier(0.2, 0, 0, 1)
--transition-base: 180ms cubic-bezier(0.2, 0, 0, 1)
```

Fast micro-interactions, deceleration easing. No spring/bounce.

## Key Component Patterns

### Navigation

**Top Nav** (`.nav-institutional`)
- Background: `--surface-elevated`
- Border bottom: `--border-standard`
- Brand logo: serif, 20px, `--brand-primary`
- Links: 14px, `--text-secondary`, hover → `--surface-hover`

**Sidebar Index** (`.sidebar-index`)
- Width: 260px
- Background: `--surface-elevated` (same as canvas, separated by border)
- Border right: `--border-standard`
- Section titles: serif, 13px, uppercase, `--text-tertiary`
- Links: 14px, border-left indicator on active (2px `--brand-primary`)
- Active state: `--brand-subtle` background, `--brand-primary` text

### Cards

**Academic Card** (`.card-academic`)
- Background: `--surface-elevated`
- Border: `--border-standard`
- Border radius: `--radius-md`
- Padding: `--space-lg`
- Feels like section of document, not floating card

**Card Header** (`.card-academic-header`)
- Display flex, space-between
- Border bottom: `--border-subtle`
- Padding bottom: `--space-md`
- Margin bottom: `--space-lg`

### Tables

**Academic Table** (`.table-academic`)
- Background: `--surface-elevated`
- Border: `--border-standard`
- Border radius: `--radius-md`
- Thead background: `--surface-canvas` (subtle differentiation)
- Headers: 13px, uppercase, `--text-secondary`, letter-spacing 0.03em
- Row borders: `--border-subtle`
- Row hover: `--surface-hover`
- First column: font-weight 500 (emphasis)

### Forms

**Form Group** (`.form-group`)
- Margin bottom: `--space-lg`

**Labels** (`.form-label`)
- Font size: 14px
- Font weight: 500
- Color: `--text-primary`
- Margin bottom: `--space-xs`

**Controls** (`.form-control`)
- Background: `--control-bg` (slightly darker than surface)
- Border: `--control-border`
- Border radius: `--radius-sm`
- Padding: `--space-sm` `--space-md`
- Focus: border `--brand-primary`, ring `rgba(30, 74, 122, 0.15)`
- On focus, background becomes `--surface-elevated` (lighter)

### Buttons

**Primary** (`.btn-primary`)
- Background: `--brand-primary`
- Color: white
- Hover: `--brand-hover`
- Active: `--brand-active`

**Secondary** (`.btn-secondary`)
- Background: `--surface-elevated`
- Border: `--border-standard`
- Color: `--text-primary`
- Hover: `--surface-hover`, border `--border-emphasis`

**Outline Danger** (`.btn-outline-danger`)
- Transparent background
- Border: `--danger-border`
- Color: `--danger-text`
- Hover: background `--danger-bg`

**Size**
- Default: 14px, padding `--space-xs` `--space-md`
- Small: 13px, padding 6px `--space-sm`

**Structure**
- Display: inline-flex
- Align items center
- Gap: `--space-xs`
- Border radius: `--radius-sm`

### Alerts

```css
.alert {
  padding: var(--space-md) var(--space-lg);
  border-radius: var(--radius-md);
  border: 1px solid;
  font-size: 14px;
}
```

- Success: `--success-bg`, `--success-border`, `--success-text`
- Danger: `--danger-bg`, `--danger-border`, `--danger-text`
- Warning: `--warning-bg`, `--warning-border`, `--warning-text`

### Layout Structure

**App Layout** (`.app-layout`)
- Display: flex
- Min height: calc(100vh - 120px)
- Sidebar + Main content

**Container Academic** (`.container-academic`)
- Flex: 1
- Padding: `--space-xl` `--space-2xl`
- Max width: 100% (flexes within layout)

### Actions Group

```css
.actions-group {
  display: flex;
  gap: var(--space-xs);
  align-items: center;
}
```

## States

**All interactive elements need:**
- Default
- Hover (usually `--surface-hover` bg, or darker brand color)
- Active (pressed state)
- Focus (border + ring for keyboard navigation)
- Disabled (opacity 0.4, cursor not-allowed)

**Data states:**
- Loading
- Empty (`.empty-state` — centered, `--text-tertiary`)
- Error

## Usage Notes

- Navigation context always visible — sidebar shows current location with active state
- Academic context bar shows period when logged in
- Titles use institutional language: "Registro de...", "Catálogo de...", "Crear Nuevo..."
- Confirmation messages formal: "¿Está seguro de eliminar este registro?"
- Inputs have helpful placeholders
- Codes (subject codes, IDs) styled as inline code elements
- Form sections grouped in cards with serif h3 headers
- Cancel buttons link back to index
- Spanish language throughout

## Defaults Rejected

1. ❌ Dark sidebar with colored icons (SaaS tech aesthetic)
   ✅ Light sidebar as document index, same background as canvas, border separation

2. ❌ White floating cards with dramatic shadows
   ✅ Paper-colored panels with subtle borders, feels like document sections

3. ❌ Modern sans-serif everywhere (Inter, Roboto)
   ✅ Serif for institutional headings + sans-serif for operational data

## Files

- `/app/assets/stylesheets/system.css` — Complete design system
- Layout: `/app/views/layouts/application.html.haml`
- Components: Card academic, table academic, form groups, sidebar index, nav institutional
