# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🔖 Dónde quedamos

El estado de avance vive en [`RETOME.md`](RETOME.md) — **leerlo al arrancar la sesión y
actualizarlo al cerrarla.** Está aparte a propósito: es lo que más cambia, y acá adentro
viajaría en cada petición al modelo además de invalidar el caché del prompt en cada edición.

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

### 1. ~~La app NO es multi-tenant~~ → resuelto, en las dos capas y también en los jobs.

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

**Los jobs** (`MOR-88`): un worker no tiene petición, así que no hereda nada. El `school_id` se
serializa en el payload **al encolar**, que es el único momento en que el contexto es un dato
confiable, y el concern `CarriesSchool` lo restablece antes del `perform`. Por defecto un job
**exige colegio**; `colegio_opcional` y `de_toda_la_plataforma` son las dos salidas. Ojo con
`perform_now` dentro de una petición: `SET LOCAL` pertenece a la transacción **más externa** y una
`transaction` anidada no abre una nueva — el concern guarda y devuelve el valor anterior por eso.

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
