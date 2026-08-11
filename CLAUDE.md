# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🔖 Punto de retome — actualizado 11 de agosto de 2026

> Sección volátil: es el estado de avance, no guía permanente. Actualizarla al cerrar cada sesión.

**Contexto de las sesiones previas.** Se hizo un análisis completo del proyecto (propuesta comercial,
modelo ER, código) corriendo la app con datos de dos colegios. Los hallazgos y decisiones están en
`## ⚠️ Estado conocido` más abajo, y el diagrama del modelo actual vs. objetivo en el artifact
enlazado al final.

> **El backlog vive en Linear**, en la initiative **SIGA**. `BACKLOG.md` quedó como puntero y tabla
> de equivalencias `E1-01 → MOR-82`, nada más — mantener dos copias a mano no era sostenible.

**Hecho:**
- Campo "¿qué usan hoy?" en el formulario de demo (`current_system` + `current_system_detail`).
  Pregunta por la forma de la solución —con internet / sin internet— y **no nombra competidores**,
  para no hacerles publicidad en el momento de máxima intención de compra.
- Censo de la cartera del incumbente por certificate transparency → `docs/investigacion/`.
- `CLAUDE.md` y `BACKLOG.md` escritos.
- **Commiteado** en la rama `feat/encuesta-demo-y-backlog` (4 commits, `main` intacto, sin push).
  `.claude/settings.local.json` y `.DS_Store` quedaron ignorados; `.mcp.json` sí se versiona.
- **`MOR-100` · Upgrade de Ruby y Rails — hecho.** Ruby 3.1.2 → **3.4.9**, Rails 7.0.10 → **8.1.3.1**,
  en la rama `chore/upgrade-ruby-rails` (7 commits, sin push). Se subió versión por versión
  (7.1 → 7.2 → 8.0 → 8.1), y valió la pena: **7.2 avisó que los enums con keyword arguments quedaban
  deprecados y 8.0 los elimina**. Saltando directo, la app se rompía sin aviso.
- **Linear reestructurado en initiatives.** Un ecosistema = una **initiative**; un cuerpo de trabajo
  con "terminado" propio = un **proyecto**; una fase adentro = un **milestone**. La ficha de negocio
  vive como **documento de la initiative**, no en un proyecto — sobrevive a cualquier proyecto que
  cierre. SIGA quedó en 5 proyectos y 41 issues.
- **Revisión de producto (10 ago).** Un agente PM revisó la estructura. Lo aplicado:
  importador de matrícula (`MOR-126`), conversaciones con directores (`MOR-127`), cobro de la
  suscripción (`MOR-128`); `MOR-91` fuera de Cimientos (silo puro primero); y la plantilla de issue
  cambió **"Especificación para el agente" por "Rabbit holes" y "No-gos"** — la spec numerada
  precomprometía decisiones y en `MOR-86` mandaba a un `before_action` que `MOR-87` obliga a rehacer.

**Pendiente inmediato, en orden:**
1. **`MOR-82` a `MOR-85` · Esquema por colegio.** Las cuatro migraciones. `MOR-82` no está bloqueado
   por nada. **Ojo con el orden nuevo:** ya no se hace todo Cimientos de corrido — después del
   esquema va el módulo de evaluación completo, y recién ahí el resto del aislamiento.
2. **Módulo de evaluación de punta a punta** (`MOR-93` → `94` → `95` → `96` → `97`). Es lo único
   demostrable, y hay un formulario de demo vivo sin nada que mostrarle a quien lo llene.
3. **`MOR-105` · CI y tests.** El script de humo del upgrade (20 checks HTTP por rol) vive en el
   scratchpad de la sesión, **no en el repo**. Rescatarlo como punto de partida. Rails 8.1 trajo
   `bin/ci` y `config/ci.rb` — decidir si se adoptan o se va a GitHub Actions.
4. **Push de las dos ramas y PR.** `feat/encuesta-demo-y-backlog` y `chore/upgrade-ruby-rails`
   (esta última construida sobre la primera). `main` sigue intacto.

**Riesgo abierto que no está en ningún issue:** no hay estimaciones, ni fechas, ni cycles, ni
horas/semana asignadas a SIGA. Con alcance fijo y tiempo indefinido, "Cimientos primero" no es una
decisión evaluable. Pendiente de resolver más adelante, por decisión explícita.

**Datos de trabajo:** base `siga_development` creada y con seeds cargados. Server: `bin/rails server`.

---

## Project Overview

SIGA (Sistema Integrado de Gestión Académica) es un SaaS de gestión académica para
instituciones educativas de Venezuela (preescolar, primaria, secundaria), vendido por
suscripción mensual según matrícula: $25 (hasta 150 alumnos) / $50 (151–400) / $90 (401–800).

Documentación de referencia (PDF/PNG del proyecto, contrato y diagramas ER) en `references/`
— ese directorio está en `.gitignore`, los originales `.pages` viven en el directorio padre
`SIGA/`.

## Common Commands

```bash
# Setup
bin/setup                          # Initial project setup
bin/rails db:create db:migrate     # Create and migrate database
bin/rails db:seed                  # Datos de prueba: 2 colegios, 290 alumnos, 15 profesores

# Development
bin/rails server                   # Start dev server (localhost:3000)
bin/rails console                  # Rails console

# Database
bin/rails db:migrate               # Run pending migrations
bin/rails db:rollback              # Rollback last migration

# Tests
bin/rails test                     # Run all tests
bin/rails test test/models/user_test.rb:10     # Run single test by line
```

Credenciales de los seeds (contraseña universal `123123`):
`director.bolivar@siga.edu` (admin) · `prof.garcia@bolivar.edu` (profesor) ·
`alvaro.lopez001@bolivar.edu` (estudiante).

## Architecture

- **Ruby 3.4.9 / Rails 8.1.3.1** con PostgreSQL (`siga_development` / `siga_test`)
- **Views**: Haml (`.html.haml`) — no ERB. Todas las vistas y plantillas de Devise usan Haml.
- **Frontend**: Hotwire (Turbo + Stimulus) con Importmap (sin Node.js/Webpack)
- **Auth**: Devise sobre `User`. `ApplicationController` aplica `authenticate_user!` global —
  los controllers nuevos deben hacer `skip_before_action` para páginas públicas.
- **Roles**: `User` tiene `has_one` a `Student` / `Teacher` / `Admin` (PK = `user_id`).
  `Admin#role` es un enum: desarrollador, director, finanzas, coordinador, secretaria.
  Los helpers de autorización viven en `ApplicationController` (`can_manage_students?`, etc.).
- **Paginación**: Pagy. **Auditoría**: concern `Auditable` + modelo `ActivityLog`.
- **Módulo**: `Siga` (ver `config/application.rb`)

## Conventions

- Vistas en **Haml**, no ERB
- Nombres en español para controllers/vistas (`InicioController`, no `HomeController`)
- Todas las rutas requieren autenticación por defecto; hay que saltarla explícitamente
- Los enums de dominio llevan etiquetas en constantes del modelo (ver `DemoRequest`)

## ⚠️ Estado conocido — leer antes de tocar el modelo

### 1. La app NO es multi-tenant. Los datos se cruzan entre colegios.

Verificado en la app corriendo con dos colegios en la base:

- No existe **ninguna** consulta filtrada por escuela en toda la app.
- El panel de admin muestra los totales de **toda la plataforma**, no los del colegio.
- `GET /students/:id` de otro colegio devuelve **200** y permite editar (IDOR).
- `grades` y `evaluation_moments` **no tienen `school_id`**. La validación de pesos de
  `EvaluationMoment` suma globalmente: si un colegio ocupa el 100 %, ningún otro puede
  crear un momento de evaluación.
- Índices únicos globales que deberían ser por colegio: `grades.name`, `subjects.code`,
  `students.school_card`. Los seeds ya lo esquivan nombrando `"1er Año - Bolívar"`.
- `Enrollment` no valida que el colegio del alumno coincida con el de la sección.

**Decisión tomada (pendiente de implementar): dos capas.**
`default_scope` vía concern `SchoolScoped` + **PostgreSQL RLS con `FORCE ROW LEVEL SECURITY`**.
La razón del RLS es que un filtro olvidado deje de ser una fuga silenciosa y pase a devolver
cero filas. Dos puntos donde Rails rompe y hay que atacar explícitamente:
la variable de sesión de Postgres se setea **por transacción** (`around_action`, no initializer),
y los **background jobs** corren sin request, así que el tenant va explícito en el payload.

Requisito que condiciona el diseño: las redes de colegios (AVEC, ANDIEP, Fe y Alegría)
necesitan **vista consolidada entre colegios**, así que el aislamiento no puede ser un silo puro.

### 2. El módulo de evaluación existe en la base y no tiene interfaz.

`evaluation_activities`, `activity_grades`, `moment_grades` y `final_grade_books` tienen
modelos, validaciones y el servicio `GradeCalculator` (promedio ponderado de lapso y anual),
pero **cero controllers, rutas y vistas**. Un profesor no puede cargar una nota y nadie puede
ver una. Es el núcleo del producto y está desconectado.

### 3. Otros pendientes

- ~~Ruby 3.1 y Rails 7.0 fuera de soporte de seguridad~~ → **resuelto**: Ruby 3.4.9 / Rails 8.1.3.1.
  Los enums migraron a la sintaxis posicional (`enum :status, {...}`), obligatoria desde Rails 8.
- `config.force_ssl` comentado en `config/environments/production.rb`.
- `action_mailer` sin configurar en producción → "olvidé mi contraseña" no envía nada.
- `User` tiene `:registerable`: cualquiera puede crear cuenta en `/users/sign_up`.
- `db/seeds.rb` crea usuarios con contraseña `123123` sin guard de entorno.
- Sin CI, sin Dockerfile, sin monitoreo. Tests prácticamente vacíos.
- Colisión de nombres: `Grade` es "grado escolar", pero `ActivityLog::LABELS` traduce
  `grade_created` como "Calificación registrada". Dos conceptos, un nombre.

## Contexto de mercado (investigado, agosto 2026)

- ~3.900 colegios privados en Venezuela (ANDIEP), tras cerrar 1.200 entre 2019 y 2023.
  Matrícula privada cayó de 3,2 M a ~1,4 M → **promedio ~360 alumnos por colegio**.
- Incumbente: **Sistemas SAE** (Barquisimeto, 25+ años, declara +900 instituciones).
  Censo por certificate transparency: **~195 subdominios de colegio**, ~87 % activos.
  → el ~78 % de su cartera usa el producto de escritorio, **sin portal web**.
- **Ese es el beachhead**: ~800 colegios que ya pagan software pero no tienen acceso web.
- Educasis declara "2+ instituciones"; SGE Pro no tiene subdominios verificables.
- SAE está concentrado en centro-occidente (Guanare, Bolívar, Carora, Lara).
  Caracas y Maracaibo aparecen ausentes de su listado.
- Venezuela **no tiene ley de protección de datos** ni autoridad de control. El riesgo de un
  cruce de datos es reputacional y de churn en red, no regulatorio.

Backlog completo en `BACKLOG.md`. Diagrama del modelo actual y objetivo:
https://claude.ai/code/artifact/0e167ba9-8e21-4264-ac29-f7a2d9fe5523
