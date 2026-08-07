# SIGA — Backlog

Estado al 4 de agosto de 2026. Este archivo es la fuente para crear los issues en Linear.
Prioridades: **P0** bloqueante · **P1** alta · **P2** media · **P3** baja.

> **Cargado en Linear el 7 de agosto de 2026** — proyecto *SIGA · Plataforma de gestión académica*,
> issues `MOR-82` a `MOR-119`, con las cinco épicas como milestones. Cada issue de Linear referencia
> su sección de acá (`Referencia: BACKLOG.md § E1-01`). Este archivo queda como la vista legible
> desde el repo; Linear es el tablero de ejecución. Al agregar uno, agregarlo en los dos lados.
> https://linear.app/morosdevelopment/project/siga-plataforma-de-gestion-academica-df900bfa9693

---

## E1 · Aislamiento multi-tenant

> **Bloquea todo lo demás.** Hoy los datos se cruzan entre colegios: el panel de admin muestra
> los totales de la plataforma, `/students/:id` de otro colegio devuelve 200 y permite editar,
> y un segundo colegio no puede crear momentos de evaluación porque los pesos suman globalmente.
> Decisión tomada: **dos capas** — `default_scope` en la app + **RLS de PostgreSQL con `FORCE`**,
> para que un filtro olvidado devuelva cero filas en vez de fugar datos en silencio.
> Costo de hacerlo ahora: casi cero (`moment_grades` está vacía). Costo en 3 meses: migración de datos vivos.

### E1-01 · Agregar `school_id` a `grades` + índice único `(school_id, name)` — P0
Hoy `grades` no tiene escuela y `grades.name` es único global. Los seeds ya lo esquivan
nombrando `"1er Año - Bolívar"` / `"1er Año - Bello"`.
**Backfill:** por el sufijo que ya traen los nombres en los seeds.
**Criterio:** dos colegios pueden tener ambos un grado llamado "1er Año".

### E1-02 · Mover `evaluation_moments` a `academic_period_id` — P0
Es la única migración que no es un backfill trivial: los momentos son hoy filas compartidas y
hay que **clonarlos por período** y repuntar las notas al clon correcto. Índice único
`(academic_period_id, name)`. Colgarlo del período (y no de la escuela) congela la estructura
de evaluación de cada año escolar, para que cambiar los lapsos no altere las notas ya calculadas.
También hay que corregir la validación de pesos en `app/models/evaluation_moment.rb`, que hoy
suma sobre toda la tabla.
**Hacerlo ahora:** `moment_grades` está vacía.

### E1-03 · Índices únicos por colegio en `subjects` y `students` — P0
`subjects.code` → `(school_id, code)`; `students.school_card` → `(school_id, school_card)`.
Agregar `school_id` a `subjects` (backfill desde `department.school_id`).
`schools.dea_code`, `users.email` y `users.id_card` quedan globales — es correcto.

### E1-04 · Agregar `school_id` a las tablas que hoy lo deducen por cadena — P0
`sections`, `enrollments`, `grade_subjects`, `teacher_sections`, `activity_logs`,
`evaluation_activities`, `activity_grades`, `moment_grades`, `final_grade_books`.
Todos son backfill de una línea desde una FK existente. Aunque sea derivable, tenerlo explícito
hace componible todo índice único y convierte cada scope en un solo salto.

### E1-05 · Concern `SchoolScoped` + `Current.school` — P0
`default_scope` + `belongs_to :school` + validación de presencia. `Current` como `ActiveSupport::CurrentAttributes`,
seteado en `ApplicationController` desde el rol del usuario autenticado — **nunca** desde un parámetro.

### E1-06 · Row-Level Security en PostgreSQL con `FORCE` — P0
La segunda capa. Sin `FORCE ROW LEVEL SECURITY` el owner de la tabla (el usuario de la app en
Rails) **se salta las políticas** — es el error más común al implementar RLS.
**Ojo con el connection pooling:** la variable de sesión se setea **por transacción**, en un
`around_action`. En un initializer no funciona.
**Criterio de aceptación:** un test que ejecuta una consulta sin scope y verifica que devuelve
cero filas del otro colegio, no que las devuelve todas.

### E1-07 · Contexto de tenant en background jobs — P0
Es donde más se rompen los sistemas multi-tenant: el job se encola con contexto y corre después
en un worker sin request, `Current.school` queda en `nil` y los default scopes dejan de aplicar.
El tenant va explícito en el payload del job.

### E1-08 · Validaciones de integridad cruzada — P1
Hoy se puede inscribir a un alumno de un colegio en la sección de otro sin que nada lo impida.
Validar que coincidan: `Enrollment` (alumno ↔ sección), `TeacherSection` (profesor ↔ sección),
`Grade#leader_teacher` (profesor del mismo colegio).

### E1-09 · Suite de tests de aislamiento — P0
Por cada recurso: un admin del colegio A no ve ni edita nada del colegio B. Es la red que evita
que la fuga vuelva a aparecer en un controller nuevo.

### E1-10 · Vista consolidada para redes de colegios — P2
AVEC, ANDIEP y Fe y Alegría son compradores institucionales que necesitan agregado entre colegios.
Cruza tenants **legítimamente**, con `school_id IN (...)` explícito y auditado. Diseñarlo junto
con E1-05/E1-06 para que no se convierta en un boquete transversal.

### E1-11 · Acceso de soporte interno acotado y auditado — P2
La cuenta de soporte/admin es el vector del incidente de Canvas (2026): una sesión con acceso
transversal a todos los tenants. Debe ser just-in-time y quedar registrada, no permanente.

---

## E2 · Módulo de evaluación

> Existe en la base con modelos, validaciones y el servicio `GradeCalculator` funcionando,
> pero **cero controllers, rutas y vistas**. Un profesor no puede cargar una nota y nadie puede
> ver una. Es lo único que convierte la app en algo por lo que un colegio paga: la propuesta
> vende "los profesores cargan notas desde sus casas" y el contrato promete "gestión de notas".
> Hacerlo **después** de E1, o hay que escribirlo dos veces.

### E2-01 · Tests de `GradeCalculator` — P0
Antes que la UI. Calcula notas oficiales que quedan en el expediente de un alumno: promedio
ponderado por lapso y anual, redondeo, nota de reparación (`final_score = max(anual, reparación)`),
y los casos borde (sin actividades, sin notas cargadas, peso total cero).

### E2-02 · CRUD de actividades evaluativas — P1
El profesor define las evaluaciones de su materia/sección/lapso con su ponderación.
La validación de que los pesos no pasen de 100 % ya existe en el modelo.

### E2-03 · Carga de notas tipo planilla — P1
La pantalla que justifica el producto. Lista de alumnos de la sección × actividad, edición rápida,
guardado incremental. Debe funcionar bien en móvil: el profesor carga desde su casa, muchas veces
desde el teléfono.

### E2-04 · Recálculo automático al guardar notas — P1
Enganchar `GradeCalculator` para que al guardar una nota se actualicen `moment_grades` y
`final_grade_books`. Hoy el servicio está escrito y no lo llama nadie.

### E2-05 · Vista de notas para el estudiante — P1
El dashboard del estudiante existe pero no muestra ni una nota.

### E2-06 · Boletín en PDF — P1
"Reportes en un clic" es parte de la propuesta de valor que justifica el cobro mensual.
Considerar código de autenticación anti-falsificación (Quid lo hace en Colombia).

### E2-07 · Formatos oficiales MPPE — P2
Notas certificadas y forma EMG 31059. **Es tabla de entrada al mercado, no diferenciador** —
SAE y SGE Pro ya los tienen. Sin esto no se compite por un colegio venezolano.

---

## E3 · Endurecimiento para producción

### E3-01 · Subir Ruby y Rails — P1
Ruby 3.1 (EOL marzo 2025) y Rails 7.0 están **fuera de soporte de seguridad**. Para un servicio
que aloja datos personales de menores y se factura por contrato, hay que subir **antes** del
primer cliente. Hacerlo después de E1 y antes de E2.

### E3-02 · Cerrar el registro público — P1
`User` tiene `:registerable`: cualquiera en internet puede crear cuenta en `/users/sign_up`.
En un SaaS B2B vendido por colegio no debería existir.

### E3-03 · Configurar Action Mailer en producción — P1
Devise tiene `:recoverable` activo pero producción no configura `action_mailer` ni
`default_url_options`: "olvidé mi contraseña" no envía nada.

### E3-04 · Activar `force_ssl` — P1
Está comentado en `config/environments/production.rb:49`.

### E3-05 · Guard de entorno en los seeds — P1
`db/seeds.rb` crea usuarios con contraseña `123123`, incluido uno con rol `desarrollador`.
`raise if Rails.env.production?`.

### E3-06 · CI con la suite de tests — P1
Hoy no hay CI y la suite está prácticamente vacía. `test/controllers/demo_requests_controller_test.rb`
llama a `demo_requests_create_url`, que no existe como ruta GET.

### E3-07 · Deploy, backups y monitoreo — P2
Sin Dockerfile/Kamal, sin estrategia de backup, sin monitoreo de errores. El contrato promete
disponibilidad y resguardo de datos escolares.

### E3-08 · Renombrar el concepto `Grade` o sus etiquetas de auditoría — P3
`Grade` es "grado escolar", pero `ActivityLog::LABELS` traduce `grade_created` como
"Calificación registrada". Dos conceptos con el mismo nombre en el mismo dominio.

---

## E4 · Capa SaaS y producto comercial

### E4-01 · Modelo de suscripción, planes y límites — P2
No existe ninguna tabla. Los planes son $25 (≤150 alumnos) / $50 (151–400) / $90 (401–800).

### E4-02 · Onboarding self-service con corte por volumen — P2
El "gancho" de la propuesta: registrarse y cargar libremente hasta ~200 registros, entonces
frenar y pedir la suscripción. Requiere contador por tenant y gating. Hoy el alta de un colegio
es manual por consola.

### E4-03 · Portal de representantes — P2
Justifica el plan Premium y es el feature más visible para el cliente final.

### E4-04 · Asistencia — P2
Estándar de mercado. Educasis diferencia con escaneo de QR en carnets.

### E4-05 · Cobranza multimoneda con indexación — P3
$/Bs/€ con tasa BCV, control de cartera. **Barrera de entrada seria:** SAE tiene homologación
SENIAT para emitir comprobantes fiscales. Evaluar si hace falta o si alcanza con control interno.

### E4-06 · Notificaciones por WhatsApp — P3
Estándar de facto en Venezuela. SAE lo ofrece; Quid lo cobra aparte.

### E4-07 · Ampliar el modelo a preescolar y universidad — P3
La propuesta apunta a "preescolar, primaria, secundaria y universitario", pero el código solo
modela dos niveles y la escala 0–20 está hardcodeada en cinco validaciones. Preescolar evalúa
cualitativamente; universidad necesita unidades de crédito.

---

## E5 · Investigación de mercado

### E5-01 · Campo "¿qué usan hoy?" en el formulario de demo — ✅ HECHO
Enum `current_system` (papel / cuadernos / instalado sin internet / web con internet / otro) +
campo libre `current_system_detail`. Pregunta por la **forma** de la solución, no por el proveedor,
para no hacerle publicidad a la competencia en el momento de máxima intención de compra.
El panel de admin muestra la distribución y los sistemas que nombraron. Scope `sin_acceso_web`
aísla el segmento del beachhead.

### E5-02 · Censo de la cartera del incumbente — ✅ HECHO
Certificate transparency sobre `asistescolar.com`: 4.095 certificados → **195 subdominios de
colegio**, ~87 % activos. SAE declara +900 instituciones ⇒ **~78 % de su cartera usa el producto
de escritorio, sin portal web**. Ese es el beachhead: ya compran software, les falta el acceso web.
Listado en `docs/investigacion/sae-cartera-subdominios.txt`, método y fecha en el `README.md` de esa
carpeta.

### E5-03 · Validar la estimación de "sin sistema" con muestreo — P2
La cifra de 60–70 % sin sistema es inferencia, no dato. Tomar 150–200 colegios privados del
directorio DEA del MPPE y revisar señales observables (web, link de consulta de notas, portal de
representantes). Con 200 casos el margen es ±7 %.

### E5-04 · Contactar ANDIEP — P2
Agrupan 3.800 colegios y le dan estadísticas a la prensa cada temporada. Ofrecerles compartir
los resultados del estudio a cambio de agregados.

### E5-05 · Investigar Caracas y Maracaibo — P2
La cartera de SAE está concentrada en centro-occidente (Guanare, Bolívar, Carora, Lara) y las dos
ciudades más grandes aparecen **ausentes** de su listado. O el incumbente no penetró la capital,
o ahí compite contra algo que todavía no identificamos.

---

## Orden recomendado

1. **E1 completo** — el aislamiento condiciona todo lo demás y hoy es barato
2. **E3-01** — subir Ruby/Rails antes de escribir el módulo de notas
3. **E2-01 → E2-06** — el producto que se vende
4. **E3** resto — antes del primer cliente real
5. **E4** — la capa que hace vendible la propuesta
