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
# Setup en una máquina nueva — `bin/setup` ya crea el rol `siga_app` y verifica
# que NO pueda saltarse el RLS. Sin ese rol, el aislamiento no se evalúa (MOR-87).
bin/setup                          # base + rol sin privilegios + verificación
bin/rails db:seed                  # Datos de prueba: 2 colegios, 290 alumnos, 15 profesores

# Development
bin/rails server                   # Start dev server (localhost:3000)
bin/jobs                           # Worker de la cola — sin él, los jobs esperan
bin/rails console                  # Rails console

# Database
bin/rails db:migrate               # Run pending migrations
bin/rails db:rollback              # Rollback last migration

# Tests
bin/rails test                     # Run all tests
bin/rails test test/models/user_test.rb:10     # Run single test by line

# Verificación completa — lo mismo que corre el CI (MOR-105)
bin/ci                             # RLS + estilo + tests + seeds + humo, ~10 s
bin/smoke                          # solo el recorrido HTTP por los cuatro roles
```

`bin/ci` arranca comprobando que el rol de la base **no** pueda saltarse el RLS, y no
es ceremonia: si ese rol fuera superusuario, el aislamiento entre colegios dejaría de
existir y **ningún otro paso del pipeline se daría cuenta** — los tests seguirían en
verde porque el `default_scope` de la app filtra igual.

Credenciales de los seeds (contraseña universal `123123`):
`director.bolivar@siga.edu` (admin) · `prof.garcia@bolivar.edu` (profesor) ·
`alvaro.lopez001@bolivar.edu` (estudiante).

## Architecture

- **Ruby 3.4.9 / Rails 8.1.3.1** con PostgreSQL (`siga_development` / `siga_test`)
- **Views**: Haml (`.html.haml`) — no ERB. Todas las vistas y plantillas de Devise usan Haml.
- **Frontend**: Hotwire (Turbo + Stimulus) con Importmap (sin Node.js/Webpack)
- **Auth**: Devise sobre `User`. `ApplicationController` aplica `authenticate_user!` global —
  los controllers nuevos deben hacer `skip_before_action` para páginas públicas.
  **`email` y `encrypted_password` son OPCIONALES** (`MOR-142`): un alumno de primaria es un
  registro, no una cuenta. Quién sí necesita correo lo decide el ROL, con el concern
  `EntraAlSistema` (`Teacher`, `Admin`, `SigaStaff`). Ver `## ⚠️ Estado conocido § 5`.
- **Roles**: `User` tiene `has_many` a `Student` / `Teacher` / `Admin` / `Representative`, cada
  uno con `id` propio y ÚNICO `(user_id, school_id)` — una persona puede tener el mismo rol en
  varios colegios (`MOR-138`). Los singulares `user.student` / `.teacher` / `.admin` siguen
  existiendo y devuelven el rol **en el colegio de la sesión**, que es lo que casi todo el
  código necesita.
  `Admin#role` es un enum: desarrollador, director, finanzas, coordinador, secretaria.
  Los helpers de autorización viven en `ApplicationController` (`can_manage_students?`, etc.).
- **Identidad de una persona**: `document` + `document_type` (los cuatro documentos que acepta
  el MPPE) y `cedula_escolar` aparte — no es "otro tipo de documento", es lo que se usa
  **mientras no hay** documento, y NO se borra cuando llega. Nombre partido en `first_name` /
  `last_name` / `second_last_name`, porque el SAIME verifica el PRIMER apellido.
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
  (Devise autentica antes de saber el inquilino, y desde `MOR-142` el índice es **parcial**:
  `WHERE email IS NOT NULL`), y `users.document` / `users.cedula_escolar` — identifican a una
  PERSONA, no a un rol, y la cédula escolar es nacional justamente para acompañar al alumno
  cuando se cambia de plantel.
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
                    │    23 modelos. Evita el error humano.
                    │    Se la saltan: unscoped, find_by_sql, SQL crudo.
                    │
                    └─ CAPA 2 · PostgreSQL RLS con FORCE
                         SET LOCAL siga.school_id, dentro de la transacción
                         22 tablas. Hace que el error no tenga consecuencias.
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

### 2. ~~El módulo de evaluación no tiene interfaz~~ → conectado de punta a punta.

El profesor define sus evaluaciones y su ponderación, carga las notas desde el teléfono con
guardado incremental, los promedios se recalculan solos y el alumno los ve el mismo día
(`MOR-93` → `97`).

**El cálculo se rige por el Reglamento General de la LOE, no por lo que haga Ruby:**

| Artículo | Regla | Dónde vive |
|---|---|---|
| **108** | La calificación es un **número entero del 1 al 20**; ≥ 0,50 sube | `GradeCalculator.redondear` + un `CHECK` por columna |
| **111** | El anual es el **promedio** de los lapsos, **sin ponderar** | `calculate_final_grade` |
| **112** | La nota de la segunda oportunidad es la definitiva | `final_score = max(anual, reparación)` |

`evaluation_moments.weight` describe la estructura del año y **no entra en ningún cálculo**:
la decisión fue apegarse a la norma en vez de generalizarla.

**"Sin nota" no es cero, y hay que sostenerlo en las tres capas.** El cálculo devuelve `nil` y
borra la calificación que quedó sin respaldo; la planilla borra la fila al vaciar el campo; la
vista del alumno escribe "Pendiente" en letras, nunca un número. Confundirlos reprueba a una
sección entera a mitad de lapso, y le hace perder la confianza a la familia.

**Qué recalcula qué:**

```
  guardar/borrar una nota  ──► EN LÍNEA  (~10 ms)   ActivityGrade#after_save
                                                     el promedio nunca queda viejo

  cambiar una ponderación  ──► POR JOB   (~1 s)     RecalcularSeccionJob
                                                     afecta a los 30 alumnos

  reparar inconsistencias  ──► bin/rails notas:recalcular   (idempotente)
```

### 3. Otros pendientes

**Resueltos** (esta lista estuvo desactualizada un tiempo; se verificó uno por uno el 15 de agosto):

- ~~Ruby 3.1 y Rails 7.0 fuera de soporte~~ → Ruby 3.4.9 / Rails 8.1.3.1. Los enums migraron a
  la sintaxis posicional (`enum :status, {...}`), obligatoria desde Rails 8.
- ~~`config.force_ssl` comentado~~ → `ENV.fetch("SIGA_FORCE_SSL", "true")`. Va por variable
  porque **HSTS es difícil de deshacer**: el navegador recuerda la orden meses.
- ~~`action_mailer` sin configurar~~ → SMTP completo por variables de entorno, sin atarse a un
  proveedor. `perform_deliveries` solo si hay `SMTP_ADDRESS`, y `raise_delivery_errors` en true:
  un correo que no sale tiene que aparecer en el log, no desaparecer.
- ~~Registro público abierto~~ → `devise_for :users, skip: [:registrations]`, y `/cuenta` se
  devuelve a mano para editar el perfil. `/users/sign_up` da **404** (`MOR-101`).
- ~~Seeds sin guard de entorno~~ → abortan fuera de desarrollo.
- ~~Sin CI~~ → `bin/ci` en ~15 s (`MOR-105`), y el workflow de GitHub Actions **ya puede correr**:
  el repo tiene remoto (`danielousky/siga`, privado).
- ~~Sin Dockerfile~~ → existe, con su `.dockerignore`.
- ~~El adaptador de jobs pierde lo encolado al reiniciar~~ → **Solid Queue**, sobre la misma base
  de PostgreSQL. Ver abajo.

**Abiertos de verdad:**

- **Sin monitoreo.** Nada avisa si el worker se cae o si la cola crece.
- **Colisión de nombres:** `Grade` es "grado escolar", pero `ActivityLog::LABELS` traduce
  `grade_created` como "Calificación registrada". Dos conceptos, un nombre.
- **El worker hay que levantarlo.** El `Procfile` declara `web` y `worker`; si el segundo no
  corre, la cola se llena y los promedios de una sección quedan viejos para siempre. Sobrevive
  al reinicio, pero nadie la vacía. `bin/rails notas:recalcular` sigue siendo la reparación.

### 4. La cola de trabajos

`config.active_job.queue_adapter = :solid_queue` en **producción y desarrollo**, y `:test` en
tests. Que los dos primeros coincidan no es simetría por gusto: con `:async` en desarrollo, el
problema que Solid Queue resuelve solo aparecería en producción.

Vive en la **misma base**, sin `connects_to`. El generador asume una base aparte porque está
pensado para volumen; SIGA tiene *un* job que corre ~1 segundo cuando un profesor cambia una
ponderación. Una segunda base sería otra cadena de conexión que configurar, respaldar y
monitorear — y en el plan de 25 $ al mes, cada pieza que no hace falta es una que puede fallar.

Sus once tablas **no llevan RLS, a propósito**: no son datos de ningún colegio, son la maquinaria
de la plataforma, igual que `SigaStaff`. El colegio de un job viaja en su payload y lo restablece
`CarriesSchool` antes del `perform` (`MOR-88`). Con RLS puesto, un worker sin contexto no vería
ni sus propios trabajos.

```
    profesor cambia un peso  →  job en la TABLA  →  deploy  →  el worker lo toma
    (antes: job en memoria del proceso web  →  deploy  →  se perdió, sin error)
```

Verificado a mano: encolar, matar el proceso que encoló, levantar `bin/jobs`, y el trabajo se
ejecuta. Sin worker, se acumula y espera — que es exactamente lo que se quería.

### 5. Quién entra al sistema, y quién solo existe en él

Decisión de producto de agosto de 2026, investigada con los competidores globales. La ley
(GDPR/COPPA) empujó a todos al mismo lugar; Venezuela **no tiene ley de protección de datos**,
así que acá la razón es puramente de producto: un niño de 8 años no tiene correo, y quien
consulta sus notas es su madre.

```
   Student         nunca entra   ·  el que consulta es su representante
   Representative  opcional      ·  entra si tiene correo; si no, el colegio se lo pide
   Teacher         obligado
   Admin           obligado
   SigaStaff       obligado
```

**El login es el CORREO, no la cédula.** Autenticar por cédula se evaluó y se descartó: mueve
el hueco en vez de taparlo, porque un alumno de primaria tampoco tiene cédula. Y el correo es
además el canal oficial de comunicación del sistema.

**Cuatro cosas que son fáciles de romper acá:**

1. **El índice de `users.email` es PARCIAL** (`WHERE email IS NOT NULL`). Con un índice plano,
   `''` es un valor como cualquier otro y PostgreSQL admite **uno solo** en toda la plataforma:
   el alumno 2 de 360 revienta la importación. Y no alcanza con el índice — el modelo tiene que
   convertir a `nil` el `""` que manda cada `<input>` vacío, en cada guardado.
2. **Buscar a una persona por correo DUPLICA o BLOQUEA.** Se busca por `document`, y si no hay,
   por `cedula_escolar`. **Normalizando antes de preguntar**: en la base vive `12345678` y
   `WHERE document = 'V-12.345.678'` no devuelve nada. Está en `User.normalizar_documento`,
   que es método de clase justamente para eso.
3. **La normalización del documento depende del tipo.** Cédula → solo dígitos (la nacionalidad
   ya está en `document_type`). Pasaporte y carné → alfanumérico en mayúscula: aplicarle la
   regla de la cédula le come las letras y lo deja identificando a otra persona. La
   `cedula_escolar` **no** se normaliza igual — su formato lo define el MPPE y los guiones son
   parte del dato.
4. **Un test que solo cuenta personas no prueba nada** en esta zona: bloquear un alta también
   deja el conteo quieto. La aserción tiene que exigir las dos mitades — ni persona nueva, **y**
   rol creado.

**Activar el acceso** (`MOR-143`) es `recoverable` de Devise con otro texto: el colegio genera
un código de un solo uso desde la ficha del representante, se ve en pantalla **una vez** —Devise
guarda el digest, no el código— y además se envía por correo si lo hay. Dos plazos, deducidos
del estado sin ninguna bandera: **72 h** para activar (la secretaria carga un jueves, la mamá
abre el domingo) y las **6 h** de Devise para recuperar.

⚠️ **Hoy el correo no sale**: falta `SMTP_ADDRESS` en producción (`MOR-102`), así que
`perform_deliveries` es `false`. El flujo funciona igual mostrando el enlace en pantalla.

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
- **Edudatos / EduRed** (Caracas, desde **1987**): ASP clásico, escritorio *Visual Gema* + web
  *EduRed*. Declara **195 centros y 104.000 usuarios**; el censo CT da **90 subdominios de colegio,
  90/90 vivos** (verificado 12 ago 2026). Mismo patrón que SAE: menos de la mitad de la cartera
  declarada tiene portal web. Vende que **los datos se quedan en el colegio** ("Ud. es dueño de sus
  datos") y tiene cobranza **multimoneda**.
- **Akdemia** (~2011, Wayra/Telefónica/Techstars): corre sobre **Rails**, y con **un solo host**
  (`edge.akdemia.com`) para todos los colegios — la misma arquitectura de inquilinos que SIGA, que
  por eso **no se puede censar**. Su pie declara `Académico v2.50.189 | Facturación y Pagos v1.0.0`:
  a los quince años acaban de rehacer la cobranza desde cero. Su sitio de marketing sigue diciendo
  "closed beta" (texto de ~2013) mientras el producto real lleva quince años de builds.
- **~91 % de los colegios privados no tiene ningún portal web** (~334 con portal, de ~3.900).
  Lo confirma, independientemente, una maestra con 19 años de aula: la mayoría usa Word y nóminas
  a mano, de preescolar a bachillerato, porque **los sistemas son caros para el colegio pequeño**.
  El precio es la barrera, no la funcionalidad — y ninguno de los tres apunta a ese colegio.
- **Cobranza, asistencia y portal de representantes son tabla de entrada**: los tres competidores
  los tienen y SIGA no tiene ninguno. El único hueco que nadie llenó es **persistir competencias e
  indicadores** entre lapsos y años (`MOR-136`) — un problema del docente, no del director, y por
  eso invisible para quien vende.
- Venezuela **no tiene ley de protección de datos** ni autoridad de control. El riesgo de un
  cruce de datos es reputacional y de churn en red, no regulatorio.

## Modelo de negocio: por qué los planes baratos son baratos

Decisión de Daniel, 14 de agosto de 2026. Es la lógica que ordena la arquitectura
de despliegue, así que conviene tenerla acá y no en un issue.

**La analogía es el hosting compartido.** Los planes económicos lo son porque
todos los colegios viven en la misma máquina, la misma base, la misma aplicación
y el mismo dominio. Eso es lo que le permite a un colegio chico tener acceso a
SIGA — y por eso el aislamiento por RLS no es una comodidad técnica: **es lo que
hace vendible el producto barato.**

```
   PLANES COMPARTIDOS               PLAN DEDICADO (el más caro)
   ──────────────────               ───────────────────────────
   misma base de datos              base propia
   mismo host                       host propio
   misma app                        subdominio propio dentro de SIGA
   mismo dominio                    —o incluso su propio dominio.com—
   $25 · $50 · $90                  precio a convenir
```

**Quien decide el paso al plan dedicado es el cliente, no nosotros.** Un colegio
que quiere su propia máquina y su propio dominio la paga; el resto convive, y
esa convivencia es exactamente lo que abarata al resto.

### Y de ahí sale el orden del trabajo

Para el lanzamiento **conviven todos**: colegios y equipo de SIGA, misma base,
misma tabla `users`, roles distintos. El equipo de SIGA tiene acceso amplio por
ahora, a propósito — la demanda todavía no justifica lo contrario y hace falta
poder responderle a un colegio en el momento, con las mismas vistas que él ve.

Cuando la demanda crezca se planifica la separación: la administración de SIGA
sale a su propia plataforma y las dos se hablan por API. `MOR-133` ya dejó la
frontera puesta para que ese día sea mover un namespace, no desenredar una app.

> ⚠️ El acceso amplio del equipo de SIGA es una **decisión con fecha de
> vencimiento**, no un estado deseable. `MOR-92` explica por qué —es la forma
> exacta del incidente de Canvas— y es el issue que hay que retomar cuando haya
> colegios pagando.

Backlog completo en `BACKLOG.md`. Diagrama del modelo actual y objetivo:
https://claude.ai/code/artifact/0e167ba9-8e21-4264-ac29-f7a2d9fe5523
