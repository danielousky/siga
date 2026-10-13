# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## 🔖 Dónde quedamos

El estado de avance vive en [`ESTADO.md`](ESTADO.md) — **leerlo al arrancar la sesión y
actualizarlo al cerrarla.** Está aparte a propósito: es lo que más cambia, y acá adentro
viajaría en cada petición al modelo además de invalidar el caché del prompt en cada edición.

Hasta el 5 de octubre de 2026 se llamó `RETOME.md` —por «punto de retome», la sección de
este archivo de donde salió—, y así lo nombran los commits anteriores. Daniel preguntó por
qué se llamaba así, y un nombre por el que hay que preguntar no está haciendo su trabajo.

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
suscripción mensual **por alumno**: **0,30 $ por alumno inscrito al mes, más IVA, con un
mínimo de 39 $** — desde el 12 de octubre de 2026. Un solo plan y sin nombres: todo
colegio tiene el sistema completo, y lo único que cambia es la matrícula. Cargar el
colegio es gratis; calificar, pasar lista y emitir piden la suscripción. La fuente única es
`Subscription::PRECIO_POR_ALUMNO` / `MINIMO_MENSUAL`.

⚠️ **El recorrido entero —puerta, prueba, precio, pago y cobro— está decidido en
[`docs/specs/del-registro-al-cobro.md`](docs/specs/del-registro-al-cobro.md)**, y se
construye por tandas. Antes fueron bandas (25/50/90, 30/60/90 y 39/79/119, con los
nombres Inicial · Estándar · Grande): si un documento, un PDF o un video dice eso, está
atrasado y manda el spec.

⚠️ **Subir un precio es cambiar UN número, y nada más.** Tres veces se quedó atrás una
copia escrita a mano —la descripción para buscadores, una segunda tabla en el panel de
`/siga` y la nota al pie de esa tabla, que el día de la segunda subida todavía decía
25/50/90— y ninguna rompió nada: la pantalla abre y el número se lee bien. Lo cuida
`los_precios_de_un_solo_lugar_test`, que cambia los precios por tres que no existen y
exige que cada pantalla diga ESOS: comparar contra la constante no alcanza, porque un
número a mano que hoy coincide pasa en verde.
⚠️ Y subirlo **no le cambia la factura a nadie**: cada suscripción guarda su
`precio_mensual` el día que se abre.

Documentación de referencia (PDF/PNG del proyecto, contrato y diagramas ER) en `references/`
— ese directorio está en `.gitignore`, los originales `.pages` viven en el directorio padre
`SIGA/`.

## Common Commands

```bash
# Setup en una máquina nueva — `bin/setup` ya crea el rol `siga_app` y verifica
# que NO pueda saltarse el RLS. Sin ese rol, el aislamiento no se evalúa (MOR-87).
bin/setup                          # base + rol sin privilegios + verificación
bin/rails db:seed                  # Datos de prueba: 2 colegios, 450 alumnos, 28 docentes · ~1 min

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
bin/ci                             # RLS + estilo + tests + seeds + humo, ~3,5 min
bin/smoke                          # solo el humo: web Y worker, y el recorrido HTTP por los cuatro roles
```

`bin/ci` arranca comprobando que el rol de la base **no** pueda saltarse el RLS, y no
es ceremonia: si ese rol fuera superusuario, el aislamiento entre colegios dejaría de
existir y **ningún otro paso del pipeline se daría cuenta** — los tests seguirían en
verde porque el `default_scope` de la app filtra igual.

**El CI de GitHub corre ese mismo `bin/ci`**, y cada corrida son minutos que se pagan
(el repositorio es privado): unos 12 min 30 s, que eran 19 min 41 s hasta el 6 de
octubre de 2026. Cuándo corre:

```
   push a main          sí
   PR abierto           sí, una vez por commit; el commit nuevo cancela la corrida del anterior
   rama sin PR          no  — antes sí, y con PR abierto eran DOS corridas idénticas
   solo documentación   no  — ESTADO.md, CLAUDE.md, BACKLOG.md, README.md, DESPLIEGUE.md,
                              docs/specs, docs/cards, docs/investigacion
```

⚠️ **`[skip ci]` en el mensaje**, cuando a un PR con código se le suma un commit que solo
toca documentación: `paths-ignore` mira TODO lo que cambia el PR, no el último commit, así
que sin eso lo vuelve a correr entero. ⚠️ `CHANGELOG.md` y `docs/manual/` NO se saltan: al
primero lo lee `version_test` y el segundo es lo que sirve `/manual`.
⚠️ **Ese marcador vale en CUALQUIER parte del mensaje, también en medio de una
explicación.** El commit que estrenó esta regla la contaba en su cuerpo, con el marcador
escrito tal cual — y GitHub no corrió nada: el PR quedó abierto, «sin chequeos», y sin un
solo error que lo dijera. En un mensaje de commit se escribe SOLO para usarlo; para
nombrarlo, «el marcador de saltar el CI».

⚠️ **Antes de optimizar un CI, se mira dónde se va el tiempo** — y las dos pérdidas grandes
no estaban donde uno apostaría:

```
   db:prepare SIEMBRA cuando la base es nueva     3 min por corrida, sembrando dos veces
   un test analizaba la hoja de estilos 13 veces  el 23 % de la suite, en cuatro tests
```

La primera no la decía ningún paso: el registro la mostraba bajo «Crear la base». La
segunda era `css[k]` sobre un texto con acentos, que en Ruby no es un salto sino contar
desde el principio — medio millón de caracteres, recorridos medio millón de veces. Se
encuentra con `bin/rails test --profile 25`. Y lo que se midió y NO valía la pena: bajar
el detalle del registro en los tests (4,5 %, y se pierde lo que sirve para diagnosticar).

⚠️ **La siembra no anota cada consulta** (110 s → 61 s): nadie lee ese registro.
`SIEMBRA_CON_REGISTRO=1 bin/rails db:seed` lo devuelve.

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
  (`MOR-209`). «1er Año A» tiene su guía y «1er Año B» el suyo; es quien pasa lista de
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

### 🎨 El sistema de diseño: un solo hilo para los cuatro roles

**Antes de escribir una pantalla se mira `/siga/estilo`** — el catálogo vivo,
tras la puerta de `SigaStaff`. Ahí está cada componente con su Haml al lado, y
se dibuja con los helpers de verdad: si algo cambia, cambia primero ahí.

Daniel, 8 de septiembre de 2026: *«hice una captura de por lo menos cinco tipos
de títulos principales. Eso es inconcebible… un framework vale, nuestro propio
framework»*. Había siete formas de título, y la cabecera correcta la usaban
**14 pantallas de 84**. El problema no era que faltara el framework: era que
**era opcional**.

**Los seis tonos de botón, cada uno con su verbo** (`MOR-172`, revisado):

```
   guardar     verde       QUEDA GUARDADO    [+ Agregar] [Crear] [Guardar cambios]
   accion      índigo      mucho de una vez  [Copiar de otro año] [Cargar notas]
   documento   petróleo    algo SALE         [Descargar] [Emitir]
   ver         azul suave  mirar sin tocar   [Ver]
   secondary   neutro      volver atrás      [Volver] [Cancelar]
   danger      sin tono    destruye          [Eliminar]
```

⚠️ **`btn-primary` SE RETIRÓ, y no volverá.** Al pasar el alta al verde, el azul
se quedó sin trabajo — y «primario» nunca fue un trabajo: es jerarquía visual,
justo lo que `MOR-172` reemplazó por *qué hace* el botón. Si estás por escribir
`btn-primary`, la pregunta no es de qué color: es cuál de los seis verbos hace.

⚠️ **El verde NO significa «crea»: significa «esto queda guardado».** Por eso lo
llevan por igual el `[+ Agregar]` que va al formulario y el `[Crear]` que lo
envía, y también `[Guardar cambios]` en una edición, que no crea nada. El `+` es
lo único que dice «y además nace algo nuevo».

⚠️ **`boton` exige `tono:` y no tiene default.** Ese default era el agujero:
escribir un botón sin pensar qué hace daba un botón azul, y así el color volvía
a no decir nada.

**El botón de alta es idéntico en las 84 pantallas:** `[+ Agregar]` visible, el
tooltip **«Registrar \<cosa\>» obligatorio** —en el teléfono no hay hover y
«Agregar» a secas no dice de qué— y `aria-label` con el mismo texto.

**Lo que hace `sistema_de_diseno_test` que falle:** un `btn-primary`, un `boton`
sin tono, un `style=` inline con valor fijo (con interpolación sí se admite: el
ancho de una barra es un dato), una `<table>` sin `.table-academic`.

⚠️ **Los MAILERS quedan fuera de esas reglas**, y no por conveniencia: un correo
HTML necesita estilos inline y `<table>` de maquetación, porque Gmail y Outlook
descartan las hojas externas y no soportan flex ni grid.

**UNA sola cabecera para las 128 pantallas** (etapa ②): `shared/cabecera`. Había
siete formas de título, y la mayoritaria —`card-academic-header`, 110 usos—
servía para **dos cosas distintas** separadas solo por qué etiqueta escribió
cada quien. Ahora el `nivel:` se pide:

```
   = render "shared/cabecera", titulo: "Editar sección"
   = render "shared/cabecera", titulo: "Asistencia", nivel: 2

   = render layout: "shared/cabecera", locals: { titulo: @seccion.nombre } do
     = boton "Volver", sections_path, icono: :volver, tono: :secondary

   = render "shared/cabecera", titulo: "Alumnos", ruta: students_path,
            pista: "Nombre, apellido, cédula…",
            alta: { ruta: new_student_path, nombre: "Registrar alumno" }
```

⚠️ **El partial NO emite la tarjeta**, y eso es lo que lo hace componible: quien
la quiera en franja propia la envuelve en `.card-academic`; quien la quiera como
título de una tarjeta que ya existe, la pone adentro con `nivel: 2`.

⚠️ **Quedan fuera cuatro contextos, y no son deuda:** Devise (otro layout), el
sitio público, los documentos en PDF (son papel) y **el panel de `/siga`**, que
es deliberadamente distinto al del colegio (`MOR-133`).

Specs: [`sistema-de-diseno.md`](docs/specs/sistema-de-diseno.md) (①) y
[`cabecera-unica.md`](docs/specs/cabecera-unica.md) (②).

### ✉️ Los correos: una plantilla, y cada uno dice de quién es

Daniel, 5 de octubre de 2026, con el de «recuperar contraseña» abierto en Gmail:
*«Esto no parece para nada un correo institucional de SIGA. Parece cualquier
cosa.»* Siete de los ocho salían sin cabecera ni pie, y el remitente era una
dirección pelada.

```
   DEL COLEGIO   activar el acceso · boletín disponible · mensaje del colegio
                 y los de la contraseña, si la persona es de UN solo colegio
   DE SIGA       bienvenida · el aviso de colegio nuevo
                 y los de la contraseña, si es de dos colegios o de ninguno
```

- **Una plantilla** (`layouts/mailer`) y sus piezas en `layouts/mailer/`. De
  quién es el correo lo dice el mailer con **`a_nombre_de(colegio)`**; sin
  llamarlo, es de SIGA. ⚠️ No se deduce de `@colegio`: el aviso de «colegio
  nuevo» tiene uno y es un correo SOBRE un colegio, no DE un colegio.
- **Una plantilla de correo es contenido puro**: `titulo_de_correo`,
  `boton_de_correo`, `nota_de_correo` y `%p` (`CorreoHelper`). ⚠️ Las de Devise
  viven en `devise/mailer/`, que `sistema_de_diseno_test` NO exime: no pueden
  llevar un `style=`.
- ⚠️ **El escudo: solo se ARMA su dirección** (`escudo_para_correo`). Nada de
  `.processed` en un mailer — es el `IOError` de «Descargar las listas» (`§ 1`).
- ⚠️ **Las imágenes llevan dirección PERMANENTE**: `public/correo/siga.png`,
  nunca los assets. Un correo vive años, y una imagen con la huella de un
  despliegue en el nombre desaparece con el siguiente.
- **Las letras son las de la app, sin descargar nada.** Gmail ignora las
  tipografías web y Outlook clásico, al no encontrarlas, cae en Times New Roman.
- ⚠️ **El nombre del colegio es TEXTO**, nunca parte de una imagen: Outlook de
  escritorio bloquea las imágenes hasta que la persona acepta.
- **Los ocho llevan versión en texto y su adelanto** (`content_for :adelanto`),
  que es lo que la bandeja muestra al lado del asunto.
- **«MANAGE NOTIFICATIONS» lo agrega ElasticEmail** a todo correo y no se apaga
  por código. Se reemplaza con un enlace propio que lleva su etiqueta
  `{unsubscribe}` — ⚠️ solo cuando el correo sale por ElasticEmail, o el enlace
  llevaría a «{unsubscribe}», tal cual.
- ⚠️ **Los correos de la cuenta salen de `CuentaMailer`**, no de
  `Devise::Mailer`, y preguntan `User#unico_colegio`: quien recupera su
  contraseña no tiene sesión. Su canal de ElasticEmail conserva el nombre
  `siga-devise-…`, o las estadísticas se partirían en dos.

Se MIRAN en `/rails/mailers/correos_de_siga`. Los cuidan
`correos_con_identidad_test` y `correos_en_el_telefono_test`, que los abre a
600 y 380 px: encontró que el aviso de colegio nuevo se corría 27 px de lado en
un teléfono, cosa que nadie habría visto leyendo el HTML.
Spec: [`correos-con-identidad.md`](docs/specs/correos-con-identidad.md).

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

- **«Área de aprendizaje», nunca «materia»**, en lo que alguien lee (`MOR-212`).
  La palabra vive en `Vocabulario`: larga donde se decide —un título, un
  aviso—, corta («Área») donde el contexto ya lo dice —una tabla, un contador,
  el buscador—. Es la del MPPE: un sistema que dice «Materias» obliga al
  director a traducir en cada pantalla.
  ⚠️ Lo que NO se lee no cambia: el modelo es `Subject`, la URL `/materias`, las
  claves `"materias"` de un boletín emitido.
  ⚠️ Las plantillas de Excel del importador conservan «MATERIA» y «CÓDIGO DE LA
  MATERIA» —es lo que el colegio escribe en SU planilla— y por eso el error de
  una celda vacía sigue siendo «Sin materia»: con «Sin área», buscaría una
  columna que no existe.
  ⚠️ Cambia la concordancia, así que no se reemplaza a ciegas: «el área» y «un
  área», pero «esta área» y «la misma área». Y «agrupar las materias por área»
  pasaba a decir «las áreas por área».
  ⚠️ Daniel fijó la palabra el 3 de septiembre y el 5 de octubre encontró
  «MATERIA» en el boletín impreso: estaba escrita a mano en el PDF, y otras
  cien frases en pantallas y avisos. Lo cuida `nomenclatura_del_mppe_test`, que
  lee el texto de vistas, mensajes y `es.yml` contra una lista corta de
  excepciones, cada una con su porqué.
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
- **Un test de sistema no cuenta sin esperar**: `assert_selector …, count: n`,
  nunca `all(…).size`. `all` mira una sola vez y solo ve lo visible, y lo que
  entra con una animación arranca en `opacity: 0` (`plan-aparece`): contando en
  ese primer cuadro, el indicador recién creado no está. ⚠️ No falla en una
  máquina rápida — falló en GitHub, dos corridas de cinco con el mismo código,
  siempre en la misma línea («esperaba 3, vio 2»). Se reprodujo deteniendo la
  animación un segundo. Lo cuida `los_tests_de_sistema_esperan_test`, que
  también ve el conteo escondido en un ayudante (`def filas = all(…)`).
- **Y no escribe en una página que todavía no lo oye.** Chrome DESCARTA —no
  encola— lo que se teclea y lo que se toca en una página recién abierta, y
  Selenium avisa al cargar, no cuando ya se puede usar. `visit` + `fill_in` se
  lee correcto y, con el procesador ocupado, a veces escribe a ciegas:

  ```
     LA QUE PASÓ                         LA QUE FALLÓ
     10 ms  carga   sin pintar           10 ms  carga   sin pintar
     46 ms  foco    PINTADA              40 ms  foco    SIN PINTAR
     56 ms  teclas, clic, envío          … y nada más: ni una tecla, ni el clic
  ```

  El campo queda vacío, el navegador bloquea el envío por ser obligatorio, y el
  test dice «no encontré la fila» de un formulario que nunca salió. Son dos
  mitades, las dos en `ApplicationSystemTestCase`:

  ```
     visit      toca una tecla que no escribe nada (Shift) hasta que la página la oye
     fill_in    comprueba que lo escrito QUEDÓ, y reescribe si el campo sigue vacío
  ```

  ⚠️ **Se PREGUNTA, no se adivina.** El primer arreglo esperaba el primer
  pintado y no alcanzó: la falla volvió con el navegador diciendo que ya había
  pintado. La tecla muda entra por la misma vía que las de verdad: si llegó,
  llegan. Altas que fallan con el procesador saturado:

  ```
     sin arreglo                                3 de  56
     esperando el primer pintado                2 de 160
     la tecla muda, rindiéndose ante un error   1 de 120
     la tecla muda, sin rendirse                0 de 320
  ```

  De esas 320, la mitad corrió ya con `fill_in` comprobando, y no tuvo que
  reescribir ni una vez: es una red, no lo que lo arregla.
  ⚠️ **Una espera que se rinde ante un error no es una espera.** La primera
  versión de la tecla muda abandonaba si el navegador devolvía un error
  pasajero —pasa justo mientras cambia de documento— y el test seguía a ciegas
  en el instante que debía evitar. Ahora vuelve a preguntar. ⚠️ Que ESO fuera
  la causa de la falla que quedaba es mi lectura, no una medición: después del
  cambio no volvió a fallar, pero tampoco apareció ningún error que rescatar.
  ⚠️ **Cómo se encontró, que es lo que vale para la próxima**: el registro del
  servidor dijo que el envío nunca llegó; la captura, que el campo estaba vacío;
  y una caja negra dentro del navegador
  (`Page.addScriptToEvaluateOnNewDocument`, anotando foco, teclas y clics con
  su hora) dijo que las teclas no habían llegado NUNCA. Agregarle mediciones al
  test hacía desaparecer la falla — eso ya era la pista: la carrera estaba
  entre abrir y escribir. Solo se reproduce con el procesador saturado
  (catorce `yes > /dev/null` en una máquina de diez núcleos), y hay que correr
  el archivo de verdad: copiar la secuencia a un bucle no la reproducía.
  `SIGA_DIAG=1` hace que la base avise cuando una página no oyó o hubo que
  reescribir un campo.
  ⚠️ Es probable que sea lo mismo que `tocando` y `tocar_para_*` vienen
  tapando con reintentos y atribuyendo a Turbo («se traga el clic»). No está
  demostrado para esos casos, así que los reintentos se quedan.

### ⚠️ Dentro de un turbo_frame, TODA salida tiene que devolver ese frame

Mordió **cuatro veces en dos días**, siempre con el mismo síntoma: la pantalla
entera reemplazada por «Content missing».

```
   1 · un enlace que salía a otra pantalla     →  data-turbo-frame="_top"
   2 · `new` con el frame escrito a mano       →  frame_que_pregunta
   3 · el error de borrar, redirigiendo al show→  ruta_de_vuelta
   4 · «Cancelar» apuntando al listado         →  ruta_de_vuelta
```

⚠️ **Ninguna falla por ningún lado.** La petición devuelve 200, el HTML es
válido, el log no dice nada y los tests de integración pasan en verde: Turbo
pide un frame, la respuesta no lo trae, y escribe el hueco. Solo se ve
mirando esa pantalla.

Las salidas son **tres y no hay una cuarta que funcione**: volver a algo que
contiene el frame (`ruta_de_vuelta`), contestar en el que preguntó
(`frame_que_pregunta`, que lee el encabezado `Turbo-Frame` contra una lista
blanca), o salir diciéndolo (`data-turbo-frame="_top"`).

Lo cuida `el_frame_sobrevive_test`, que pide como pide Turbo, sigue los
redirects **y recorre los enlaces de cada formulario** — el cuarto caso entró
justamente por ahí, que era el hueco de la guarda anterior.

⚠️ Y una que no es de Turbo pero se paga igual: **Stimulus busca sus `target`
DENTRO del elemento del controlador.** Con `data-controller` en la barra de
ponderación y los campos en las filas de abajo, `pesoTargets` salía vacío —
la barra se dibujaba bien al cargar y no se movía nunca. No falla nada:
simplemente no pasa nada, y un test de integración lo ve todo correcto.

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

⚠️ **Y una consecuencia que muerde lejos de acá: en una petición, «después de confirmar» es
cuando ya terminó.** Como todo corre dentro de UNA transacción, cualquier `after_commit` espera
al final de la petición — y Active Storage guarda así los archivos.

```
   logo.variant(…).processed.download     lo que enseña la documentación de Rails
        │
        ├─ .download   la miniatura todavía no está guardada  →  FileNotFoundError
        └─ al cerrar   Rails la guarda desde un temporal que ya cerró  →  IOError: closed stream
```

«Descargar las listas» daba un 500 en todo colegio con escudo, y antes de eso el Excel salía
**sin** escudo en silencio, porque el primer error lo tapaba un `rescue`. Estuvo así desde que
existe la descarga: ningún test le ponía escudo al colegio. Ahora la miniatura se calcula con
`ActiveStorage::Variation#transform`, que no guarda nada ni deja nada pendiente.
**Lo que se adjunta no se lee en la misma petición, y lo que se necesita ahora no se le encarga
a un `after_commit`.** Los PDF no lo sufren: `School#imagen_para_pdf` baja el original.

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

⚠️ **En PRIMARIA, una evaluación mide UNA COMPETENCIA**, y sus indicadores
nacen después (`MOR-136`, segunda mitad). Los indicadores cuelgan de la
competencia y **no se repiten entre evaluaciones**: la competencia se repite, ellos la REPARTEN —el
examen mide «suma con reagrupación» y el taller, «estima antes de calcular»—.
Por eso es una columna en `indicators` y no una tabla intermedia.

```
   Resuelve problemas de adición
     ∘ Suma con reagrupación      ──►  Examen del lapso   40 %
     ∘ Resuelve en dos pasos      ──►  Taller en equipo   30 %
     ∘ Compara dos estrategias    ──►  libre
```

La validación es **`on: :create` y solo si `Grade#por_competencias?`**. Siempre
rompería la edición en línea de lo escrito antes de la regla; sin la guarda de
nivel dejaría a todo bachillerato sin poder crear una evaluación. Lo viejo se
**avisa** en el plan, como `MOR-229` avisa la competencia sin evaluaciones.

⚠️ **El indicador NO se exige al crear, y es lo que hace posible una sola
pantalla.** Un indicador cuelga de la evaluación que lo mide, así que al nacer
la evaluación todavía no hay dónde ponerlo: exigirlo obligaba a un formulario
aparte que los pidiera de antemano —el textarea «uno por línea»— justo lo que
Daniel objetó el 23 de septiembre. La evaluación nace con su competencia, y los
indicadores se agregan sobre la fila ya guardada. Que falten **se avisa** en el
plan, que es donde se ven.

⚠️ **La jerarquía del plan es COMPETENCIA ▸ EVALUACIÓN ▸ INDICADORES**, cada
uno en su contenedor (21 de septiembre). El indicador **nace dentro de la
evaluación que lo mide** —el campo vive en esa fila— porque uno sin evaluación
no se imprime en la boleta ni se ve en el plan: es un dato invisible. Por eso
el textarea de «un indicador por línea» **se retiró**, y por eso los chips de
«también mide» también: le ofrecían a una evaluación cualquier competencia del
plan, contradiciendo lo que la pantalla enseña.

⚠️ **Y hay UNA manera de dar de alta una evaluación: la fila del plan.**
Daniel, 23 de septiembre: *«¿te parece bien que haya 2 maneras distintas de
hacer lo mismo?… parece que fueran desarrollos distintos»*. Tocar «Agregar
evaluación» abre **la misma fila de la edición** con borde punteado, ✓ para
crear y ✗ donde va el basurero de las demás; el botón desaparece mientras está
abierta. El formulario completo (`/evaluaciones/nueva`) sigue existiendo para
lo que siempre hizo —decir qué competencia mide— y **no reparte indicadores**:
eso era la segunda manera.

⚠️ Borrar una evaluación **borra** sus indicadores (`destroy`), y el aviso lo
dice antes. Salió con `nullify` y Daniel lo revirtió el 22 de septiembre: uno
suelto no se imprime en la boleta ni se ve en el plan, así que «conservarlo» era
guardar un dato que nadie iba a volver a encontrar. Por lo mismo, **traer el
plan de otro profesor ya no trae indicadores** — sin las evaluaciones que los
midan no tienen dónde vivir.

⚠️ **El peso se teclea Y se desliza, y el deslizador NO lleva `name`.** Daniel,
23 de septiembre: *«podemos robarle un poco de espacio al texto y que la persona
deslice en lugar de escribir»*. Con los dos controles enviando
`weight_percentage`, el formulario mandaría el peso dos veces y el servidor se
quedaría con el último del marcado — el que el profesor no tocó, y sin error en
ningún lado. Los junta `peso-deslizante`, que además **copia el tope del número
en vez de calcularlo otra vez**: el máximo es lo que QUEDA contando a las otras
evaluaciones, lo recalcula `reparto` en vivo, y dos cuentas del mismo número se
separan el día que una cambie.

⚠️ **Entrar y salir suave son DOS mecanismos, porque el navegador solo regala
uno.** Lo que APARECE se anima con `animation`, que corre al insertarse el
elemento. Lo que SE VA no tiene ese momento: Turbo reemplaza el bloque y el nodo
desaparece de golpe. Por eso el desvanecido lo empieza `se-desvanece` mientras la
petición viaja — y con `turbo:submit-start` y **no** con el clic, que está antes
del «¿Borrar…?»: decir que no dejaría la fila medio borrada en pantalla. Y entra
solo lo que de verdad es nuevo (`--recien`, que pone el servidor y solo en el
alta): el stream reemplaza la competencia entera, así que animar `.plan-indicador`
a secas haría parpadear la lista completa al corregir una letra de cualquier otro.

⚠️ **Con notas cargadas, el botón de borrar se apaga con `aria-disabled` y su
tooltip dice por qué.** No `disabled`: el nativo no recibe foco, y el tooltip
—que ES la explicación— aparece con `:hover` y `:focus-visible`. Y la fila lleva
una pastilla con **cuántas notas tiene de cuántos alumnos**, con el vocabulario
de la libreta.

⚠️ **En la BOLETA, cada indicador lleva SU nivel** —el de la evaluación que lo
midió— y salen **solo los medidos**. La competencia conserva el suyo, que es el
ponderado de sus evaluaciones. Hasta esta regla el nivel por indicador era
imposible: habría exigido una regla de agregación —moda, promedio, mínimo— que
ninguna norma define. Con un indicador por evaluación es una **lectura**, no una
cuenta. Vive en `PlanEvaluado`, que usan la boleta y el portal de la familia.

⚠️ **Un boletín EMITIDO no cambia**: los `snapshot` viejos guardaron los
indicadores como una lista de textos y `PlanEvaluado.indicadores_de` los sigue
leyendo así. No se migran — reescribir un documento emitido es lo que el
snapshot existe para impedir.

⚠️ **Traer el plan del año pasado trae las evaluaciones SOLO si lo dictaba el
mismo profesor.** Decisión de Daniel: una evaluación es una decisión pedagógica
de quien evalúa —el peso, la fecha, qué mide— y heredarla de otro le pone un
criterio ajeno que no va a revisar. Las competencias sí se heredan: describen
qué enseña el grado. Entre hermanas siempre va todo, porque son del mismo
profesor.

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
  ⚠️ **Registrarse manda DOS correos, a dos personas**: la bienvenida a quien se registró y
  el aviso a SIGA (`PlataformaMailer#colegio_registrado`, a `SIGA_AVISOS_EMAIL`), que es
  como el equipo se entera de que entró un cliente. El segundo estuvo **un mes sin salir**:
  `MOR-208` borró su línea al juntar el registro en un formulario, y el test exigía «un
  correo» — la mitad que faltaba no se notó. Ahora se cuentan los dos, cada uno por su
  destinatario. Y se encola con `Current.en_el_colegio(colegio)`: quien se registra todavía
  no tiene sesión, y un job sin colegio lee cero grados y dice «todavía no eligió sus
  niveles» de un colegio que sí los eligió.
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
- ~~**Producción corre con los datos de demo** (`MOR-146`)~~ → **hecho**, el 17 de
  septiembre de 2026. La base quedó vacía —898 personas, 4 colegios, 9.512 notas— con
  respaldo verificado antes. El catálogo de planteles se resembró aparte: `demo:limpiar`
  se lo lleva y no es de ningún colegio.
  ⚠️ Lo que queda de esa decisión: **ya no hay datos para MOSTRAR SIGA**. Una demo a un
  colegio nuevo se monta con `prueba:campo`, que nace vacío a propósito.
- **Colisión de nombres:** `Grade` es "grado escolar", pero `ActivityLog::LABELS` traduce
  `grade_created` como "Calificación registrada". Dos conceptos, un nombre.
- **El worker hay que levantarlo.** El `Procfile` declara `web` y `worker`; si el segundo no
  corre, la cola se llena y los promedios de una sección quedan viejos para siempre. Sobrevive
  al reinicio, pero nadie la vacía. `bin/rails notas:recalcular` sigue siendo la reparación.
  ⚠️ **El humo levanta los DOS**, con la orden del `Procfile`, y es lo único que prueba que el
  worker arranca. Levantaba solo el web, así que `/salud` dependía de la suerte:

  ```
     cola vacía                     200   pasa
     un trabajo de hace 2 minutos   200   pasa
     un trabajo de hace 6 minutos   503   falla, y el código no cambió
  ```

  En GitHub fallaba SIEMPRE, y con razón: sembrar la base de desarrollo deja dos trabajos
  —el análisis de cada escudo que se adjunta—, la suite tarda doce minutos en llegar al
  humo, y allá no corría ningún worker. `/salud` hacía su trabajo; faltaba quien vaciara la
  cola. Ahora `bin/smoke` exige tres cosas: que el worker arranque, que la cola quede vacía
  y que nada haya fallado al procesarse.
  ⚠️ **«La cola quedó vacía» no distingue procesar de fallar**: un trabajo que revienta
  también sale de la cola. Lo que los distingue es el contador de fallidos, leído ANTES de
  arrancar el worker y después. Y se compara, no se exige en cero: un fallido viejo en la
  base de desarrollo no es culpa del código que se está probando.

### 5. La cola de trabajos

`config.active_job.queue_adapter = :solid_queue` en **producción y desarrollo**, y `:test` en
tests. Que los dos primeros coincidan no es simetría por gusto: con `:async` en desarrollo, el
problema que Solid Queue resuelve solo aparecería en producción.

Vive en la **misma base**, sin `connects_to`. El generador asume una base aparte porque está
pensado para volumen; SIGA tiene *un* job que corre ~1 segundo cuando un profesor cambia una
ponderación. Una segunda base sería otra cadena de conexión que configurar, respaldar y
monitorear — y en el plan de 39 $ al mes, cada pieza que no hace falta es una que puede fallar.

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
   0,30 $ por alumno + IVA          precio a convenir
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

### 7. Cargar es gratis, y el límite es por FUNCIÓN

Decisión de Daniel, 27 de agosto de 2026, y ratificada el 9 de octubre —*«dejar
libre la entrada pero limitar el procesamiento (calificar o asistencia) y la
salida»*— en el spec `del-registro-al-cobro`. El corte **no es por número de
registros ni por tiempo**:

```
   LIBRE, SIN TOPE NI FECHA           SE ACTIVA CON LA SUSCRIPCIÓN
   ────────────────────────           ────────────────────────────
   ENTRADA                            PROCESAMIENTO
   alumnos, representantes            calificar, pasar lista, cerrar el lapso,
   profesores, áreas                  reparaciones, valoraciones, informes,
   secciones, inscripciones           la cobranza, los correos a las familias
   el plan de evaluación              SALIDA
   el importador y su plantilla       boletines, constancias, certificados,
                                      documentos del MPPE, listas en Excel,
                                      los portales de la familia y del alumno
```

**Por registros rompe la importación a mitad de camino:** con matrícula promedio
de 360 y tope en 200, la fila 201 falla y el colegio queda con media matrícula y
un problema de datos, justo cuando debía sentirse poderoso. **Por tiempo** empieza
a correr en septiembre, que es cuando nadie en un colegio tiene un minuto.

⚠️ **Cada controlador del colegio está en UNA de cuatro listas** de
`RespetaLaSuscripcion` —siempre abierto, entrada, con suscripción, solo con
suscripción—, y `frontera_de_lo_gratis_test` lo exige. La lista anterior nombraba
lo que existía el 27 de agosto, y lo construido después quedó afuera: con un
preescolar se operaba completo sin pagar. Un controlador nuevo sin lista no pasa
el CI; y si llegara sin ella, en gratis queda cerrado.

⚠️ **Un colegio SIN fila en `subscriptions` cuenta como gratis**, y ninguno queda
sin ella: el registro y el alta desde `/siga` la abren con
`Subscription.abrir_gratis!`. Hasta el 12 de octubre de 2026 era al revés —sin
fila era acceso completo y sin fecha— y por esa puerta se entraba a todo el
producto, gratis y para siempre. El colegio de los tests nace pagando
(`escenario_academico`, `suscripcion: :por_alumno`).

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

### 11. Los certificados, y por qué nadie los encontraba

Existían desde el 11 de septiembre de 2026 (`MOR-99`) y Cyndi los dio por
faltantes el 18. Daniel, 1 de octubre: *«creo que ella nunca vio los
certificados, no los encontró»*. Estaban en la última tarjeta de la ficha de
cada alumno, mientras el menú «Documentos» ofrecía dos pestañas.

```
   Documentos
   [ Boletines | Constancias | Certificados ]     ← la tercera, del 1 de octubre

   el grado decide el papel:
   3er Nivel         Certificación de Estudios de Inicial
   1er y 2do Nivel   Constancia de Prosecución de Inicial
   6to Grado         Certificado de Educación Primaria
   1ro a 5to Grado   Constancia de Prosecución
   Media             Certificación 31059
```

Un alumno o la sección entera, en un PDF con una página por alumno. La tarjeta
de la ficha **se queda**: la mamá que llega por el papel de su hijo sigue siendo
un caso, y ahí vive el Excel de la 31059. Spec:
[`certificados-en-documentos.md`](docs/specs/certificados-en-documentos.md).

⚠️ **El mismo papel tiene DOS puertas, y la suscripción las mira distinto.** La
ficha lo pide por `GET`; la pestaña, por `POST`. Por eso `certificados#create`
está en las dos listas de `RespetaLaSuscripcion`: en `ACCIONES_CON_PLAN`, o el
plan gratuito emitía por la pestaña lo que la ficha le niega; y en
`SIEMPRE_PERMITIDO`, o el colegio vencido perdía por la pestaña lo que por la
ficha sigue sacando. Una puerta nueva para algo que ya existía hay que
recorrerla contra las DOS.

⚠️ **Quien repite queda fuera de «toda la sección» — y solo en primaria.** El
papel de primaria dice *«siendo promovido(a)»* sin mirar las notas: de a uno lo
decide quien lo firma, de a veinticuatro nadie lo mira. No es un bloqueo:
eligiéndolo en el desplegable, sale. La regla es **del papel, no de la
pantalla** — la 31059 es un historial de notas, cierto también para quien
repite, y ahí no se excluye a nadie. «Sin calificación definitiva» **no** es
«repite»: es el caso normal de un cliente nuevo, sale con la línea en blanco y
la pantalla lo avisa antes.

⚠️ **«Repite» se pregunta en un solo sitio**: `PromocionDeAlumnos.veredicto`.
Estaba en un método privado atado a la promoción del año entero; se SACÓ, no se
copió. Escrita dos veces, la pantalla de promoción diría que un alumno repite y
su certificado, que pasó.

⚠️ **Un PDF de varios alumnos no memoriza nada que salga de `@d`**
(`UnDocumentoPorAlumno`). Cada dibujante lee `@d`, y `@d` cambia en cada vuelta:
un valor guardado «para no calcularlo dos veces» se queda con el del alumno
anterior. No falla nada — el PDF sale con sus veinticuatro páginas y la segunda
dice el colegio o el tipo de la primera. Por eso `tipo` es un método y el
colegio de la 31059 se memoriza por código.

⚠️ **Tres piezas con su test y una costura sin ninguno.** El documento de
Inicial reventaba desde la ficha en todo colegio con director cargado: el
controlador pasaba el `Admin` y el armador le pedía `nombre_completo`, que es de
su `User`. El único test llamaba al armador sin director. Estuvo veinte días en
producción y lo encontró la pestaña nueva, por emitir por el mismo camino.
`documentos_desde_la_ficha_test` pasa por el controlador, **siempre con
director**: es el caso de todo colegio real y era el que nadie ejercitaba.

⚠️ **Una casilla de alto fijo corta lo que no cabe, sin avisar.** La 31059
escribe cada dato en un `text_box` de un renglón: a un texto largo Prawn lo
parte en dos y dibuja solo el primero. Así salió sin el AÑO la fecha de
expedición —«LIBERTADOR, DISTRITO CAPITAL 5 DE OCTUBRE DE»— en un documento que
vale tres años desde esa fecha, y en Caracas siempre. Estuvo veinticuatro días
así: el test miraba que el archivo pesara más de mil bytes. Ahora el dato se
achica antes que cortarse (`shrink_to_fit`), y el test lee la fecha entera con
el municipio de nombre más largo del país.

⚠️ **Para probar un PDF de varios hay que LEERLO**, no contar páginas:
`paginas_de` en `certificados_test` saca el texto de cada página sin una gema
—Prawn escribe sin comprimir y en hexadecimal— y es lo que deja afirmar que la
segunda página es del segundo alumno.

### 12. El boletín en papel: cuánto tarda y en cuántas hojas cabe

Tres reclamos de Daniel sobre el mismo PDF, del 1 al 5 de octubre de 2026:
*«la generación de documentos tarda mucho»*, *«se está cortando el foot»* y
*«en Media lo que falta para que entre el cuadro comparativo es poco»*.

```
   4to Grado A · 21 alumnos        ANTES       AHORA
   ────────────────────────        ─────       ─────
   armar los datos                 22,2 s      1,2 s     40.866 → 1.184 consultas
   dibujar el PDF                   4,1 s      1,0 s
                                   ──────      ─────
                                   26,3 s      2,2 s

   1er Año A · 22 alumnos          44 hojas    22 hojas  (una por alumno)
```

Son tres piezas: `ReportCardPdf` dice qué lleva el boletín, `TablaAMano` dibuja
una tabla fila por fila con el alto que le pidan, y `AcomodoEnHojas` decide
dónde cae cada cosa.

⚠️ **No era el PDF.** `ReportCardData#promedio` no guardaba su resultado y
`puesto` lo pregunta dos veces por cada compañero: la lista de materias se
armaba **43 veces por alumno**. El arreglo es memorizar — con `defined?`, no
`||=`: el promedio de quien no tiene notas es `nil`, y `||=` lo recalcula.

⚠️ **`prawn-table` salió del boletín**, por lenta —3 ms por fila contra 0,13—
y por dos cosas que hacía mal sin avisar: aplicaba el tamaño de letra de la
tabla DESPUÉS del de cada celda (las competencias pedían 7,5 y salían a 9), y
la sangría, escrita con espacios, se recortaba. Sigue en la 31059 y en el
Resumen Final, que no tienen ninguno de los dos problemas.

⚠️ **El pie no se corta ni viaja solo, y son dos reglas distintas.** Que no
viaje solo lo garantiza el PEGADO: se lleva lo que tiene encima hasta juntar
100 puntos. El RELLENO de las filas (2,5 a 7; de fábrica 4) decide lo demás, en
este orden: menos hojas si apretando cabe en una menos; si no, estirar hasta
llenar la hoja anterior; si ni así, quedarse en 4. No se estira «un poco»: una
tabla de diez filas con aire de más y media hoja en blanco es peor que antes.

⚠️ **Lo que mide un bloque se MIDE dibujándolo en un borrador**
(`alto_en_borrador`), no se suma a mano. Sumé el pie y me dio 180 cuando mide
173: esos siete puntos mandaron a otra hoja el pie de todos los boletines
anuales de bachillerato, que cabían en una. Y Prawn tiene dos trampas iguales:
`font` y `font_size` con bloque devuelven la fuente o el tamaño anterior, **no
lo que devuelve el bloque**.

⚠️ **Cuando un documento no cabe por mucho, no se aprieta: se mira qué sobra.**
El de bachillerato medía 840 puntos en una hoja de 720. Juntar renglones daba
28; lo que sobraba era una tabla entera —«situación con respecto a la sección»
repetía cada materia con su nota— y 42 puntos en blanco al lado del escudo, que
empujaba el membrete hacia abajo. Ahora la comparación son tres columnas más de
la tabla de notas.

⚠️ **Esa comparación es un COMPLEMENTO, y se dibuja como tal.** Daniel, el
mismo día: *«ese grupo es un complemento; no es la calificación como tal»*.
Ocupaba el 41 % del ancho en azul macizo y era lo primero que veía el ojo.

```
   NOTAS                                            ┆  COMPLEMENTO
   MATERIA        CALIFICACIÓN   PROMEDIO DE        ┆  MUY  BAJO MEDIO MEDIO ALTO MUY
                                 LA SECCIÓN         ┆  BAJO      BAJO  ALTO       ALTO
   Matemática          13           13,7            ┆  //// //// ////
```

Tres decisiones suyas: bandas de 22 puntos —lo que mide el rótulo «MEDIO»—,
**rayadas y no rellenas** (`trama:` en `TablaAMano`: *«si se va a imprimir se
gasta menos tinta y me dice la misma información»*, y es la quinta parte), y
separadas de las notas por un hueco (`huecos:`). Y la columna se llama
«PROMEDIO DE LA SECCIÓN»: «SECCIÓN» a secas, en un boletín, es «A» o «B».

⚠️ **Estas fallas dependen del LARGO, así que el test lo barre.** El pie se
cortaba «en algunos» boletines, y mi arreglo lo dejó solo en otros tantos: con
un boletín de ejemplo cualquiera, el test pasa en verde con el error adentro.
`LeePdf` (en `test/support`) lee el texto y las coordenadas de un PDF de Prawn
sin una gema — durante meses los tests de documentos solo miraron que el
archivo empezara por `%PDF`.

⚠️ **Y un test se prueba rompiendo lo que cuida.** «El pie no queda solo»
comparaba contra `ACOMPANA`, la misma constante que la regla: puesta en cero, el
test seguía en verde. El mínimo va escrito en el test, no leído del código.

⚠️ **Para cambiar cómo se arma un documento, primero se guarda lo que dice.**
Antes de tocar las consultas se tomó la huella de 372 boletines y después se
compararon: idénticos byte por byte. Un `snapshot` es un documento emitido.

⚠️ **Emitir en segundo plano se evaluó y NO se construyó.** Daniel lo pidió el
1 de octubre, con la sección en 26 segundos; el 5, con la sección en 2, decidió
dejarlo como está. Lo que el spec anotó en contra de construirlo: un job obliga
a guardar en disco documentos con notas de menores —hoy se dibujan y se
entregan— y convierte un worker caído en «no se pueden emitir boletines» el día
de la entrega. **Se reabre si un colegio se queja de la espera**, y ese día lo
primero es medir en producción. El registro está en
[`emision-en-segundo-plano.md`](docs/specs/emision-en-segundo-plano.md).

## 🔢 La versión

`Siga::VERSION` en `config/application.rb` es la del PRODUCTO, y **no** la del
commit. SemVer con los significados puestos desde el colegio, porque de SIGA no
depende ninguna API:

```
   MAYOR    cambia CÓMO TRABAJA el colegio    hay que avisarle y enseñarle
   MENOR    una función nueva                  se cuenta en el CHANGELOG
   PARCHE   un arreglo o un ajuste             nadie tiene que enterarse
```

⚠️ **El número COMUNICA, y ese es su primer trabajo.** Daniel, 18 de septiembre:
*«lo que quiero con estas versiones es que se genere confianza; un producto en
0.algo se ve como una beta»*. De ahí el salto de **0.10 a 1.5**: SIGA opera un
año escolar completo desde hace semanas y el número decía lo contrario.

⚠️ **Y me corrijo, porque el criterio anterior lo inventé yo.** El commit
`91abda4` escribió que «1.0.0 significa que un colegio real opera con esto» y lo
citó después como si fuera norma. No lo es de nadie: `semver.org` dice casi lo
contrario —*«if your software is being used in production, it should probably
already be 1.0.0»*— y SIGA no tiene API pública que estabilizar. El criterio que
manda es el de arriba.

⚠️ **Del 1.5.0 en adelante los tres significados sí aplican**, y el MAYOR se
reserva para lo que dice la tabla: que cambie **cómo trabaja** el colegio.

⚠️ **Subir el número son tres cosas, no una**: la constante, la entrada en
[`CHANGELOG.md`](CHANGELOG.md) y el tag `vX.Y.Z`. Lo cuida `version_test`, que
falla si el número no tiene su entrada — un colegio que reporta «la 0.9.0» tiene
que poder saberse qué había dentro.

⚠️ **`/salud` devuelve las DOS**: `version` es qué producto es y `revision` el
commit desplegado. Confundirlas hace que una versión signifique cuarenta builds.

## 🔧 Operar producción

Las tareas están en [`docs/tareas-de-operacion.md`](docs/tareas-de-operacion.md):
quién entra, qué cuentas hay, cambiar un rol, montar una prueba de campo, limpiar
la demo y respaldar.

⚠️ **`bin/rails runner` NO sirve contra producción por `dokku run`.** La orden pasa
por dos shells —el segundo se come las comillas y los bloques— y, peor, **su salida
no vuelve**: el comando corre y no se ve nada. Las tareas `rake` sí devuelven su
texto. Por eso cada cosa que haya que hacer allá se escribe como tarea.

⚠️ Y las variables de entorno **no se pueden pasar en la misma línea del `run`**: el
`env` del contenedor parte el valor en el primer espacio. Se ponen con
`config:set --no-restart`, se corre, y se quitan.

Backlog completo en `BACKLOG.md`. Diagrama del modelo actual y objetivo:
https://claude.ai/code/artifact/0e167ba9-8e21-4264-ac29-f7a2d9fe5523
