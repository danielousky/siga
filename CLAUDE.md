# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🔖 Dónde quedamos

El estado de avance vive en [`RETOME.md`](RETOME.md) — **leerlo al arrancar la sesión y
actualizarlo al cerrarla.** Está aparte a propósito: es lo que más cambia, y acá adentro
viajaría en cada petición al modelo además de invalidar el caché del prompt en cada edición.

---

## 📐 Cómo se trabaja un issue

**Antes de la primera línea de código va un SPEC**, discutido y congelado. Ver
[`docs/specs/README.md`](docs/specs/README.md) y su plantilla.

```
   ISSUE  ──►  SPEC  ──►  RAMA + PR  ──►  MERGE + DESPLIEGUE
   problema    contrato    el código      lo que ve el colegio
```

⚠️ **Una funcionalidad, una rama, un PR.** Nada va directo a `main`.

⚠️ **Si hay una DECISIÓN que tomar, hay spec.** Si solo hay algo que arreglar,
hay PR: un spec para cada corrección de texto es burocracia y se deja de leer.

---

## 🧠 Cómo se explica un cambio

Daniel necesita **conocer** el proyecto, no solo recibirlo. Cada cambio se
cuenta sintetizado y **con wireframes ASCII** —«a veces una imagen dice más que
mil palabras»— antes de cualquier prosa. Está en el `CLAUDE.md` global; se
repite acá porque este es el proyecto donde más pesa.

---

## Project Overview

SIGA (Sistema Integrado de Gestión Académica) es un SaaS de gestión académica para
instituciones educativas de Venezuela (preescolar, primaria, secundaria), vendido por
suscripción mensual según matrícula: **$30** (hasta 150 alumnos) / **$60** (151–400) /
**$90** (401–800). Los planes se llaman **Inicial · Estándar · Grande** — «Básico» y
«Premium» se cayeron en septiembre de 2026 con la subida de precio: son nombres de SaaS
gringo, y «Premium» insinuaba funciones aparte que NO existen (entre planes no se recorta
nada, lo único que cambia es la matrícula). La fuente única es `Subscription::PLANES`.

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
`maria.perez@familia.test` (representante, hijos en LOS DOS colegios) ·
`alvaro.lopez001@bolivar.edu` (alumno).

⚠️ **Para probar el consumo de las notas, entra como el REPRESENTANTE**, no como el alumno:
es a quien apunta el producto (ver `## ⚠️ Estado conocido § 6`). Los otros dos representantes
con correo son `carmen.lopez@familia.test` (una hija) y `jose.ramos@familia.test` (dos hijos en
grados distintos). `Yolanda Guerra` existe **sin correo** a propósito: aparece en el listado y
no puede entrar hasta que el colegio se lo cargue.

## Architecture

- **Ruby 3.4.9 / Rails 8.1.3.1** con PostgreSQL (`siga_development` / `siga_test`)
- **Views**: Haml (`.html.haml`) — no ERB. Todas las vistas y plantillas de Devise usan Haml.
- **Frontend**: Hotwire (Turbo + Stimulus) con Importmap (sin Node.js/Webpack)
- **Auth**: Devise sobre `User`. `ApplicationController` aplica `authenticate_user!` global —
  los controllers nuevos deben hacer `skip_before_action` para páginas públicas.
  **`email` y `encrypted_password` son OPCIONALES** (`MOR-142`): un alumno de primaria es un
  registro, no una cuenta. Quién sí necesita correo lo decide el ROL, con el concern
  `EntraAlSistema` (`Teacher`, `Admin`, `SigaStaff`). Ver `## ⚠️ Estado conocido § 6`.
- **Roles**: `User` tiene `has_many` a `Student` / `Teacher` / `Admin` / `Representative`, cada
  uno con `id` propio y ÚNICO `(user_id, school_id)` — una persona puede tener el mismo rol en
  varios colegios (`MOR-138`). Los singulares `user.student` / `.teacher` / `.admin` siguen
  existiendo y devuelven el rol **en el colegio de la sesión**, que es lo que casi todo el
  código necesita.
  `Admin#role` es un enum: desarrollador, director, finanzas, coordinador, secretaria.
  Los helpers de autorización viven en `ApplicationController` (`can_manage_students?`, etc.).
- **Los grados los fija la ley** (`MOR-153`). `GradoOficial` es una constante con los
  **quince** grados de Venezuela; el **nivel se DEDUCE del nombre** («4to Grado» es
  primaria, «4to Año» es bachillerato). La Media Técnica aporta **un** grado —el 6to
  Año— y no seis: marcarla siembra también el bachillerato, porque no hay sexto año sin
  los cinco anteriores. ⚠️ `Grade#media?` es el concepto del dominio (general **o**
  técnica); preguntar `secundaria?` a secas deja ciego al sexto año, y la certificación
  31059 es de la educación **media**. **Qué dicta un colegio se DERIVA de sus
  grados** (`School#niveles` / `#que_dicta`), y la columna `school_type` **se borró**
  (`MOR-160`): era excluyente —o primaria o bachillerato— y para la mitad del mercado
  mentía. ⚠️ `niveles` consulta con `Grade.unscoped.where(school_id:)` a propósito:
  `Grade` es `SchoolScoped`, así que preguntarle a un colegio que NO es el de la sesión
  devolvía cero filas en silencio —y eso lo hace el panel de SIGA en cada fila—. Quien
  decide qué se lee es el RLS, no el `default_scope`.
- **Profesor guía**: cuelga de la **sección** (`Section#leader_teacher`), no del grado
  (`MOR-150`). «1er Año A» tiene su guía y «1er Año B» el suyo; es quien pasa lista de
  ESOS alumnos. Del grado cuelga un `coordinator_teacher` **opcional**, que coordina a los
  guías y NO toma asistencia. Los dos son opcionales: sin guía, la asistencia solo la toma
  la dirección.
- **Identidad de una persona**: `document` + `document_type` (los cuatro documentos que acepta
  el MPPE) y `cedula_escolar` aparte — no es "otro tipo de documento", es lo que se usa
  **mientras no hay** documento, y NO se borra cuando llega. Nombre partido en `first_name` /
  `last_name` / `second_last_name`, porque el SAIME verifica el PRIMER apellido.
- **El identificador de una sección** (`MOR-170`) es corto y alfanumérico —«A»,
  «B», «U1»— y se guarda en MAYÚSCULA. No es una lista cerrada: un colegio puede
  usar «U1» o «2». Lo que se prohíbe es el texto libre. ⚠️ La normalización es lo
  que impide la sección duplicada: «a» y «A» pasan las dos el formato, pero para
  el índice único son dos filas, y el colegio descubre que tiene dos secciones A
  cuando la matrícula le queda partida. El formulario **sugiere los que el
  colegio ya usa** (`Section.identificadores_usados`, un `datalist` y no un
  `select`): el que abre su primera sección «D» tiene que poder escribirla.
- **Paginación**: Pagy. **Auditoría**: concern `Auditable` + modelo `ActivityLog`.
- **Multi-tenancy**: `Current.school` + concern `SchoolScoped` (app) + RLS con `FORCE` (base).
  La app se conecta como **`siga_app`**, un rol sin `SUPERUSER` ni `BYPASSRLS` — con cualquiera de
  los dos el RLS deja de evaluarse. Ver `## ⚠️ Estado conocido § 1`.
- **Esquema**: `db/structure.sql`, no `schema.rb` — las políticas de RLS no caben en el DSL de Ruby.
- **Módulo**: `Siga` (ver `config/application.rb`)

## Conventions

### ⚠️ Inglés y español: dónde va cada uno (`MOR-162`)

El criterio es uno y se dice en una línea: **inglés donde Rails DEDUCE un nombre
de otro, español donde nadie deduce nada.**

```
   base de datos · modelos · asociaciones   →  INGLÉS
   URLs · pantallas · textos · mensajes     →  ESPAÑOL
   servicios y conceptos del dominio        →  ESPAÑOL
```

**Por qué el inglés en los modelos no es gusto.** Rails deduce el nombre de la
tabla y el de la clase asociada pluralizando, y en español eso no funciona:

```ruby
"seccion".pluralize      # => "seccions"        ✗
"profesor".pluralize     # => "profesors"       ✗
"materia".pluralize      # => "materia"         ✗  ¡ni pluraliza!
"calificacion".pluralize # => "calificacions"   ✗
```

Todo el modelo en español costaría una inflexión a medida por cada sustantivo
irregular —ya hay tres en `config/initializers/inflections.rb`— más renombrar
veintisiete tablas. Y **nada de eso lo ve un director**.

**Lo que sí ve es la barra de direcciones**, y por eso las URLs van en español.
`resources :students, path: "alumnos"` es la opción que Rails trae justamente
para esto: deja `StudentsController`, `students_path` y `Student` intactos y
muestra `/alumnos`.

⚠️ **La excepción: `/academic_periods` queda en inglés.** «Años escolares» lleva ñ, y
una URL no la admite — quedaba `anios-escolares`, que no es español ni es nada. La regla
no es «todo en español»: es que **la URL se lea bien**, y donde el español necesita
muletas gana el inglés. El resto —alumnos, profesores, secciones, materias, grados,
inscripciones, lapsos— se escribe perfecto sin acentos.

⚠️ **En los tests, la ruta se pide por HELPER, nunca escrita a mano.** Un
`get "/students"` se rompe con el próximo cambio de nombre y deja de probar lo
que decía probar. La excepción es `bin/smoke`, que es un cliente HTTP de verdad
y ahí escribir la URL en español ES la comprobación.

- Vistas en **Haml**, no ERB
- Controllers y vistas en español cuando no espejan un modelo (`InicioController`,
  `ArranqueController`); en inglés cuando sí (`StudentsController` ↔ `Student`)
- Todas las rutas requieren autenticación por defecto; hay que saltarla explícitamente
- Los enums de dominio llevan etiquetas en constantes del modelo (ver `DemoRequest`)
- **Los botones se distinguen por QUÉ HACEN** (`MOR-172`), con tonos de la familia
  fría — verde, rojo y ámbar están reservados para el dato (ver la regla de color,
  `MOR-135`):
  `btn-primary` azul (crear, guardar) · `btn-accion` índigo (lo que hace mucho de
  una vez: copiar, promover, importar) · `btn-documento` petróleo (lo que sale:
  descargar, emitir) · `btn-ver` azul suave · `btn-secondary` neutro ·
  `btn-danger` sin tono. ⚠️ La distinción que importa no es «primario vs
  secundario»: «Copiar de otro año» crea ochenta filas y «Guardar» actualiza una.
- **Dar de alta se dice «Registrar <cosa>»**, siempre (`MOR-175`). Había cinco
  fórmulas para lo mismo —«Crear el año escolar», «Nuevo grado», «Registrar nueva
  materia», «Cargar un alumno», «Agregar una materia»— y el botón ni siquiera
  coincidía con el título de la pantalla a la que llevaba. ⚠️ «Registrar» y no
  «Nuevo/Nueva» esquiva además la concordancia de género, que es justo lo que se
  afloja cuando alguien agrega una pantalla apurado. El **submit** lo pone Rails
  desde `es.yml` («Crear» / «Guardar cambios»), así que `f.submit` va **a secas**.
  Lo cuida `nombres_de_las_acciones_test`.
  ⚠️ Los verbos de `PasosDeArranque` («Armar las secciones», «Subir la matrícula»)
  **no** entran en la regla: enseñan qué es el paso y apuntan al listado, no al
  alta — otro destino, otro nombre.
- **El tooltip es `data-tooltip`, nunca `title`** (`MOR-173`). El nativo no se
  puede estilar, tarda un segundo largo en aparecer, sale con la tipografía del
  sistema y **en el teléfono no existe** — que es donde un profesor carga notas.
  Sin librería: son treinta líneas de CSS, y aparece también con `:focus-visible`
  porque en un control que es solo un icono el tooltip **es** su nombre. Va
  DEBAJO por defecto (arriba se recorta contra el borde de la ventana);
  `data-tooltip-arriba` para las filas del final de una lista. Lo cuida
  `hoja_de_estilos_test`.
- **Los campos de una persona viven en `shared/_datos_de_la_persona`** (`MOR-177`),
  no repetidos en cada formulario: estaban escritos SEIS veces y cada copia se
  fue separando.
  `nombres/apellidos` letras+acentos+Ñ+espacio, en mayúscula, recortados al salir ·
  `cédula` **un solo campo**: el select de V/E pegado al número, solo dígitos ·
  `cédula escolar` alfanumérico **con guiones** — su formato lo fija el MPPE ·
  `sexo` botones, no desplegable · las contraseñas con el ojo.
  ⚠️ El enum de `document_type` **no** se recortó: `User.tipos_de_documento_ofrecidos`
  agrega el suyo a quien ya tenga pasaporte, o editar su ficha se lo cambiaría en
  silencio.
- **El colegio le escribe a la familia desde la ficha del representante**
  (`MOR-181`). Dos canales que NO son lo mismo: **WhatsApp** es un enlace
  (`Contacto.whatsapp_url`) que abre la app con el número puesto y termina fuera
  de SIGA; el **correo** lo manda SIGA y queda en la auditoría.
  ⚠️ El remitente **no puede ser el colegio**: ElasticEmail solo despacha
  dominios verificados. Sale de SIGA con `reply_to` a quien escribió — la mamá
  responde y le llega a la secretaria.
  ⚠️ Solo un móvil (0412/0414/0416/0424/0426) ofrece WhatsApp, y se le quita el
  cero antes del `58`: «580414…» es un número que no existe y la app abre igual,
  con un chat hacia nadie.
  ⚠️ Cada envío queda como un `Mensaje` (`MOR-186`) —a quién, quién, qué, cuándo
  y a qué dirección— y se ve en la ficha de la persona. En la AUDITORÍA queda
  solo el asunto: son dos preguntas distintas y la bitácora no es un archivo de
  correspondencia.
  ⚠️ El correo va CONGELADO en el mensaje: si después se corrige el de la persona,
  el registro tiene que seguir diciendo a dónde fue.
- **De una inscripción solo se editan la SECCIÓN y el ESTADO** (`MOR-182`). El
  alumno no: una inscripción ES «este alumno en esta sección», y cambiárselo no
  la corrige — la convierte en otra, con las notas, la asistencia y los boletines
  de la persona anterior colgando. La fecha tampoco: es un hecho.
  ⚠️ Cuidado con `user_id` vs `id`. El desplegable del alta mandaba `s.user_id`
  donde `enrollments.student_id` espera el del ALUMNO, y el conteo del panel
  comparaba igual: dos tablas, dos numeraciones, y ninguna coincidencia — en
  silencio. Aparecieron los dos el mismo día.
- **Buscar es PALABRA POR PALABRA** (`MOR-183`), y cada una puede caer en un
  campo distinto: «López Guzmán» son dos columnas —`last_name` y
  `second_last_name`— y con el término entero contra cada columna no encontraba
  a nadie. AND entre palabras (escribir más ACOTA), OR entre campos. ⚠️ Y
  `second_last_name` faltaba en casi todos los buscadores de personas.
- **Buscar ignora los acentos en las DOS capas** (`MOR-179`). La regla estaba en
  Ruby (`BusquedaSinAcentos`) y los filtros del navegador comparaban con
  `toLowerCase()` a secas, así que «sofia» no encontraba a Sofía — y en Venezuela
  eso deja afuera a López, Pérez, Guzmán, Rodríguez, Martínez, Hernández, Díaz y
  Gómez. `app/javascript/lib/sin_acentos.js` es su mitad JavaScript; las dos
  están anotadas la una en la otra. ⚠️ Va en `importmap.rb` con
  `pin_all_from "app/javascript/lib"`: sin el pin, el `import` falla **en
  silencio** y Stimulus deja de conectar el controlador.
- **El teléfono lleva su guion puesto por el campo** (`campo-telefono`):
  «0414-1234567», cuatro de código y siete de número. No valida que el número
  exista —eso no se puede saber, y rechazar un teléfono correcto es peor— sino
  que evita la letra, el espacio y el paréntesis que después rompen el enlace de
  «llamar».
- **Un campo con formato se filtra AL ESCRIBIR**, no solo al enviar: el controlador
  `campo-filtrado` (`data-campo-filtrado-permite-value="A-Za-z0-9"`) borra lo que no
  corresponde mientras se teclea. ⚠️ `pattern` **no** alcanza: es validación del
  navegador e impide enviar, no escribir. Son tres capas —filtrar, `pattern`, y la
  validación del modelo para lo que llegue por otra puerta— y ninguna sobra.
- **La ayuda va bajo demanda** (`MOR-161`): `etiqueta_con_pista` para lo que
  explica QUÉ es un campo; `.nota-ayuda` visible solo para CONSECUENCIAS;
  `placeholder` para el formato

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
  `TeacherSection` y el guía del grado (hoy `Grade#coordinator_teacher`, ver abajo), pero
  cualquier modelo con dos FK a entidades con
  colegio era candidato. Vive en el concern `ValidatesSameSchool`.

**Las dos capas, implementadas** (`MOR-86` + `MOR-87`):

```
  Petición ──► around_action ──► Current.school = colegio del ROL del usuario
                    │             (nunca de un parámetro, URL, header ni campo oculto)
                    │
                    ├─ CAPA 1 · SchoolScoped
                    │    default_scope { where(school_id: Current.school_id) }
                    │    24 modelos. Evita el error humano.
                    │    Se la saltan: unscoped, find_by_sql, SQL crudo.
                    │
                    └─ CAPA 2 · PostgreSQL RLS con FORCE
                         SET LOCAL siga.school_id, dentro de la transacción
                         23 tablas. Hace que el error no tenga consecuencias.
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
| **112** | La nota de la segunda oportunidad es la definitiva | `FinalGradeBook#calcular_definitiva` + la planilla de `/reparaciones` |

⚠️ **Un lapso NO tiene peso** (`MOR-164`). La columna `evaluation_moments.weight` existía,
se validaba y **no entraba en ningún cálculo** — el 111 manda promedio simple, así que un
«30/30/40» escrito al lado no significaba nada. Se borró: era un campo que no hacía nada y
que, por su validación de «suma ≤ 100», podía impedir crear un lapso.

⚠️ **El 70/30 SÍ es norma, y es otra cosa.** El mismo artículo dice que la nota de un lapso
se forma con 70 % de evaluaciones parciales más 30 % de una evaluación final del lapso. Eso
vive en `EvaluationActivity#weight_percentage`, que sí entra en el cálculo. SIGA no impone
esa estructura —los pesos son libres mientras cierren en 100— pero **propone el que falta**
al crear una evaluación, en vez de pedirle al profesor una resta que el sistema ya tiene
hecha.

⚠️ **La reparación es UNA sola nota, y se carga en `/reparaciones`** (`MOR-168`).

La Circular 0007 del MPPE fija cuatro momentos para presentar una materia
—octubre, diciembre, enero y junio— pero lo que queda registrado es una nota:
«el examen versará sobre el 100 % del contenido y la calificación obtenida será
la definitiva». Los cuatro intentos son procedimiento interno del colegio, y
SIGA no los modela. Decisión de Daniel: *«la reparación debe ir una sola nota;
no importa los procesos que hagan»*.

Hasta MOR-168 el Art. 112 estaba implementado **de la mitad para adelante**:
`remedial_exam_score` se leía en el boletín, en la certificación 31059, en el
panel del alumno y en el cálculo — y solo se escribía desde el importador de
historial. Un colegio que usa SIGA en el año en curso no tenía dónde cargarla.

⚠️ **`debe_reparar?` NO es `aplazado?`, y confundirlos rompe la planilla.**
Quién tiene DERECHO a reparar lo decide el promedio **anual**; `aplazado?` mira
la **definitiva**, que ya incluye la reparación. Con `aplazado?`, un alumno
desaparecía de la planilla en el instante en que se le cargaba una reparación
aprobatoria: escribir 74 en vez de 14 dejaba un error imposible de corregir.

⚠️ **La regla del 112 vive en el MODELO**, no en `GradeCalculator`. Hay dos
escritores —el cálculo y la planilla— y sobre todo: un libro **importado** no
pasa por el calculador (`return libro if importada?`), así que su definitiva no
se habría actualizado nunca al repararla. Es el caso normal de un colegio que
trae su historial y después repara.

⚠️ **Una calificación IMPORTADA no la recalcula ni la borra nadie** (`origen` en
`moment_grades` y `final_grade_books`). El historial de un colegio no tiene actividades debajo
—las cinco evaluaciones que produjeron ese 15 están en papel— y el cálculo borraba exactamente
eso. La regla de borrar está bien y no se aflojó: lo que faltaba era distinguir «sin respaldo»
de «con un respaldo que no está acá». Si alguien carga las evaluaciones de verdad, esas ganan
y la nota vuelve a ser `calculada`.

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

### 3. El importador de planillas (`MOR-126`)

Un colegio que ya usa otro sistema **no va a tipear 360 alumnos de nuevo**. Tres planillas, un
solo recorrido; `Importacion#tipo` decide qué se espera y qué se crea:

```
   matricula   alumnos y representantes   →  MatriculaInterpretada · CargaDeMatricula
   pensum      materias y profesores      →  PensumInterpretado    · CargaDePensum
   historial   notas de años anteriores   →  HistorialInterpretado · CargaDeHistorial
```

**Nada se crea solo, y nada es un callejón.** Cuando falta una entidad, la previsualización la
lista *con su conteo* —lo que delata el dedazo— y ofrece crearla de un clic: el año escolar
(con sus lapsos, contados de las columnas), el grado (proponiendo dónde cortar «3er Año C» y
qué nivel es) y la sección.

**La distinción que ordena todo es ERROR vs AVISO.** Error: la fila NO se carga, le falta algo
sin lo cual el registro no existiría. Aviso: se carga, pero alguien tiene que enterarse.
Confundirlas hace inservible al importador — si todo es error, un colegio con 45 representantes
sin correo no puede importar nada; si todo es aviso, se cargan alumnos sin nombre.

⚠️ **El correo NO es lo mismo en las dos planillas, y la diferencia es del modelo.** A un
representante sin correo se le carga igual y sale listado al final; un profesor sin correo es un
ERROR, porque `EntraAlSistema` lo exige y sin entrar no puede cargar notas. Ver `§ 6`.

**Siete cosas que ya se rompieron y no hay que volver a romper:**

1. **La fila de encabezados se detecta por la LÍNEA EN BLANCO, no por densidad.** Costó tres
   intentos («una celda menos», «la mitad»). El membrete de un colegio también es denso.
2. **Se busca por cédula, nunca por nombre, y SIN aislamiento** (`EscribePersonas`). Una persona
   es de la plataforma; su rol es del colegio. Buscar dentro del colegio la duplica y choca
   contra el índice único de `users.document` con un error que no dice nada.
3. **Y por eso hay que AVISAR cuando la cédula ya es de alguien muy distinto.** Pasó: la planilla
   sobrescribió el nombre del profesor García. Buscar por cédula es correcto y no se toca; lo que
   faltaba era notarlo.
4. **Las secciones se buscan DENTRO del año escolar de la importación.** Con `vigente` a secas,
   un import queda partido entre dos años sin que nadie lo vea. El selector va en la
   previsualización, que es donde el problema se ve.
5. **El historial NO es de un año: cada fila trae el suyo.** Por eso `HistorialInterpretado`
   sobrescribe `secciones_de_la_planilla` —agrupa por (año, sección)— y no lleva selector de
   año escolar. Y **`origen: :importada`** es lo que impide que `GradeCalculator` borre esas
   notas: no tienen actividades debajo ni las van a tener. Ver `§ 2`.
6. **Cada fila en su propio `SAVEPOINT`.** Con una transacción única, la fila 200 de 360 se lleva
   las 359 buenas. El reporte da el número de fila **del archivo** — «la fila 47», no «el
   registro 43».
7. **Un CSV no dice con qué está separado, y Excel NO usa coma.** Un Excel en español guarda con
   punto y coma —la coma ya es el separador decimal—, Numbers exporta con tabulaciones, y un
   Excel de Windows escribe en Windows-1252 con `\r\n` y a veces con BOM. `Planilla` adivina las
   dos cosas del propio archivo; el separador **por el ancho que resulta**, no contando caracteres
   (una coma dentro de una celda entrecomillada no separa nada).

**Las secciones NO se crean solas**, pero tampoco se rechaza la fila y listo: la previsualización
las lista con **cuántas filas las esperan** —«1er Año C · 18» es una sección, «1er Año Á · 1» es un
dedazo— y ofrece crearlas de un clic.

**El código de la materia es un INVENTO cuando la planilla no lo trae**, y por eso se lista antes
de confirmar: los códigos de un colegio son elecciones humanas y ningún algoritmo las acierta —en
los propios seeds, «Castellano y Literatura» es `LEN`—. Reutilizar y chocar no son lo mismo: si el
colegio ya tiene `MAT` = Matemática, la planilla que trae «Matemática» lo reutiliza.

### 4. Otros pendientes

**Resueltos** (esta lista estuvo desactualizada un tiempo; se verificó uno por uno el 15 de agosto,
y otra vez el 25):

- ~~Ruby 3.1 y Rails 7.0 fuera de soporte~~ → Ruby 3.4.9 / Rails 8.1.3.1. Los enums migraron a
  la sintaxis posicional (`enum :status, {...}`), obligatoria desde Rails 8.
- ~~`config.force_ssl` comentado~~ → `ENV.fetch("SIGA_FORCE_SSL", "true")`. Va por variable
  porque **HSTS es difícil de deshacer**: el navegador recuerda la orden meses.
- ~~`action_mailer` sin configurar~~ → SMTP completo por variables de entorno, sin atarse a un
  proveedor. `perform_deliveries` solo si hay `SMTP_ADDRESS`, y `raise_delivery_errors` en true:
  un correo que no sale tiene que aparecer en el log, no desaparecer.
- ~~Registro público abierto~~ → cerrado en `MOR-101`… y **reabierto a propósito en
  `MOR-158`**. La puerta es `/registrarse`, no `/users/sign_up`, que sigue dando 404.
  ⚠️ El riesgo que motivó el cierre —`users.email` es único en toda la plataforma, así que
  cualquiera puede quemar el correo de un profesor real— **sigue existiendo y se acepta**:
  la decisión es facilidad de registro por encima de la seguridad mientras el acceso sea
  compartir el enlace a mano. Lo que lo hace tolerable es el aislamiento: registrarse crea
  **siempre un colegio nuevo** y nunca se une a uno existente, así que el daño máximo de un
  abuso es una fila que no ve nada de nadie. Ese invariante vive en `MiColegioController` y
  no se afloja sin volver a discutir esto. `destroy` NO volvió.
- ~~Seeds sin guard de entorno~~ → abortan fuera de desarrollo.
- ~~Sin CI~~ → `bin/ci` en ~15 s (`MOR-105`), y el workflow de GitHub Actions **ya puede correr**:
  el repo tiene remoto (`danielousky/siga`, privado).
- ~~Sin Dockerfile~~ → existe, con su `.dockerignore`.
- ~~El adaptador de jobs pierde lo encolado al reiniciar~~ → **Solid Queue**, sobre la misma base
  de PostgreSQL. Ver abajo.
- ~~Nada borra los archivos de las importaciones~~ → `PurgarPlanillasJob`, todos los días a las 3.
  Se borra el **archivo**, no la fila: la importación es la bitácora de quién cargó qué. Alcanza a
  las abandonadas a medias, que eran las que se quedaban para siempre.

**Abiertos de verdad:**

- ~~**Sin monitoreo.** Nada avisa si el worker se cae o si la cola crece.~~ →
  **medio resuelto** (`MOR-167`): existe `GET /salud`, que devuelve 503 cuando el
  trabajo más viejo lleva esperando más de 5 minutos. **Falta enganchar un
  monitor externo que lo mire** — hoy nadie lo consulta, así que el aviso existe
  y no suena.
  ⚠️ `/salud` y `/up` NO son intercambiables: `/up` dice que el proceso arrancó y
  lo mira DOKKU; `/salud` dice que la cola avanza y lo mira un monitor. Si Dokku
  mirara `/salud`, un worker caído impediría desplegar la corrección que lo
  arregla.
- **Producción corre con los datos de demo** (`MOR-146`). Es lo más urgente del backlog: hay
  usuarios con contraseña `123123` y 290 alumnos inventados en la base que ve el mundo.
- **Colisión de nombres:** `Grade` es "grado escolar", pero `ActivityLog::LABELS` traduce
  `grade_created` como "Calificación registrada". Dos conceptos, un nombre.
- **El worker hay que levantarlo.** El `Procfile` declara `web` y `worker`; si el segundo no
  corre, la cola se llena y los promedios de una sección quedan viejos para siempre. Sobrevive
  al reinicio, pero nadie la vacía. `bin/rails notas:recalcular` sigue siendo la reparación.

### 5. La cola de trabajos

`config.active_job.queue_adapter = :solid_queue` en **producción y desarrollo**, y `:test` en
tests. Que los dos primeros coincidan no es simetría por gusto: con `:async` en desarrollo, el
problema que Solid Queue resuelve solo aparecería en producción.

Vive en la **misma base**, sin `connects_to`. El generador asume una base aparte porque está
pensado para volumen; SIGA tiene *un* job que corre ~1 segundo cuando un profesor cambia una
ponderación. Una segunda base sería otra cadena de conexión que configurar, respaldar y
monitorear — y en el plan de 30 $ al mes, cada pieza que no hace falta es una que puede fallar.

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

### 6. Quién entra al sistema, y quién solo existe en él

Decisión de producto de agosto de 2026, investigada con los competidores globales. La ley
(GDPR/COPPA) empujó a todos al mismo lugar; Venezuela **no tiene ley de protección de datos**,
así que acá la razón es puramente de producto: un niño de 8 años no tiene correo, y quien
consulta sus notas es su madre.

```
   Student         opcional      ·  puede entrar, pero NO es a quien apunta el producto
   Representative  opcional      ·  entra si tiene correo; si no, el colegio se lo pide
   Teacher         obligado
   Admin           obligado
   SigaStaff       obligado
```

⚠️ **«Opcional» en el alumno no es lo mismo que en el representante, y decía otra cosa.**

Acá se leía «Student nunca entra», y eso contradecía al código: existe el portal del alumno
—`dashboards/estudiante`, `dashboards/notas`, su propio menú— y funciona. La regla real es más
chica: **el alumno no ESTÁ OBLIGADO a tener correo** (`Student` no incluye `EntraAlSistema`),
porque un niño de 8 años no tiene uno. Si lo tiene, entra y ve sus notas — a un muchacho de
bachillerato no hay razón para negárselo.

Lo que sí es cierto es a quién apunta el producto: **el consumidor de las notas es el
representante**, y es la experiencia que hay que cuidar. El portal del alumno es un extra.

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
5. **`set_reset_password_token` devuelve el código en claro y guarda el digest.** Leer
   `usuario.reset_password_token` DESPUÉS envía por correo un enlace que no abre nada.

**Activar el acceso** (`MOR-143`) es `recoverable` de Devise con otro texto: el colegio genera
un código de un solo uso, se ve en pantalla **una vez** —Devise guarda el digest, no el código—
y además se envía por correo si lo hay. Dos plazos, deducidos del estado sin ninguna bandera:
**72 h** para activar (la secretaria carga un jueves, la mamá abre el domingo) y las **6 h** de
Devise para recuperar.

⚠️ **El código es de la PERSONA, no de su rol.** Representante, profesor y administrador usan la
MISMA funcionalidad, en el concern `GeneraCodigosDeAcceso`; el día que un alumno tenga que entrar
son dos líneas en su controller. Cuelga de cada controller de rol y **no** de un
`POST /personas/:id/codigo` central a propósito: `User` no es `SchoolScoped` —una persona es de la
plataforma— así que un controller central tendría que resolver a mano si esa persona es de este
colegio, y acá lo que se filtra no es una ficha, es una **llave**. El `set_teacher` /
`set_representative` que ya existe hace ese filtro con el `default_scope` del rol.

**El correo YA SALE en producción** desde el 21 de agosto: ElasticEmail configurado,
`perform_deliveries=true` y `raise_delivery_errors=true` —un correo que no sale tiene que
aparecer en el log, no desaparecer— (`MOR-102`). El enlace se muestra igual en pantalla: el
correo puede tardar, caer en spam o rebotar, y la secretaria tiene a la persona delante.

⚠️ Lo que **no** existe todavía es enterarse de un REBOTE (`MOR-145`). Hoy un correo que rebota
se queda ahí y solo se sabe si el usuario lo reporta.

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
  los tienen. SIGA ya tiene **asistencia** (`MOR-111`) y **portal de representantes** (`MOR-110`);
  de cobranza tiene el ESTADO de la suscripción (`MOR-108`) pero **nada que cobre** — `MOR-128`
  sigue abierto y es la única de las tres que falta.
  El único hueco que nadie llenó es **persistir competencias e indicadores** entre lapsos y años
  (`MOR-136`) — un problema del docente, no del director, y por eso invisible para quien vende.
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
   $30 · $60 · $90                  precio a convenir
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

### 7. El plan Inicial es gratis, y el límite es por FUNCIÓN

Decisión de Daniel, 27 de agosto de 2026. El corte **no es por número de
registros ni por tiempo**:

```
   LIBRE, SIN TOPE                    SE ACTIVA CON EL PLAN
   ───────────────                    ─────────────────────
   alumnos, representantes            calificar
   profesores, materias               pasar lista
   secciones, inscripciones           emitir boletines y constancias
   el importador de planillas         los documentos del MPPE
                                      el portal de los representantes
```

**Por registros rompe la importación a mitad de camino:** con matrícula promedio
de 360 y tope en 200, la fila 201 falla y el colegio queda con media matrícula y
un problema de datos, justo cuando debía sentirse poderoso. **Por tiempo** empieza
a correr en septiembre, que es cuando nadie en un colegio tiene un minuto.

⚠️ **`gratis` es un plan que se elige, NO la ausencia de suscripción.** Un colegio
sin fila en `subscriptions` tiene acceso completo a propósito: es el piloto o el
primer mes. Confundirlos deja al piloto sin poder calificar.

⚠️ **Y no es lo mismo que `vencida`.** Un colegio endeudado TENÍA estas funciones:
queda en solo lectura pero **sigue emitiendo constancias**, porque la deuda es del
colegio y el perjuicio no puede ser del alumno (`§ MOR-108`). Mezclar los dos
estados le quita a una familia el papel del pasaporte.

**Las pantallas no se esconden.** El director entra a la planilla de notas, ve su
sección y sus alumnos, y el aviso de qué la activa. Una pantalla escondida no
vende nada; una que se ve y no se toca, sí.

### 8. El año escolar de la sesión (`MOR-165`)

Hay **un** selector arriba, en la barra de contexto, y de ahí cuelga todo lo filtrable:

```
   U.E. Simón Bolívar   ·   Año escolar [2025-2026 ▾]   finalizado el 31 de julio
```

Antes había **cuatro** maneras de decidir el año, cada una escrita a mano en su
pantalla —`AcademicPeriod.vigente`, `.en_operacion`, el helper `periodo_vigente` y el
prefijo del importador— y se contradecían en agosto.

```
   Current.school            del ROL, jamás de un parámetro   →  límite de SEGURIDAD
   Current.academic_period   de la SESIÓN, se elige con un clic →  PREFERENCIA de quien mira
```

⚠️ **`DelAnioEscolar` NO es un `default_scope`, y `SchoolScoped` sí.** Que un colegio
se cuele es un incidente; que un año se cuele no es nada —son datos del mismo colegio,
de quien ya los puede ver—. Y al revés, un `default_scope` por año **rompería cosas que
tienen que funcionar**: el histórico de un alumno cruza años por definición, la
constancia de un egresado es de un año cerrado, y `AcademicPeriod.en_operacion` —que es
quien DECIDE el año— tendría que consultar secciones sin filtrar por el año que todavía
no eligió. Por eso el scope es explícito: `Enrollment.del_anio_de_la_sesion`.

Cada modelo declara **cómo** llega al año, y son tres profundidades distintas:

```ruby
llega_al_anio_por                       # sections, evaluation_moments  (columna propia)
llega_al_anio_por :section              # enrollments, teacher_sections (un join)
llega_al_anio_por enrollment: :section  # attendances, moment_grades    (dos joins)
```

⚠️ **El profesor NO tiene selector.** Daniel: *«los docentes no deberían necesitar ni
siquiera ver algo anterior, solo lo que están calificando»*. No es permisología: darle
el control es darle una manera de cargar notas en el año equivocado sin enterarse.

⚠️ **El año por defecto es el que TIENE ALUMNOS (`en_operacion`), no la fila más
nueva.** En agosto son distintos: la fila más nueva es el año que empieza en septiembre
y no tiene ni una sección, así que arrancar ahí es abrir el panel de un colegio lleno y
leer «0 alumnos». Es la tercera vez que aparece la trampa —`Subscription.matricula_de` y
`periodo_en_curso` fueron las otras dos— y ahora vive en un solo lugar,
`anio_por_defecto`. `anio_de_trabajo` es su hermano para las pantallas que **no pueden**
no tener año (el panel, «quién no cargó notas»): con «Todos» elegido, cae en el que
tiene clases.

⚠️ **`include LlevaElAnioEscolar` va DESPUÉS del `around_action` del colegio.** Estuvo
arriba de todo y falló exactamente como ya había fallado `RespetaLaSuscripcion`: sin
`Current.school` el RLS devuelve cero años, el `return` temprano se dispara y
`Current.academic_period` queda en nil — **en silencio**, con los listados sin filtrar y
un «Período académico debe existir» que no explica nada.

**Y lo que se deduce ya no se pregunta.** Un lapso —que se llama **lapso**, no «momento
de evaluación»— nace en el año de la sesión con su nombre propuesto. Una sección nace
en el año de la sesión, y al **editarla el año ni se muestra**: mover una sección de año
arrastraría sus inscripciones, su asistencia y sus notas, que son de ese año y de ningún
otro.

### 8.b El NIVEL de la sesión — el segundo pivote

Un colegio venezolano de tamaño medio dicta los tres niveles a la vez, y el
trabajo está partido por nivel en la realidad: la coordinadora de primaria no
toca bachillerato, y la reunión de septiembre para armar secciones se hace un
nivel por vez. Daniel: *«puede ser confuso crear una sección y que me aparezcan
preescolar, primaria y bachillerato juntos»*.

```
   Current.school            del ROL       →  límite de SEGURIDAD
   Current.academic_period   de la SESIÓN  →  preferencia de quien mira
   Current.nivel             de la SESIÓN  →  preferencia de quien mira
```

`DelNivel` es gemelo de `DelAnioEscolar` y **tampoco es un `default_scope`**, por
las mismas razones más una peor: el historial de un alumno **cruza niveles por
definición** —el mismo niño hace 6to Grado y después 1er Año— y `School#niveles`,
que es quien DECIDE qué niveles ofrecer, tendría que consultar grados sin filtrar
por el nivel que todavía no eligió. Eso es una recursión.

```ruby
llega_al_nivel_por                                 # grades   (columna propia)
llega_al_nivel_por :grade                          # sections, grade_subjects
llega_al_nivel_por section: :grade                 # enrollments, teacher_sections
llega_al_nivel_por enrollment: { section: :grade } # notas, asistencias, boletines
llega_al_nivel_por_los Enrollment, :student_id     # Student  ← SUBCONSULTA
```

⚠️ **Alumno y profesor van por SUBCONSULTA, no por `joins`.** Tienen muchas
inscripciones y muchas secciones: un `joins` los duplica —un profesor con cuatro
secciones aparecería cuatro veces— y `.distinct` rompe el `ORDER BY` sobre la
tabla unida, que es como se ordena por apellido. La subconsulta arrastra además
el AÑO: «alumnos de primaria» solo tiene respuesta dentro de un año, o quien pasó
de 6to Grado a 1er Año cuenta en los dos niveles y la suma da más que el total.

⚠️ **«Bachillerato» son DOS valores del enum** (`secundaria` + `media_tecnica`).
Con `=` en vez de `IN`, elegirlo escondería el **6to Año** de un colegio técnico
— la misma trampa que `Grade#media?` existe para evitar. Vive en
`GradoOficial::ABARCA`, y por eso el selector ofrece **tres** opciones, no cuatro.

⚠️ **El defecto es «Todos», no el primer nivel.** Un director de 360 alumnos que
abre el panel y lee 142 no concluye «estoy en primaria»: concluye que se
perdieron los datos. Es la trampa de `AcademicPeriod.en_operacion`, cuarta
aparición. Daniel lo pidió como un MODO DE TRABAJO —*«vamos a trabajar
Primaria»*— y un modo de trabajo se entra, no se hereda.

⚠️ **El filtro NO puede tocar `Subscription.matricula_de`.** Un colegio de 360
alumnos con primaria elegida se facturaría como uno de 140: la factura sale más
barata y nadie la mira. Ya usa `Enrollment.unscoped`, y lo cuida un test.

⚠️ **Donde el nivel no aplica, la pantalla lo DICE** — `el_nivel_no_aplica "…"`
arriba del controller. Un filtro que aparece puesto y no filtra hace que quien
vea ocho departamentos con «PRIMARIA» arriba concluya que primaria tiene ocho.
Y el conteo del listado se calla el nivel ahí, o miente en el mismo renglón.

⚠️ **Editar no puede perder lo guardado.** `grados_por_nivel(incluyendo:)`: una
sección de bachillerato abierta desde una sesión de primaria mostraría un
desplegable sin su propio grado, y guardar lo borraría. Ahí es donde un filtro
deja de ser preferencia y pasa a ser daño.

⚠️ **Y NO es permisología.** El día que un colegio pida «la coordinadora de
primaria no puede ver bachillerato», eso vive en el ROL —como `Current.school`—
y no acá. Un límite de seguridad que se apaga desde un desplegable no es un
límite.

Spec completo, con las decisiones y quién las tomó, en
[`docs/specs/nivel-de-la-sesion.md`](docs/specs/nivel-de-la-sesion.md).

### 9. Copiar la estructura de un año al siguiente (`MOR-166`)

Un colegio de diez secciones con ocho materias son **ochenta** asignaciones de
profesor escritas a mano cada septiembre, cuando el 90 % son las mismas del año
anterior. Es la clase de trabajo que hace que un colegio no renueve.

```
   SE COPIA                          NO SE COPIA
   ────────                          ───────────
   las secciones (1er Año A, B, C)   los alumnos    ← promover es otra cosa
   su cupo y su aula                 las notas      ← son del año que pasó
   su profesor guía                  la asistencia  ← ídem
   quién dicta qué en cada una       los boletines  ← ídem
```

Los **grados** y las **materias** no están en ninguna columna porque no son del
año: cuelgan del colegio y ya están. Lo mismo el pensum (`GradeSubject`).

⚠️ **Los alumnos NO se copian, a propósito.** Pasar un alumno de 1er a 2do Año
depende de si aprobó —Artículo 112, con su segunda oportunidad— no de un botón.
Copiar la matrícula repetiría a trescientos sesenta alumnos en el mismo grado, y
eso es lo que un director teme al leer «copiar el año»: por eso la pantalla lo
**dice antes de confirmar**, junto con la cuenta de lo que sí va a traer.

⚠️ **ERROR vs AVISO otra vez** (la misma distinción del importador, `§ 3`). Una
sección que no se puede crear es un **error** y deshace la copia entera: media
estructura es peor que ninguna. Una asignación que no se puede recrear —el
profesor renunció— es un **aviso**: se salta, se copia el resto, y se dice cuál
faltó. Cada una en su `SAVEPOINT`, o un `create!` fallido aborta la transacción
de PostgreSQL y las siguientes revientan con «current transaction is aborted».

⚠️ **Es idempotente y respeta lo hecho a mano.** Copiar dos veces no duplica
nada, y una sección que el colegio ya armó no se pisa —conserva su cupo y su
aula— pero sí se le completan las asignaciones que le faltaban. El índice de
secciones ya existentes se actualiza al crear, así que **hay que preguntar una
sola vez** si existe: preguntar de nuevo encuentra la que se acaba de crear y la
cuenta como «ya estaba» (pasó).

⚠️ **El plural se escribe, no se deduce.** `"sección".pluralize` devuelve
«sección» y `"estaba".pluralize(2)` devuelve «estabas»: el inflector de Rails es
inglés y en español **acierta por casualidad** en las palabras terminadas en
vocal. `ApplicationHelper#contar` y `#pluralizar` llevan las dos formas escritas,
y `test/integration/plural_en_espanol_test.rb` impide que el atajo vuelva.

### 10. Promover alumnos al año siguiente (`MOR-169`)

Es la otra mitad de septiembre. `CopiarLaEstructura` arma el año nuevo y lo deja
vacío; esto lo llena.

```
   1. Crear el año escolar     →  nace con sus tres lapsos       (MOR-163)
   2. Copiar la estructura     →  secciones + quién dicta qué    (MOR-166)
   3. Promover a los alumnos   →  los inscribe en esas secciones (MOR-169)
```

Las cinco situaciones, y **ninguna se guarda: se deducen de las notas**:

```
   PROMUEVE   aprobó todo, o arrastra dentro del tope    → el grado siguiente
   REPITE     arrastra más que el tope                   → el mismo grado
   EGRESA     el grado siguiente no lo dicta el colegio  → no se inscribe
   SIN DATOS  no tiene notas definitivas cargadas        → lo decide el director
   RETIRADO   su inscripción no es `regular`             → no se toca
```

⚠️ **SIN DATOS es el caso NORMAL de un cliente nuevo**, no un error. Un colegio
en su primer año con SIGA tiene las notas del año anterior en su sistema viejo o
en papel. Si la pantalla asumiera que siempre hay notas, no serviría en el único
momento en que hace falta. Por eso existe «Pasar a todos al siguiente grado»: el
director asume la decisión y queda registrada como suya.

⚠️ **El tope de arrastre es del COLEGIO** (`schools.tope_de_arrastre`, por
defecto **2**). La referencia venezolana son dos materias pendientes y en el
último año ninguna, pero los mecanismos los fijan circulares del MPPE que
cambian y en primaria la norma es menos clara. Decisión de Daniel: SIGA propone
el número correcto y el colegio lo corrige sin esperar un despliegue. El valor
por defecto es 2 y **no cero**: sin default, los colegios que ya existían habrían
mandado a repetir a todo el que aplazó una materia.

⚠️ **El grado siguiente sale del catálogo, sin casos especiales.**
`GradoOficial::CATALOGO` tiene los quince en orden, así que «6to Grado» va a «1er
Año» porque están uno detrás del otro. Y **egresar es simplemente que ese grado
no está entre los del colegio**: uno de solo primaria egresa en 6to Grado sin
configurar nada.

⚠️ **Nada se escribe sin confirmar**, como en el importador: se muestra la cuenta
—«181 pasan, 18 repiten, 1 egresa»— y el director acepta. Promover a trescientos
sesenta alumnos al grado equivocado no se deshace con un botón. Y es idempotente:
correrlo dos veces no duplica inscripciones.

⚠️ **La auditoría guarda UN hecho, no trescientas inscripciones**
(`alumnos_promovidos`). En la pantalla que contesta «¿por qué mi hijo quedó en
2do Año B?», lo que hay que ver es quién corrió la promoción, desde qué año y con
qué criterio.

Backlog completo en `BACKLOG.md`. Diagrama del modelo actual y objetivo:
https://claude.ai/code/artifact/0e167ba9-8e21-4264-ac29-f7a2d9fe5523
