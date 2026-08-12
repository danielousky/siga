# 🔖 Punto de retome — actualizado 12 de agosto de 2026

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

**Pendiente inmediato, en orden:**

1. **Crear el repositorio remoto y empujar.** Es el riesgo abierto más grande: **19 commits viven en
   una rama local**, y las tres ramas están encadenadas —`feat/encuesta-demo-y-backlog` →
   `chore/upgrade-ruby-rails` → `feat/mor-82-school-id-en-grades`—, con `main` intacto. Además
   `.github/workflows/ci.yml` está escrito y **no puede correr sin remoto**: es lo único que le
   falta a `MOR-105` para cerrar.
2. **`MOR-90` · Suite de aislamiento recurso por recurso.** Ya no está bloqueado: `escenario_academico`
   resuelve el prerrequisito de "fixtures para dos colegios", y pone el contexto en las **dos** capas
   (sin lo segundo, el `WITH CHECK` del RLS rechaza cualquier inserción).
3. **`MOR-99` · Formatos del MPPE.** **Bloqueado y a propósito**: el issue prohíbe modelar sobre una
   reconstrucción, y las dos fuentes públicas están caídas o son de 2017. Necesita que un colegio
   pase el formato en blanco. Faltan además cinco campos de identidad en el modelo —fecha y lugar de
   nacimiento, nacionalidad, zona educativa— que conviene que entren por `MOR-126` (el importador).
4. **`MOR-101` · `/users/sign_up` abierto** y **`MOR-104` · seeds con `123123` sin guard de entorno.**
   Son los dos agujeros de exposición que quedan en Cimientos, y los dos son chicos.

**Lo único que no pude verificar yo:** las dos pantallas nuevas están pensadas **móvil primero** y
verificadas por CSS, pero **no las probé en un teléfono real**. Es un criterio de aceptación explícito
de `MOR-95` y `MOR-97` y necesita el ojo de Daniel.

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
