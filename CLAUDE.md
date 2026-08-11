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

- **Milestone `1 · Esquema por colegio` completo, más `MOR-89`.** En la rama
  `feat/mor-82-school-id-en-grades` (7 commits, sin push). Todas las tablas del dominio tienen
  `school_id` materializado, los índices únicos que debían ser por colegio lo son, y **ya no se
  puede escribir una fila que cruce dos colegios**. Ver `## ⚠️ Estado conocido` para el detalle
  de qué quedó global a propósito.
- **Tres concerns**, que es donde vive la mecánica del aislamiento:
  `DerivesSchoolFrom` (declara de qué padre sale `school_id` y lo mantiene al día),
  `ValidatesSameSchool` (impide vincular entidades de colegios distintos) y
  `SchoolScoped` (el `default_scope` por colegio).
- **`MOR-86` + `MOR-87` · La app es multi-tenant. Las dos capas están puestas y medidas.**
  Commits `cddab27` y `82a3259`, misma rama. `Current.school` sale **solo del rol del usuario
  autenticado**; el selector de colegio salió del formulario de grados y `school_id` dejó de estar
  en los parámetros permitidos. Debajo, RLS con `FORCE` en las 17 tablas del dominio.
  **El IDOR documentado (`GET /students/:id` de otro colegio) pasó de 200 a 404.**

  | | Solo capa 1 | Con RLS |
  |---|---|---|
  | `Student.count` con contexto Bolívar | 200 ✅ | 200 ✅ |
  | `Student.unscoped.count` | 290 ❌ | 200 ✅ |
  | `SELECT * FROM students` crudo | 290 ❌ | 200 ✅ |
  | **Sin contexto de colegio** | 290 ❌ | **0** ✅ |
  | `INSERT` cruzado | pasa ❌ | rechazado ✅ |

  ⚠️ **Requisito de setup que NO es opcional:** la app se conecta como `siga_app`, no como el
  usuario de macOS. Un superusuario **se salta el RLS por completo** y `FORCE` no lo alcanza —
  las políticas quedan decorativas. Pasó exactamente eso durante el desarrollo. Ver
  `## Common Commands` para el arranque en una máquina nueva.

**Pendiente inmediato, en orden:**
1. **`MOR-88` · Tenant en los background jobs.** Es lo único que queda del milestone
   `2 · Aislamiento`. Un worker corre sin request, así que `Current.school` está en `nil` y —con el
   RLS puesto— la consulta ahora devuelve **cero filas**, no todas. El tenant va explícito en el
   payload del job.
2. **Módulo de evaluación de punta a punta** (`MOR-93` → `94` → `95` → `96` → `97`). Es lo único
   demostrable, y hay un formulario de demo vivo sin nada que mostrarle a quien lo llene.
3. **`MOR-105` · CI y tests.** `bin/smoke` ya está en el repo (21 checks HTTP por rol) y es el punto
   de partida. Rails 8.1 trajo `bin/ci` y `config/ci.rb` — decidir si se adoptan o GitHub Actions.
   Ojo para `MOR-90`: las fixtures se insertan **sin contexto de colegio**, así que el `WITH CHECK`
   las va a rechazar en cuanto haya fixtures de tablas con RLS.
4. **Push de las tres ramas y PR.** `feat/encuesta-demo-y-backlog` → `chore/upgrade-ruby-rails` →
   `feat/mor-82-school-id-en-grades`, encadenadas. `main` sigue intacto.

**Cómo se entrega, desde ahora** (convención escrita en el documento *Cómo trabajamos* de Linear):
cada issue cerrado deja **transferencia de aprendizaje** (qué salió distinto, qué falló y cómo se
descubrió, qué no hacer la próxima vez), **material visual** siempre que se pueda —diagramas ASCII,
tablas, antes/después— y una **guía de QA** con datos sembrados que cubran el caso que el issue
resuelve **y** el que rechaza. Nada se da por terminado sin poder verlo funcionando en la app.

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
# Setup en una máquina nueva — el primer paso NO es opcional
SIGA_DB_USER=$(whoami) bin/rails rls:crear_rol   # crea siga_app y le traspasa las tablas
bin/rails rls:verificar                          # debe decir SUPERUSER: false / BYPASSRLS: false
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
- **Multi-tenancy**: `Current.school` + concern `SchoolScoped` (app) + RLS con `FORCE` (base).
  La app se conecta como **`siga_app`**, un rol sin `SUPERUSER` ni `BYPASSRLS` — con cualquiera de
  los dos el RLS deja de evaluarse. Ver `## ⚠️ Estado conocido § 1`.
- **Esquema**: `db/structure.sql`, no `schema.rb` — las políticas de RLS no caben en el DSL de Ruby.
- **Módulo**: `Siga` (ver `config/application.rb`)

## Conventions

- Vistas en **Haml**, no ERB
- Nombres en español para controllers/vistas (`InicioController`, no `HomeController`)
- Todas las rutas requieren autenticación por defecto; hay que saltarla explícitamente
- Los enums de dominio llevan etiquetas en constantes del modelo (ver `DemoRequest`)

## ⚠️ Estado conocido — leer antes de tocar el modelo

### 1. ~~La app NO es multi-tenant~~ → resuelto. Queda un pendiente: los jobs.

El diagnóstico original, con lo que quedó de cada punto:

- ~~No existe **ninguna** consulta filtrada por escuela en toda la app~~ → **resuelto** (`MOR-86`).
  Sigue sin haber filtros escritos a mano, y esa es la gracia: los pone `SchoolScoped`.
- ~~El panel de admin muestra los totales de **toda la plataforma**~~ → **resuelto**: 200/8/10 para
  Bolívar, 90/7/6 para Bello, sin tocar el controller.
- ~~`GET /students/:id` de otro colegio devuelve **200** y permite editar (IDOR)~~ → **404**.
- ~~`grades` y `evaluation_moments` no tienen `school_id`~~ → **resuelto** (`MOR-82`, `MOR-83`).
  Los momentos cuelgan del **período académico**, no de la escuela: así la estructura de
  evaluación de cada año queda congelada junto con sus notas. La validación de pesos suma
  dentro del período.
- ~~Índices únicos globales que deberían ser por colegio~~ → **resuelto** (`MOR-84`).
  `grades.name`, `subjects.code` y `students.school_card` son compuestos con `school_id`.
  Quedan globales **a propósito**: `schools.dea_code` (lo asigna el MPPE), `users.email`
  (Devise autentica antes de saber el inquilino) y `users.id_card` (identifica a una persona,
  no a un rol).
- ~~Nueve tablas deducen su colegio por cadena~~ → **resuelto** (`MOR-85`). `school_id`
  materializado y mantenido al día por el concern `DerivesSchoolFrom`. Es el prerrequisito
  del RLS: una política de PostgreSQL evalúa columnas de la fila, no asociaciones.
- ~~`Enrollment` no valida que el colegio del alumno coincida con el de la sección~~ →
  **resuelto** (`MOR-89`), y en nueve modelos, no en tres: el issue listaba `Enrollment`,
  `TeacherSection` y `Grade#leader_teacher`, pero cualquier modelo con dos FK a entidades con
  colegio era candidato. Vive en el concern `ValidatesSameSchool`.

**Las dos capas, implementadas** (`MOR-86` + `MOR-87`):

```
  Petición ──► around_action ──► Current.school = colegio del ROL del usuario
                    │             (nunca de un parámetro, URL, header ni campo oculto)
                    │
                    ├─ CAPA 1 · SchoolScoped
                    │    default_scope { where(school_id: Current.school_id) }
                    │    17 modelos. Evita el error humano.
                    │    Se la saltan: unscoped, find_by_sql, SQL crudo.
                    │
                    └─ CAPA 2 · PostgreSQL RLS con FORCE
                         SET LOCAL siga.school_id, dentro de la transacción
                         17 tablas. Hace que el error no tenga consecuencias.
                         Sin contexto → CERO filas, no todas.
```

**Tres cosas que no son negociables y son fáciles de romper:**

1. **El rol de la base no puede ser superusuario ni tener `BYPASSRLS`.** Un superusuario se salta
   las políticas antes de mirarlas, y `FORCE` no lo alcanza — `FORCE` solo somete al *dueño* de la
   tabla. En macOS con Homebrew el usuario por defecto **es** superusuario: sin `rls:crear_rol` el
   aislamiento parece configurado y no se evalúa ni una vez. `bin/rails rls:verificar` lo detecta.
2. **La variable de sesión va por transacción** (`set_config(..., true)`, o sea `SET LOCAL`).
   Con `SET` a secas sobrevive a la petición y la siguiente hereda el colegio de la anterior — la
   misma fuga, con más pasos. Por eso `around_action`, no `before_action` ni initializer.
3. **El esquema va en `structure.sql`.** `schema.rb` no sabe representar `CREATE POLICY`: el primer
   `db:prepare` regeneraría el esquema sin RLS, en silencio.

**Lo que queda:** los **background jobs** corren sin request, así que `Current.school` está en `nil`
y —con el RLS puesto— la consulta devuelve cero filas. El tenant va explícito en el payload
(`MOR-88`).

`Current.sin_aislamiento` es la única puerta de salida, explícita y grepeable a propósito: las redes
de colegios (AVEC, ANDIEP, Fe y Alegría) necesitan **vista consolidada entre colegios**, así que el
aislamiento no puede ser un silo puro. Para ese caso está `de_los_colegios(*ids)`, que cruza colegios
sin apagar el resto de los scopes.

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
