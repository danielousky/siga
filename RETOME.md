# 🔖 Punto de retome — actualizado 15 de agosto de 2026 (madrugada)

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
- **`MOR-88` · El colegio viaja con el job.** Commit `8cf9dc9`. Concern `CarriesSchool`: el
  `school_id` se serializa en el payload al encolar —el único momento en que el contexto es un dato
  confiable— y se restablece, en la app y en la base, antes del `perform`. Por defecto un job
  **exige colegio** y levanta `CarriesSchool::SinColegio` si no lo trae; `colegio_opcional` y
  `de_toda_la_plataforma` son las dos salidas, explícitas y grepeables. `MailerDeliveryJob`
  reemplaza al de Rails, que no heredaba de `ApplicationJob` y por lo tanto no llevaba colegio.

  Lo encontró un test que parecía trivial: **`SET LOCAL` pertenece a la transacción más externa**,
  y `ActiveRecord::Base.transaction` anidado no abre una nueva. Un job corrido con `perform_now`
  dentro de una petición le dejaba su colegio puesto a la petición — capa 1 diciendo A, capa 2
  diciendo B, cero filas y ninguna explicación. Se guarda el valor anterior y se devuelve a mano.

  **Con esto cierra el milestone `2 · Aislamiento en la app y en la base`** (`MOR-86`, `87`, `88`,
  `89`). Y quedaron los **primeros 9 tests reales de aislamiento** del repo — la suite pasó de 3 a 13.

- **El módulo de evaluación está conectado de punta a punta** (`MOR-93` → `97`). Era "el núcleo del
  producto y está desconectado"; ahora el profesor define cómo evalúa, carga las notas desde el
  teléfono, los promedios se mantienen solos y el alumno los ve el mismo día.

  | | |
  |---|---|
  | `MOR-93` | El cálculo, verificado contra el Reglamento. **Guardaba 14,67 donde la norma dice 15** |
  | `MOR-94` | El profesor define sus evaluaciones y su ponderación |
  | `MOR-95` | La planilla de carga: guardado nota por nota, móvil primero |
  | `MOR-96` | Cargar una nota mueve el promedio, sin que nadie se acuerde |
  | `MOR-97` | El alumno ve sus notas — y lo que falta corregir |

  **La norma manda.** Reglamento General de la LOE: **Art. 108** (entero del 1 al 20; ≥ 0,50 sube),
  **Art. 111** (el anual es el *promedio* de los lapsos, sin ponderar) y **Art. 112** (la nota de la
  segunda oportunidad es la definitiva). Decisión explícita de Daniel: apegarse a la norma en vez de
  generalizarla. `evaluation_moments.weight` se queda pero **ya no entra en ningún cálculo**.

  **Tres trampas que costaron encontrar y valen para lo que viene:**
  1. **ActiveJob deserializa los argumentos ANTES de los `around_perform`.** Un job con contexto de
     colegio que recibe un `Section` resolvía su GlobalID sin colegio → cero filas. `CarriesSchool`
     engancha `perform_now`, que envuelve también la deserialización.
  2. **`unscoped` no se salta el RLS.** Quita el `default_scope` de la app y nada más. Contar sin
     contexto da cero, no todo.
  3. **Sin nota no es cero**, y hay que sostenerlo en las tres capas: el cálculo devuelve `nil`, la
     planilla borra la fila al vaciar el campo, y la vista del alumno escribe "Pendiente" en letras.

- **`MOR-98` · Boletines en PDF con verificación pública.** Commit `76d8bf3`. **Prawn**, elegido
  porque no necesita ningún binario del sistema: `wkhtmltopdf` está archivado por sus autores y
  Grover pide Node, y **el entorno de despliegue todavía no está decidido**.

  Una sola tabla —`report_cards`— resuelve tres cosas: el `snapshot` es el **archivo** (un boletín
  de diciembre sigue diciendo lo de diciembre aunque corrijan una nota en marzo), `issued_by` es la
  **auditoría**, y `code` es la **verificación** en `/verificar/:code`, pública y sin sesión.
  Verificado de punta a punta: PDF de 20 páginas por HTTP, código leído del papel, verificación
  devolviendo lo mismo.

- **`MOR-105` · Un solo pipeline, `bin/ci`, en 10 s.** Commits `0bc4451` y `7eba062`. `config/ci.rb`
  define qué se verifica y corre igual en la máquina y en GitHub. **El primer paso comprueba que el
  rol de la base no pueda saltarse el RLS** — si fuera superusuario, ningún otro paso se daría
  cuenta, porque los tests seguirían en verde. Verificado apuntando la app a un superusuario: falla
  en medio segundo.

  De paso: **`bin/setup` estaba roto en una máquina nueva** (hacía `db:prepare` conectándose como
  un rol que todavía no existía), y quien lo arreglaba a mano terminaba con un superusuario y el
  RLS decorativo. Ahora hace lo que `CLAUDE.md` decía que había que hacer.

- **El repositorio ya está enlazado y el CI corre en GitHub.** Esta copia local no
  tenía el remoto configurado —`.git/config` solo tenía `[core]` y `[lfs]`— por eso
  parecía que no había repo. Es `danielousky/siga`, privado. Las tres ramas
  encadenadas están subidas y **`main` sigue intacto**, para revisar por PR.

- **`MOR-105` cerrado · CI en verde en GitHub.** El workflow falló tres veces antes
  de andar, y ninguno de los tres errores se puede encontrar en la máquina de uno:
  el `Gemfile.lock` solo tenía plataformas de macOS; el paso de seeds dejaba la base
  de test sembrada y **el que reventaba era el `bin/rails test` de después**; y las
  tablas de `siga_test` no eran del rol de la app — bug que también estaba en
  `bin/setup` y que una máquina nueva se habría comido entero.

- **`MOR-101` + `MOR-104` cerrados · los dos agujeros de una URL pública.**
  No hay registro público (`/users/sign_up` da 404) y las cuentas nacen del panel
  del colegio. Los seeds no corren fuera de desarrollo salvo declarando
  `SIGA_ENTORNO_DEMO=1` **y** una contraseña propia, que fuera de desarrollo no
  tiene default. El correo personal salió del repositorio.

  El guard vive en `lib/seed_guard.rb` y no dentro de `db/seeds.rb` por algo que
  descubrí probándolo: **contra producción Rails aborta ANTES de llegar al guard**,
  por la conexión. Uno lo escribe, ve que falla, y cree que funcionó — cuando ni se
  ejecutó. Como clase se prueba de verdad.

- **La app se puede desplegar** (`DESPLIEGUE.md`). Dockerfile para Dokku, TLS por
  variables de entorno con HSTS de una hora, correo por SMTP, `GET /up`, y
  `bin/docker-entrypoint` que corre `rls:verificar` **antes** de levantar Puma.

  El hallazgo que habría roto el deploy: `database.yml` tenía `username: siga`
  escrito, y **las claves del archivo ganan sobre las de `DATABASE_URL`** —al revés
  de lo que dice el comentario que trae Rails—. Dokku inyecta la URL correcta y la
  app se habría conectado igual como `siga`. Se vio corriendo producción a mano:
  `/up` en 200 y toda vista con base en 500.

- **`MOR-90` cerrado · 173 tests, y la lección de por qué una suite puede no morder.**
  La primera versión medía las dos capas juntas: rompí el `default_scope` **entero** a
  propósito y **los 54 tests siguieron en verde**, porque el RLS filtraba igual. Que cada
  capa alcance sola es exactamente lo que se quería del diseño — y significa que un test
  que las mide juntas **no puede detectar la pérdida de una**. Ahora cada capa se mide con
  la otra apagada (`test/models/aislamiento_estructural_test.rb`).

  Y tres agujeros que **ninguna de las dos capas podía tapar**, los tres del mismo tipo:

  | Encontrado por | Qué era |
  |---|---|
  | QA de Daniel | `/departments/new` ofrecía un `<select>` con **los dos colegios** — y 5 formularios más |
  | QA de Daniel | La columna "Escuela" repetida en cada fila de los listados |
  | Milestone "División de Admins" | **Cualquier `director` veía el pipeline comercial completo** en `/demo_requests` |

  > La defensa en profundidad protege **los datos del inquilino**. No protege el **catálogo
  > de inquilinos** (`School`) ni los **datos de la plataforma** (`demo_requests`, que no
  > tiene `school_id`). Son dos problemas distintos y el segundo depende de acordarse en
  > cada pantalla nueva. De ahí salió `MOR-133`.

- **`MOR-99` · analizados Akdemia y Edudatos, y la segunda conversación de Cyndi.**
  Lo verificable está en `CLAUDE.md § Contexto de mercado`. Lo que cambió el plan:

  1. **`MOR-129` se derrumbó de alcance.** El sistema anterior de Cyndi (Arcada) ya hacía
     lo que hace falta: el docente carga **el número**, al representante se le muestra **el
     literal**. Deja de ser un cambio de esquema en dos capas y pasa a ser un **mapeo de
     presentación** — no se toca ningún `CHECK` ni ninguna validación `1..20`.
  2. **`MOR-136`, nuevo y es el único diferenciador que apareció**: persistir competencias
     e indicadores entre lapsos y años. Cyndi dice que **ningún sistema lo resuelve**, y es
     lo único que nombró como "lo principal".
  3. **Cobranza y representantes suben de prioridad**: los tres competidores los tienen.

  ⚠️ **`crt.sh` estaba caído (502)**: el censo de SAE no se pudo rehacer y **el cruce para
  ver si algún colegio está en dos sistemas a la vez quedó pendiente** — no dio negativo.

- **Proyecto "Apreciaciones Iniciales" tenía dos milestones y cero issues.** Ahora tiene tres:
  `MOR-133` (la administración de SIGA vive dentro del panel de los colegios · P1),
  `MOR-134` (arreglos de primera impresión antes de la demo · P2) y
  `MOR-135` (moldear el rediseño — **bloqueado a propósito** hasta que haya más estructura).

- **`MOR-134` + `MOR-137` cerrados · la app ya se puede mostrar.** Commits `482df7c`
  y `01497ea`, 201 tests.

  La barra de contexto trae el colegio y el año escolar de verdad —Bolívar dice
  `2026-2027 · comienza el 15 de septiembre`, Bello `2025-2026 · finalizado`—, los
  listados dicen cuántos son (**200** vs **90**, el remate de la demo, ya legible),
  el menú en el teléfono es una tira que se desliza en vez de trece enlaces
  apilados, y **Font Awesome salió**: se traía de un CDN en cada página para el
  ojito del login.

  **Dos cosas que valen más que el código:**

  1. **La búsqueda estaba rota a medias y por eso nadie la vio.** `ILIKE` ignora
     mayúsculas pero **no acentos**: `lopez` daba 0 y `ramos` daba 7. Se prueba con
     el primero de la lista, anda, y se cierra. En Venezuela eso es López, Pérez,
     Guzmán, Rodríguez, Martínez — la mayoría del país.

     Se arregló con `translate()` y **no** con `unaccent`, que desde PostgreSQL 13
     no es *trusted* y exige superusuario — o sea que chocaba de frente con
     `MOR-87`. Costo medido: **+0,026 ms**, porque el `school_id` acota a los 200
     alumnos del colegio antes de que la expresión corra. *El aislamiento paga la
     búsqueda.*

  2. **Lo destapó un cambio que no lo buscaba.** El indicador de escala convirtió
     una tabla vacía —que se lee como "no hay resultados"— en un `0 estudiantes`
     en números grandes. Mostrar la cantidad no era cosmético.

  Y apareció el **cuarto caso** del hueco de `MOR-133`: la corrección de
  `/demo_requests` tapó el controller y no llegó a la vista, así que el panel
  seguía diciéndole al director cuántas solicitudes de demo hay pendientes.
  **Tapar la puerta no alcanza si la pared tiene ventana.**

- **Noche del 13 al 14 de agosto · cuatro issues de la ruta crítica + constancias.**
  De `a500c6d` a `7dc4ab7`, 47 archivos, ~3.850 líneas. **283 tests.**

  | | Qué cambió de verdad |
  |---|---|
  | `MOR-129` | **Un colegio de primaria ya puede usar SIGA.** Y no costó lo que decía el issue: la respuesta de Cyndi lo convirtió de cambio de esquema en dos capas a un **mapa de presentación**. Cero `CHECK` aflojados. |
  | `MOR-111` | **Asistencia**, con la pantalla que entra en un minuto: todos presentes por defecto, se tocan las excepciones. |
  | `MOR-110` | **Portal de representantes** — el rol más numeroso del sistema, que no tenía ni una pantalla. |
  | — | **Constancias de estudio.** El documento que la secretaría escribe en Word, uno por uno. |

  **Las tres decisiones de diseño que valen para lo que viene:**

  1. **La escala cuelga del GRADO, no del colegio.** Un mismo colegio tiene primaria
     por literal y bachillerato por número. `grades.level` ya existía pero contesta
     otra pregunta —a qué nivel pertenece— y la certificación EMG tiene dos áreas
     por literal *dentro* de media general: ni dentro de un nivel la respuesta es
     única.

  2. **El colegio del representante sale de la sesión, y no es una excepción a la
     regla.** El conjunto viene de sus filas de `Representative` —vínculos que
     cargó el colegio, no él— y un id fuera de ese conjunto se descarta. La regla
     nunca fue *"el colegio no puede venir de la sesión"*: es **"no puede venir de
     algo que el usuario controla sin que el sistema lo haya verificado"**. Hay un
     test que manda un id ajeno y verifica que no pasa nada.

  3. **Asistencia tiene botón "Guardar" y la planilla de notas no.** Parece
     inconsistente y es deliberado: las notas son 30 valores tipeados y media hora
     de trabajo, así que cada una viaja sola. La asistencia son 3 toques, y con una
     conexión mala **una petición chica llega mucho más seguido que treinta**. La
     regla es "que el profesor no pierda su trabajo", y acá se cumple al revés.

  **Dos bugs que solo aparecieron al MIRAR, no al testear:**

  - La constancia salía con las etiquetas `<b>` impresas literalmente. Los tests
    pasaban: verificaban que el PDF existiera, no lo que decía. Se vio convirtiendo
    el PDF a imagen. Y arreglarlo destapó otro: con `inline_format`, un colegio
    llamado *"Bolívar & Asociados"* rompía el parser de Prawn.
  - El portal dejaba **encerrada** a una madre con un hijo en cada colegio: con un
    solo hijo saltaba directo al detalle, y el selector de colegio vive en la vista
    que se estaba salteando.

- **`MOR-133` decidido por Daniel: app aparte, mismo host de Dokku.** Comparte
  PostgreSQL, y eso sigue siendo seguro porque el aislamiento vive **en la base**:
  un segundo proceso con el rol `siga_app` está sujeto a las mismas políticas. De
  paso resuelve el rabbit hole 2 — en una app que por naturaleza ve todos los
  colegios, el bypass es la norma y no se confunde con un descuido.

**Pendiente inmediato, en orden:**

1. **La demo pública.** Ya se puede hoy, sin servidor:

       SIGA_HOSTS=".trycloudflare.com" bin/rails server
       cloudflared tunnel --url http://localhost:3000

   Está en `DESPLIEGUE.md` con qué mostrar y en qué orden.

2. **`MOR-102` y `MOR-103` esperan infraestructura.** El correo está configurado y
   falta un proveedor SMTP; el TLS está activo y falta el certificado. Los dos
   cierran sin tocar código cuando estén Contabo y el dominio.

3. **`MOR-129` · el literal A–E, ahora barato.** Cyndi contestó las cuatro preguntas
   que el issue tenía abiertas: A = 20–19, B = 18–17, C = 16–14, D = 13–10,
   **E = por debajo de 10** (el mismo corte de aprobación que el Art. 108). Sale de
   un **promedio numérico**, así que no hay aritmética sobre literales. Queda una
   tabla de rangos **colgada del grado, no del colegio** —un mismo colegio tiene
   primaria por literal y bachillerato por número— y mostrar **las dos cosas** en el
   boletín, porque el representante igual pregunta *"¿y cuánto, profe?"*.

4. **`MOR-133` · la administración de SIGA vive dentro del panel de los colegios.**
   P1, y ya costó **cuatro** agujeros: el controller de `/demo_requests`, la vista
   del panel, el `School.all` de los formularios y la columna "Escuela" de los
   listados. `desarrollador` es el parche de hoy y está escrito como tal en el
   código. Van a seguir apareciendo mientras compartan superficie.

5. **Lo que hay que pedirle a Cyndi**, en un solo mensaje: la constancia de
   **inicial**, la plantilla **en blanco** de la EMG 31059, si preescolar usa los
   mismos literales (mandó dos capturas sin mirar), y las cinco preguntas de
   `MOR-136` sobre las competencias.

- **`MOR-135` cerrado · el rediseño, decidido y ejecutado.** De `1859940` a `dc027c5`,
  **354 tests**, `bin/ci` en verde.

  El issue pedía **decidir**, no dibujar. Las cuatro decisiones quedaron escritas —y como
  los bloqueantes (`MOR-110`, `MOR-129`, `MOR-111`, `MOR-108`, `MOR-133`) se habían cerrado
  en el camino, se aplicaron en la misma tanda.

  **Tres hallazgos que valen más que las pantallas:**

  1. **La página que llega por WhatsApp pesaba 1,45 MB**, de los cuales **1,19 MB era el
     logo**: un PNG de 1024 px puesto donde se dibuja a 140. A 400 kbps —el piso realista
     en Venezuela— son 29 segundos de pantalla en blanco antes de ver un formulario de
     cuatro campos. Quedó en **260 KB**. Techo declarado: **≤ 300 KB por página pública**.

  2. **44 botones apuntaban a clases de Bootstrap que esta app no carga** — `btn-danger`
     (los 15 de borrar), `btn-outline-primary` (23), `btn-outline-secondary` (6) — más
     **80 clases de espaciado** en 39 vistas, o sea cero separación entre los campos de
     TODOS los formularios. Un botón así no explota: hereda `.btn` y se dibuja como texto
     suelto. *Esa era la causa real de "parece de otro sistema".* Nada en el pipeline lo
     veía: el HTML es válido y el humo devuelve 200. Ahora hay un test que lo fija
     (`test/integration/sistema_de_diseno_test.rb`).

  3. **El botón "Eliminar" fallaba 200 de 200 veces** en alumnos: cualquier alumno con
     inscripciones está protegido por `restrict_with_error`, y un alumno sin inscripciones
     no existe en un colegio real. Ahora aparece **solo donde va a funcionar** —dos de
     nueve recursos— y donde no, explica qué se perdería (`BorradoHelper`).

  **Lo demás:** portada reescrita (una tesis, cifras con fuente, precios leídos de
  `Subscription::PLANES`, ningún enlace muerto); página de demo con 4 campos y WhatsApp
  obligatorio, donde **pedirla dos veces ya no devuelve un error de validación** sino que
  suma en `veces`; fichas de alumno, grado, materia y profesor reescritas; cinco `show` que
  solo repetían la fila del listado, borradas; el menú del administrador reordenado **por
  frecuencia** (19 enlaces → 10 a la vista, resto en un `<details>`); 75 rótulos de Title
  Case a minúscula de frase.

  **Dos correcciones de rumbo, del propio Claude:**

  - El logo que usé no era el de SIGA: reconstruí con cuidado la sintaxis de un SVG roto
    (`siga-logo.svg`) sin preguntarme si ese archivo era siquiera el logo. El de verdad es
    `logo.svg`. Daniel lo corrigió y pidió que volviera el hero, que yo había sacado.
  - Los seeds daban **30 nombres distintos para 200 alumnos** —el mismo índice para nombre
    y apellido, así que solo salía la diagonal— y la lista mostraba "Blanco, José" tres
    veces seguidas. Mi primer arreglo (`k*7 + 3`) **no arregló nada** y lo di por bueno; lo
    vi porque conté los pares distintos en vez de mirar la fórmula. Arreglarlo destapó
    además que **`db:seed` no era idempotente ante cambios de contenido**: buscaba al alumno
    por correo, y el correo se deriva del nombre.

  ⚠️ **Trampa de medición, anotada para el próximo:** Chrome en macOS no abre ventanas de
  menos de 500 px, así que `--window-size=430` renderiza a 500 y *recorta* la captura —todo
  parece desbordado y no lo está. Para un ancho de teléfono real hay que meter la página en
  un `<iframe>` de 390 px **servido desde el mismo origen**: `X-Frame-Options: SAMEORIGIN`
  bloquea hacerlo desde `file://`.

- **La regla de color, auditada pantalla por pantalla + barrido visual.** De
  `d3fb5e2` a `0f80ab6`, **364 tests**.

  La regla es *el color lo usa el DATO, nunca el CONTROL*, y en un sistema
  escolar no es negociable: **un número en rojo es un niño aplazado**. Está en
  la libreta que mira una madre desde el teléfono. Si el rojo también quiere
  decir "este botón borra cosas", deja de decir lo primero.

  No se auditó pantalla por pantalla a ojo, sino cruzando **qué clases con
  color conviven en cada vista**: un rojo de control solo compite cuando está en
  la misma pantalla que un rojo de dato. 46 reglas usan color semántico; seis
  eran violaciones, una parecía violación y no lo era (`.asistencia-boton`: ahí
  el botón ES el estado, tocarlo cicla presente→ausente→tarde) y aparecieron dos
  que no buscaba —un ámbar escrito a mano y un `.status-pendiente` **pintado de
  verde** por un `style` inline, con las dos clases inexistentes—.

  Lo destructivo pasó a señalarse por **peso y posición**: borde fuerte, tinta
  sólida en hover, dentro de un bloque rotulado de la pantalla de edición. Y el
  rojo se quedó en la frase que nombra lo que se perdería, que es su trabajo.

  **Y después, mirar pantalla por pantalla encontró lo que ningún test veía:**

  1. **Los dos ojos del campo de contraseña se dibujaban superpuestos**, desde
     `MOR-134`, en la pantalla que un profesor abre cada mañana. Y **una caja de
     aviso vacía con un botón "Reintentar"**, permanente, en la planilla de
     notas. La misma causa: `[hidden] { display: none }` es del NAVEGADOR y
     cualquier `display` de autor le gana. Resuelto de raíz con
     `[hidden] { display: none !important }` — `hidden` es una afirmación sobre
     el DOM, no una sugerencia de estilo.
  2. **`.role-badge` traía `text-transform: capitalize`**, que capitaliza cada
     palabra: la pantalla de asistencia decía **"15 De Agosto De 2026"**. El
     HTML estaba bien; lo rompía la hoja de estilo, y por eso el barrido de
     Title Case de las vistas no lo había tocado.
  3. **La cabecera de TODAS las pantallas se encimaba en el teléfono**: flex sin
     `flex-wrap`.
  4. **Regresión mía:** el `<details>` del menú dejaba **nueve pantallas
     inalcanzables desde un teléfono** —la tira se desliza en horizontal y tiene
     `overflow-y: hidden`, así que lo que el `<details>` despliega hacia abajo
     queda recortado—. Y el CSS **no** puede forzarlo abierto: Chrome lo esconde
     por el slot de su shadow DOM, que es justo lo contrario del caso de
     `[hidden]`. Se resolvió renderizando el grupo de dos formas, apagando cada
     una en el ancho de la otra.

  **Los tres paneles pasaron a contestar la pregunta con la que se entra:** el
  del director muestra qué atender (con enlace a donde se resuelve) en vez de
  repetir el menú con emoji; el del profesor abre en lo que le falta corregir,
  con "Cargar notas" al lado; el del alumno muestra la nota, que antes estaba
  detrás de un botón.

  ⚠️ **Tres mediciones mintieron en esta tanda**, y las tres se zanjaron igual:
  renderizando completo y mirando. `getClientRects()` y `getComputedStyle()` en
  Chrome headless reportan cajas y `display` para el contenido de un `<details>`
  **cerrado**; y antes de eso di por bueno un colapso mirando una captura
  recortada a 900 px de alto. Para ver el final de la tira del menú hay que
  ponerle `scrollLeft = 99999` antes de capturar.

- **Cierre de pendientes técnicos.** De `59ef5ef` a `d0731c1`, **382 tests**.

  **La cola de trabajos deja de perderse.** Era `:async`, que guarda la cola en
  memoria del proceso web: un deploy se llevaba lo encolado sin dejar rastro, y
  el único job que hay recalcula los promedios de una sección entera. Ahora
  **Solid Queue sobre la misma base** —sin base aparte: para un job de un
  segundo, una segunda cadena de conexión que configurar, respaldar y
  monitorear no se paga—. Sus once tablas no llevan RLS a propósito: son
  maquinaria de plataforma, y el colegio viaja en el payload (`MOR-88`).
  Verificado a mano: encolar → matar el proceso → `bin/jobs` lo toma.

  **Auditar quién cambia una calificación.** *"¿Quién le cambió la nota a mi
  hijo?"* es la pregunta que un colegio necesita responder, y el sistema no la
  contestaba: había etiquetas para "Calificación registrada/modificada/
  eliminada" y **nadie las emitía**. Ahora queda quién, a quién, en qué
  evaluación y **de qué valor a cuál**. Guardar el mismo valor no cuenta: la
  planilla reenvía al salir del campo, y un historial lleno de cambios que no
  ocurrieron esconde los que sí.

  **Y una regresión mía, encontrada en el camino:** al borrar los cinco `show`
  que solo repetían la fila del listado, quince redirecciones quedaron
  apuntando a rutas que ya no existen. **No explotaban** —el helper
  `department_path` sobrevive porque `PATCH` y `DELETE` comparten esa ruta— así
  que creaban bien y dejaban al usuario en un 404. Ningún test lo veía porque
  ninguno ejercía alta ni edición de esos recursos; ahora hay uno que falla
  4 de 4 sin el arreglo.

  El registro de actividad pasó de cubrir 10 acciones a cubrir 25, con **los dos
  lados fijados por tests**: ninguna etiqueta sin emisor (prometía una auditoría
  inexistente) y ningún emisor sin etiqueta (la mostraba en inglés — incluida
  la visita de soporte de SIGA, que es la que hace defendible el acceso amplio).

  ⚠️ **`CLAUDE.md` estaba desactualizado en cinco puntos** y se verificó uno por
  uno: `force_ssl`, `action_mailer`, el registro público cerrado, el guard de
  los seeds y el Dockerfile ya estaban resueltos. Y **el repo ya tiene remoto**
  (`danielousky/siga`), así que el workflow de GitHub Actions puede correr —
  decía lo contrario. La rama actual está **21 commits adelante de su remoto**;
  subir es decisión de Daniel.

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

> Este archivo es **volátil por diseño**: es el estado de avance, no guía permanente.
> Vive fuera de `CLAUDE.md` porque esa sección se reescribe cada sesión — adentro viajaba
> en cada petición al modelo y además invalidaba el caché del prompt en cada edición.
> La guía permanente (stack, comandos, convenciones, estado conocido) sigue en `CLAUDE.md`.
