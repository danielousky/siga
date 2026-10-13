# Del registro al cobro

> **Estado:** **congelado el 12 de octubre de 2026.** Decisiones de Daniel del
> 8, 9 y 12 de octubre. Si algo cambia, se cambia aquí primero.
> **Ramas:** `feat/del-registro-al-cobro` (este spec y la tanda 1) ·
> `feat/pagar-sin-consola` (la tanda 2) · `feat/el-precio-con-el-iva-adentro` ·
> `feat/la-muestra` (la tanda 5) · `feat/la-puerta` (la tanda 4) ·
> `feat/la-escalera` (la tanda 3). Cada una sale de la anterior. Locales, sin PR.

```
   LAS TANDAS, en el orden que eligió Daniel («primero cobrar»)
   1 · las reglas           hecha     el precio por alumno y la frontera de lo gratis
   2 · pagar sin consola    hecha     «Suscripción», el reporte, validar en /siga y los ajustes
   5 · la muestra           hecha     el colegio de muestra, EN LÍNEA: demo.sigaeducando.com
   4 · la puerta            hecha     la portada, el registro con su precio y el WhatsApp
   3 · la escalera          hecha     el trabajo diario y sus tres correos
   ─────────────────────────────────────────────────────────────────────────────
   «hecha» es en local y con `bin/ci` en verde. Las decisiones 23 a 27 nacieron
   en la tanda 2 y están POR CONFIRMAR, y la 29 también. Las 30 a 34 nacieron
   en la tanda 5 —con Daniel ausente— y están POR CONFIRMAR.

   ⚠️ LA TANDA 5 SÍ SALIÓ, y es la única: la muestra vive en su propia app del
   servidor (`siga-demo`, con su base). Producción no se tocó.

   ⚠️ EL PRECIO CAMBIÓ el mismo 12 de octubre, después de la tanda 2 y antes de
   que nada saliera: de «0,30 $ + IVA, mínimo 39» a **0,35 $, mínimo 45, sin
   IVA aparte** (decisiones 28 y 29). Donde este spec decía lo primero, ya dice
   lo segundo; las decisiones 7 y 8 quedan tachadas, como historia.
```

Un colegio entra a SIGA, carga lo suyo, ve cuánto le cuesta operar, paga, y SIGA
le abre el resto. Si deja de pagar, el sistema se traba solo. Hoy ese recorrido
no existe completo; este spec lo define.

> ⚠️ **La fuente de verdad es el código, más lo que se decide aquí.** Los PDF de
> la propuesta inicial, el contrato modelo, el programa de aliados, el manual y
> varios textos de las vistas se quedaron atrás. Este spec no los toma como
> referencia: los lista en § 9, para unificarlos al final.

```
   PORTADA ──► [Registre su colegio]      [WhatsApp]      [Vea un colegio funcionando]
                       │                                              │
                       ▼                                              ▼
               cuenta + colegio, con la línea:              el colegio de muestra: entra
               «cargar es gratis; calificar, pasar           como directivo, profesor o
                lista y emitir: 0,35 $ por alumno            representante, clave 123123
                al mes»
                       │
                       ▼
               CARGA, gratis y sin fecha: alumnos, familias, profesores, secciones, importador
                       │
                       ▼  toca Calificar, Asistencia o Emitir
               EL MURO: «126,00 $ al mes por 360 alumnos»  ──►  SUSCRIPCIÓN: cómo pagar
                       │
                       ▼
               REPORTA el pago  ──►  correo a Daniel  ──►  VALIDA en /siga
                       │
                       ▼
               ACTIVA un mes  ──►  5 días antes, aviso  ──►  vence: 15 días de gracia
                                                        ──►  solo lectura
```

---

## 1 · El problema

Daniel, 8 de octubre de 2026:

> *«No está claramente definido si la puerta de entrada es una solicitud demo
> (en cuyo caso no lo tenemos) o un registro, si la persona registra el colegio
> (cosa que no se induce por ningún lado) luego no se deja claro qué plan tiene o
> cuánto le cuesta y cómo pagarlo.»*

Leído en el código ese día, hay dos puertas, y llevan a dos productos distintos:

```
   PUERTA A · «Agende una demostración»            el botón grande de la portada
   formulario ──► fila en /siga/solicitudes         nadie recibe aviso
              ──► alguien lo llama…                 no hay colegio de muestra que enseñar
              ──► /siga/colegios «Dar de alta»  ──► colegio SIN suscripción
              ══► todo el producto, sin límite y sin fecha

   PUERTA B · «Registre su colegio»                el enlace discreto
   formulario ──► plan «gratis», precio 0, sin vencimiento
              ──► carga todo lo que quiera
              ──► toca Calificar ──► «se activan con un plan»
              ══► y ahí termina: ni precio, ni cómo pagar, ni a quién escribir
```

Y detrás de las dos:

- **Nadie puede volverse cliente sin abrir la consola.** La Cartera tiene la
  acción `update` y ninguna pantalla la llama. Su «Dar de alta» aparece solo
  para el colegio sin suscripción, y el que se registra ya tiene una.
- **La escalera no se mueve sola.** `Subscription.actualizar_todas!` corre
  únicamente al abrir `/siga/cartera` (`cartera_controller.rb:10`);
  `config/recurring.yml` no la programa.
- **La frontera de lo gratis tiene ocho huecos.** La lista de
  `RespetaLaSuscripcion` se escribió el 27 de agosto y lo construido después
  quedó afuera: cerrar el lapso —que emite boletines y les escribe a las
  familias—, reparaciones, valoraciones de Inicial, informes descriptivos, la
  cobranza a las familias, la descarga del boletín por la familia, las listas en
  Excel y los correos a los representantes. Leído, no probado: con eso un
  preescolar opera completo sin pagar.
- **Las bandas tienen un escalón sin defensa.** El alumno 151 sube la factura de
  39 a 79 $, y el colegio de 800 paga menos por alumno que el de 150.

Y el criterio que ordena todo lo demás. Daniel, 9 de octubre:

> *«no quiero estar detrás de la gente para que pague y que si no les presiono
> entonces no me pagan. Eso muchas veces me ha puesto en situaciones MUY
> incómodas y no espero eso de este proyecto.»*

```
   EL SISTEMA COBRA, NO DANIEL
   ▸ nada que tenga valor queda gratis para siempre
   ▸ si no paga, se traba solo, por escalones, sin que nadie tenga que llamar
```

## 2 · Qué NO entra

```
   ENTRA                                          NO ENTRA
   ─────                                          ────────
   la portada: el registro como puerta,           la pasarela de pago: SIGA no toca el dinero
     WhatsApp y el colegio de muestra             la factura fiscal: la emite Daniel, fuera de SIGA
   el botón de WhatsApp, en tres lugares          la tasa BCV automática: el monto en bolívares
   el registro dice el precio                       lo calcula quien paga
   la frontera de lo gratis, completa y           pagar por lapso o por año: se decidió mensual
     cuidada por un test                          recordatorios por WhatsApp: los manda el correo
   el precio por alumno, en un solo lugar         el programa de aliados: no tiene código
   la pantalla «Suscripción» y el reporte         que una persona se pueda editar desde otro
     del pago                                       colegio: va en su propio PR, antes del
   validar y rechazar en /siga                      segundo colegio real (§ 4.3)
   los ajustes de /siga: el WhatsApp y            las fechas de los lapsos (hoy, tercios
     los datos para pagar                           parejos) y la zona horaria de la app
   la escalera, moviéndose sola cada día          unificar documentos y PDF: § 9, al final
   los correos de la escalera y del pago,
     y los de bienvenida y colegio nuevo
   el colegio de muestra
```

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Cuál es la puerta de entrada? | **El registro**, como botón principal, con un botón de WhatsApp al lado y una entrada rápida a un colegio de muestra. La solicitud de demostración deja de ser la puerta | Daniel, 8 oct. |
| 2 | ¿Cómo se ve el sistema funcionando? | **Un colegio de muestra** con datos, con credenciales por rol —directivo, profesor y representante— y clave `123123` | Daniel, 8 oct. |
| 3 | ¿Qué puede hacer gratis un colegio con SUS datos? | **Solo cargar.** La entrada (cargar e importar), libre, sin tope y sin fecha. Procesamiento y salida, con suscripción desde el primer día | Daniel, 9 oct. |
| 4 | ¿Cuándo se abre lo demás? | **Cuando Daniel valida el pago**, no cuando el colegio lo reporta | Daniel, 9 oct. |
| 5 | ¿Sobre qué se cobra? | **Por alumno inscrito, un solo plan:** todo el sistema para todos | Daniel, 9 oct. |
| 6 | ¿Cada cuánto? | **Mensual, por adelantado.** Sin opción anual | Daniel, 9 oct. |
| 7 | ¿Cuánto? | ~~0,30 $ por alumno al mes, mínimo 39 $~~ → reemplazada por la 28 y la 29 | Daniel, 9 oct. |
| 8 | ¿Lleva factura? | ~~Sí, con IVA aparte: «0,30 $ por alumno + IVA»~~ → reemplazada por la 28. La factura la sigue emitiendo Daniel, fuera de SIGA | Daniel, 9 oct. |
| 9 | ¿Por qué medios se paga? | **Pago Móvil o transferencia,** en bolívares a la tasa BCV del día; **Binance (USDT)**; **efectivo en dólares.** Zelle, no | Daniel, 9 oct. |
| 10 | ¿El registro dice el precio? | **Sí, en una línea** | Daniel, 9 oct. |
| 11 | ¿Cuántos días de gracia? | **15**, como hoy | Daniel, 9 oct. |
| 12 | Si paga tarde, ¿desde cuándo cuenta el mes? | **Si paga en la gracia, desde que venció; si paga en solo lectura, desde que se valida** | Daniel, 9 oct. |
| 13 | ¿Dónde vive el colegio de muestra? | **En una instancia aparte, con su propia base.** Ver § 4.3 | Daniel, 12 oct. |
| 14 | ¿Quién ve «Suscripción»? | **Dirección y finanzas:** quien lleva el dinero es quien paga | Claude; confirmada por Daniel, 12 oct. |
| 15 | ¿Qué pasa con los nombres Inicial, Estándar y Grande? | **Desaparecen.** Con un solo plan, el colegio tiene la suscripción activa o no la tiene. De paso se acaba el choque de hoy: «Inicial» es a la vez el plan gratis y el de 39 $ | Claude; confirmada por Daniel, 12 oct. |
| 16 | ¿Puede un colegio quedarse SIN suscripción? | **No.** Hoy «sin fila» es acceso completo y sin fecha: es la puerta A. Todo colegio nace en `gratis`, y una cortesía o un piloto es una suscripción activa a 0 $, con su vencimiento | Claude; confirmada por Daniel, 12 oct. |
| 17 | ¿Se congela el precio del que entra? | **Sí:** cada colegio conserva su precio por alumno y su mínimo, y subirlos toca solo a los que entran después. Hoy ya se congela `precio_mensual` | Claude; confirmada por Daniel, 12 oct. |
| 18 | ¿Cómo se ajusta el precio? | Si cuatro de los primeros cinco colegios a los que se les cotiza aceptan sin discutir el precio, los siguientes entran a 0,40. ⚠️ Ese 0,40 era ANTES de meter el IVA en el precio (decisión 28): con la misma cuenta serían 0,46, y hay que volver a decidirlo | Claude; confirmada por Daniel, 12 oct. |
| 19 | ¿Qué pasa con el formulario de demostración? | **Sale de la portada;** su dirección lleva a la portada, y `/siga/solicitudes` se queda como historia | Claude; confirmada por Daniel, 12 oct. |
| 20 | ¿Dónde está el botón de WhatsApp, y de dónde sale el número? | **En la portada, el registro y «Suscripción».** Hoy vive solo en el formulario de demostración, que sale con la decisión 19. **El número es un ajuste que Daniel cambia desde `/siga`,** sin tocar el servidor; reemplaza a la variable `SIGA_WHATSAPP` | Daniel, 12 oct. |
| 21 | ¿Y los datos para pagar —Pago Móvil, Binance—? | **En el mismo ajuste de `/siga`,** por la misma razón: cambiar de cuenta no puede exigir un despliegue | Claude, por la misma razón que la 20 |
| 22 | ¿Quién valida pagos y cambia los ajustes? | **El fundador**, como ya pasa con tocar suscripciones (`SigaStaff#puede_dar_de_alta_colegios?`); operaciones los ve | Claude, siguiendo el código |
| 23 | ¿Se le avisa al colegio cuando su pago se valida? | **Sí, por correo, a quien lo reportó.** El spec pedía solo el del rechazo; sin el otro, el colegio tiene que entrar a mirar o escribir a preguntar si ya puede calificar | Claude, tanda 2 · **por confirmar** |
| 24 | ¿Y si el colegio reportó mal? | **Retira su reporte mientras nadie lo ha mirado, y reporta de nuevo.** Solo cabe uno en revisión: sin esto quedaría esperando a que se lo rechacen | Claude, tanda 2 · **por confirmar** |
| 25 | ¿Con qué cuenta se cobra: la del día que reporta o la del día que se valida? | **La del día que REPORTA.** El reporte guarda lo que el colegio vio —alumnos, precio, mínimo y monto— y validar activa con eso, aunque después inscriba más alumnos o suba el precio | Claude, tanda 2 · **por confirmar** |
| 26 | «Pagó tarde», ¿se mide por el reporte o por la validación? | **Por el reporte.** La demora en validar es de SIGA y no puede moverle el mes al colegio (§ 5.7) | Claude, tanda 2 · **por confirmar** |
| 27 | ¿Se puede deshacer una validación? | **No, por ahora.** Por eso validar pide confirmación, y un pago ya revisado no se vuelve a decidir. Deshacerla exigiría guardar cómo estaba la suscripción antes | Claude, tanda 2 · **por confirmar** |
| 28 | ¿Y el IVA? | **Va DENTRO del precio: 0,35 $ por alumno al mes, y ninguna pantalla dice «más IVA».** *«No podemos cobrar IVA en dólares, eso no es correcto… vamos a incrementarle el IVA al costo, es decir, 0,30 × 1,16 = 0,348, poco menos de 0,35. Pongámoslo de una vez como el costo.»* Lo que se lee es lo que se paga: 360 alumnos, 126,00 $ | Daniel, 12 oct. |
| 29 | ¿Y el mínimo? | **45 $,** por la misma cuenta: 39 × 1,16 = 45,24. Daniel dijo el precio por alumno y no el mínimo; dejarlo en 39 le habría bajado la cuenta al colegio chico de 45,24 a 39. Cubre hasta 128 alumnos | Claude · **por confirmar** |
| 30 | ¿Con qué cuentas se entra a la muestra? | **`director.bolivar@mail.com`, `profesor.bolivar@mail.com` y `representante.bolivar@mail.com`, clave `123123`.** La primera la fijó Daniel —*«pongámosles director.bolivar@mail.com»*—; las otras dos siguen su forma. Son las mismas en desarrollo: reemplazan a `director.bolivar@siga.edu` y `prof.garcia@bolivar.edu` | Daniel (la primera) · Claude, por confirmar (las otras dos), 12 oct. |
| 31 | ¿Solo tres puertas? | **Tres grandes y siete chicas.** Debajo van «Otras miradas» —coordinación, secretaría, finanzas, una maestra de primaria, un alumno, una representante con hijos en dos colegios y el colegio que dejó de pagar—: no venden, pero dejan recorrer lo que las tres no enseñan | Claude; por confirmar |
| 32 | ¿Qué fecha tiene el colegio de la muestra? | **La de HOY.** Los años escolares de la siembra se cuentan desde el día en que corre: el año pasado completo y cerrado, y el que corre, calificado y con asistencia hasta ayer. Como se resiembra cada noche, el colegio avanza solo. Antes eran años escritos, y la muestra abría en un año «finalizado» | Claude; por confirmar |
| 33 | ¿Quién entra a `/siga` en la muestra? | **Nadie, por defecto.** El equipo de SIGA se siembra con una clave al azar: `/siga` guarda las cuentas a donde se paga, y con la clave pública cualquiera pondría la suya en «cómo pagar». Se abre poniendo `SIGA_SEED_STAFF_PASSWORD` | Claude; por confirmar |
| 34 | En el portal, ¿qué ve la familia de un niño de Inicial, y qué boletines? | **La valoración que escribió la maestra** —leía «Pendiente» aunque estuviera escrita—, **y los boletines liberados de los años anteriores,** no solo los del que corre. Son dos arreglos del producto, no de la muestra: los dejó a la vista sembrar una familia con un hijo en cada nivel | Claude; por confirmar |

## 4 · El dominio

### 4.1 · Quién paga, y por qué por alumno

- **Paga el colegio, nunca la familia.** La Resolución 114 del MPPE (Gaceta
  Oficial 40.452, 11 de julio de 2014), art. 17, prohíbe cuotas, aportes o bonos
  aparte de la matrícula y las mensualidades. El costo de SIGA va dentro de la
  estructura de costos que aprueba la asamblea de padres.
- **Por alumno es la unidad con que el colegio razona.** Cobra a sus familias
  por alumno; el costo de SIGA entra en su estructura como «tanto por alumno».
- **El colegio cobra doce mensualidades,** de septiembre a agosto. SIGA cobra
  doce también.

### 4.2 · Lo que ya estaba, y no se toca

- **Al vencer, solo lectura; nunca se corta** (`MOR-108`). El colegio ve y
  descarga todo, y sigue emitiendo constancias, boletines y certificados: la
  deuda es del colegio y el perjuicio no puede ser del alumno
  (`RespetaLaSuscripcion::SIEMPRE_PERMITIDO`).
- **Se observa siempre y se cobra al renovar.** Que la matrícula crezca a mitad
  de mes no cambia lo que ya se pagó: cuenta en la renovación siguiente, que
  ahora es cada mes.
- **La matrícula que cuenta** es la de `Subscription.matricula_de`: las
  inscripciones `regular` del último año escolar que tiene inscripciones.
- **Las pantallas no se esconden.** Sin suscripción, el director ve la planilla
  de notas y no la puede tocar.

### 4.3 · Dónde vive el colegio de muestra

Daniel eligió A el 12 de octubre. Las dos opciones quedan escritas por lo que
explica la B: es lo que impide, más adelante, mudar la muestra a producción.

```
   A · UNA INSTANCIA APARTE, con su propia base                  ← la elegida
       demo.sigaeducando.com, sembrada con los seeds de hoy: la U.E. Simón Bolívar,
       360 alumnos y los tres niveles, más la Media Técnica
       ahí no hay nadie real: la clave 123123 no expone a nadie
       sin correo saliente, y se resiembra cada noche
       cuesta: una segunda app en el mismo servidor, y desplegar a las dos

   B · DENTRO DE PRODUCCIÓN
       la misma dirección y el mismo login
       cuesta: una siembra aparte —los seeds de hoy crean además una cuenta del
       equipo de SIGA que ve todos los colegios— y, antes, el arreglo de abajo
```

⚠️ **Por qué B es delicado** (leído en el código, no ejecutado). Una persona es de
la plataforma, no del colegio. `RepresentativesController#usuario_existente`
busca por cédula en toda la plataforma y reutiliza a la persona que encuentra;
`#update` deja editar sus datos, correo incluido (`user_params` permite
`:email`). Desde el colegio de muestra, con la clave pública, cualquiera podría
enganchar por su cédula a una persona real de otro colegio, cambiarle el correo y
entrar como ella con «olvidé mi contraseña». Lo mismo pasa hoy entre dos colegios
reales, y por eso se arregla aparte antes del segundo; pero con una clave pública
deja de ser un riesgo de un empleado identificable y pasa a ser de cualquiera.

**Lo que quedó construido** (tanda 5, 12 de octubre):

```
   demo.sigaeducando.com          app Dokku `siga-demo`, base `siga-demo-db`
   ┌───────────────────────────────────────┐   SIGA_MUESTRA=1
   │ Vea SIGA funcionando, sin registrarse │
   │ [director] [profesor] [representante] │   un clic abre la sesión, sin clave
   │ Otras miradas: coordinación, alumno…  │   la clave igual está escrita: 123123
   └───────────────────────────────────────┘
        adentro: «Colegio de muestra · [Cambiar de rol] · Registre su colegio →»
```

- **Se declara con una variable, `SIGA_MUESTRA=1`,** y todo lo que la muestra
  hace distinto lo pregunta en un solo sitio (`Muestra.activa?`). La variable es
  nueva a propósito: la `SIGA_ENTORNO_DEMO` de los seeds se usó contra
  producción, y una que nunca existió no puede haber quedado puesta en ningún lado.
- **Entrar sin clave tiene tres cerrojos,** y cada uno alcanza solo: la
  instancia se declaró muestra (si no, 404), la cuenta está en la lista, y tiene
  ese rol en el colegio de ese código DEA.
- **No sale correo** (un interceptor, no «no configurar el SMTP»: una ausencia
  la corrige cualquiera que copie las variables de producción), **no se
  indexa** y **no se registra nadie:** el registro manda al sitio de verdad.
- **Las puertas no se rompen:** a esas cuentas no se les cambia el correo, la
  clave, el rol ni el cargo. Todo lo demás se puede tocar.
- **Cada noche vuelve a su estado sembrado** (4:00 a. m. de Venezuela).
  Restablecer borra una base entera, así que se niega si la instancia no se
  declaró muestra **y** se niega si en la base hay un colegio que no sea de la
  muestra: la segunda mira los datos, no la variable. Borrar y sembrar van en
  una sola transacción: si la siembra falla, la muestra amanece como ayer.

### 4.4 · El dinero

- Precio en dólares, y final: lleva el IVA adentro (decisión 28). Un colegio de
  360 alumnos: 360 × 0,35 = **126,00 $ al mes.** Uno de 100: el mínimo,
  **45,00 $.** Ninguna pantalla desglosa un IVA ni dice «más IVA».
- En bolívares se paga a la tasa BCV del día. SIGA no guarda tasas: la cuenta la
  hace quien paga y Daniel la revisa al validar, igual que en los pagos de las
  familias (`payment_reports` no tiene columna de tasa).
- La unidad del monto la da el medio: Pago Móvil o transferencia, bolívares;
  Binance y efectivo, dólares.
- **Para el contador de Daniel,** fuera de este spec: si los pagos en dólares
  (USDT y efectivo) llevan además el IGTF del 3 %, y si le toca factura digital
  por vender en línea.

## 5 · Cómo se ve

### 5.1 · La portada

```
   ANTES                                           DESPUÉS
   [Agende una demostración de 20 min ↗]           [Registre su colegio →]          ← el principal
   [Entrar al sistema →]                           [Escríbanos por WhatsApp]
   ¿Todavía no tiene cuenta? Registre su colegio   [Vea un colegio funcionando]
                                                   («Entrar» queda en la barra de arriba)

   «04 — La suscripción»                           «04 — La suscripción»
   Inicial 39 · Estándar 79 · Grande 119           0,35 $ por alumno al mes · mínimo 45 $
   · A convenir                                    cargar su colegio es gratis
```

El precio sigue fuera del bloque principal, como lo dejó Daniel: lo contesta la
sección «La suscripción», que es donde lo busca quien quiere saberlo.

### 5.2 · El registro

```
   Cree su cuenta
   En un solo paso queda su cuenta y su colegio, con sus grados, sus áreas de
   aprendizaje y sus años escolares ya cargados.
   Cargar su colegio es gratis y no vence. Calificar, pasar lista y emitir:      ← nueva
   0,35 $ por alumno al mes.
```

### 5.3 · La pantalla «Suscripción»

Para la dirección y finanzas de un colegio de 360 alumnos que todavía no paga:

```
   ┌─ Suscripción ──────────────────────────────────────────────────────────┐
   │                                                                        │
   │  Sin suscripción activa                                                │
   │  Cargar es libre. Calificar, pasar lista y emitir se activan           │
   │  al validarse el pago.                                                 │
   │                                                                        │
   │  EL PRECIO                                                             │
   │  360 alumnos inscritos × 0,35 $, al mes                 126,00 $       │
   │                                                                        │
   │  CÓMO PAGAR                                                            │
   │  Pago Móvil o transferencia    en bolívares, a la tasa BCV del día     │
   │  Binance (USDT)                en dólares                              │
   │  Efectivo en dólares           se coordina por WhatsApp                │
   │                                                                        │
   │  [ Reportar el pago ]    [ Escribir por WhatsApp ]                     │
   └────────────────────────────────────────────────────────────────────────┘
```

Debajo va «Lo reportado»: cada reporte con su situación —en revisión,
validado con el mes que cubrió, o rechazado con su motivo—. El último rechazo
se lee además ARRIBA, junto al estado, hasta que el colegio reporte de nuevo:
es la respuesta que está esperando.

Lo de arriba cambia según el estado:

```
   sin suscripción     «Cargar es libre. Calificar, pasar lista y emitir se activan al validarse el pago»
   pago en revisión    «Recibimos el reporte del 9 de octubre; lo estamos validando»
   activa              «Activa hasta el 9 de noviembre»
   por vencer          «Vence el 9 de noviembre»
   en gracia           «Venció: quedan 12 días antes de pasar a solo lectura»
   solo lectura        «Se puede ver y descargar todo; para volver a cargar, hay que reportar el pago»
```

### 5.4 · El aviso de arriba y el muro

```
   EL AVISO, HOY                                 DESPUÉS
   «Plan Inicial, gratis. Cargar alumnos, …      «Sin suscripción activa. Cargar es libre;
    se activan al contratar un plan.»              calificar, pasar lista y emitir se activan
                                                   al validarse el pago. Ver cómo →»

   EL MURO, HOY                                  DESPUÉS
   vuelve atrás con «Calificar, pasar lista      «Calificar se activa con la suscripción:
    y emitir documentos se activan con un plan.    126,00 $ al mes por 360 alumnos.
    Cargar … es libre y no vence.»                 Ver cómo activarla →»
   sin precio y sin enlace
```

El precio lo ven quienes lo pagan —dirección y finanzas, decisión 14—. El
profesor que toca Calificar lee que la función todavía no está activa y que la
suscripción la lleva la dirección, sin precios que no son suyos.

Los portales —el de la familia, el del alumno— y los documentos del ministerio
no contestan con un aviso y un redirect: el destino por defecto de una familia
ES su portal, y redirigirla a él la dejaría dando vueltas. Muestran una página,
como la de la deuda de la familia, que dice que el colegio todavía no activó
esa parte. A una madre se le habla de usted, y tampoco de precios.

### 5.5 · Reportar el pago

```
   ┌─ Reportar el pago ──────────────────────────────┐
   │  Medio         (•) Pago Móvil o transferencia   │
   │                ( ) Binance (USDT)               │
   │                ( ) Efectivo en dólares          │
   │  Monto         [ 109.586,17 ] Bs                │   ← la unidad la da el medio
   │  Referencia    [ 0012345    ]                   │   ← no se pide en efectivo
   │  Fecha         [ 09/10/2026 ]                   │
   │  Comprobante   [ foto ]                         │   ← opcional en efectivo
   │  [ Enviar ]                                     │
   └─────────────────────────────────────────────────┘
```

Un solo reporte en revisión a la vez: el segundo espera a que se resuelva el
primero. Mientras nadie lo ha mirado, el colegio puede **retirarlo** y reportar
de nuevo (decisión 24): es la manera de corregir un monto o una referencia mal
escritos.

Se ofrecen solo los medios que SIGA tiene cargados en sus ajustes, y lo que se
pide lo da el medio:

```
   Pago Móvil o transferencia   monto en Bs   referencia   comprobante
   Binance (USDT)               monto en $    referencia   comprobante
   Efectivo en dólares          monto en $    —            comprobante, si hay
```

El reporte guarda la cuenta con que se hizo (decisión 25): los alumnos, el
precio por alumno, el mínimo y el monto de ese día.

### 5.6 · Validar, en /siga

```
   ┌─ Cartera · Pagos por validar ─────────────────────────────────────────────────┐
   │  U.E. COLEGIO SAN JOSÉ    Pago Móvil    Bs 109.586,17    ref. 0012345   9 oct │
   │  le toca: 126,00 $  (360 alumnos × 0,35)              [ Validar ] [ Rechazar ] │
   └───────────────────────────────────────────────────────────────────────────────┘

   Validar   ──►  la suscripción queda activa por un mes (§ 5.7) y se abre todo, en el momento
                  al colegio le llega un correo que dice hasta cuándo (decisión 23)
   Rechazar  ──►  pide el motivo; el colegio lo ve en su pantalla y le llega por correo
```

Validar pide confirmación —no hay botón para deshacerlo, decisión 27— y lo que
ya se revisó no se vuelve a decidir. Debajo, «Lo último que se revisó»: quién
validó o rechazó qué, y cuándo. Las dos cosas quedan además en el historial del
colegio, que es quien preguntará quién lo activó.

**Los ajustes** (`/siga/ajustes`, decisiones 20 a 22) son una pantalla con cinco
grupos: el WhatsApp de SIGA; a nombre de quién se paga (titular y cédula o RIF);
el Pago Móvil (banco y teléfono); la transferencia (la cuenta, de veinte
dígitos); y Binance Pay. Un medio se ofrece solo con sus datos completos, y el
efectivo, solo si hay WhatsApp con quién coordinarlo.

### 5.7 · La escalera, y el pago tarde

```
   5 días antes       correo + aviso: «vence el 9 de noviembre»        todo funciona
   vence              correo + aviso: «venció; quedan 15 días»         todo funciona   ← la gracia
   pasados 15 días    correo + aviso: solo lectura                     ve y descarga; las constancias siguen
   ─────────────────────────────────────────────────────────────────────────────────────────────
   un trabajo diario la mueve: nadie tiene que abrir nada
   nada baja mientras un pago espera validación
```

```
   AL VALIDAR, ¿DESDE CUÁNDO CUENTA EL MES?
   primer pago              desde el día que se valida
   pago a tiempo            desde el día que vencía         sin huecos ni días encimados
   pago en la gracia        desde el día que VENCIÓ         los días de gracia se pagan:
                                                            pagar tarde no regala nada
   pago en solo lectura     desde el día que se VALIDA      lo de solo lectura no se cobra:
                                                            no queda deuda
```

Sin la tercera fila, un colegio que paga siempre el día 14 de la gracia usaría
casi cuatro meses gratis al año.

«A tiempo», «en la gracia» y «en solo lectura» se miden por el día en que el
colegio **reportó**, no por el día en que se validó (decisión 26): quien reportó
el día 13 de la gracia pagó en la gracia, aunque se valide el 20.

## 6 · Criterios de aceptación

Marcado, lo que ya está construido y probado (tandas 1 y 2). Dos quedan sin
marcar aunque están casi enteros, porque nombran el REGISTRO y la PORTADA, que
llegan con la tanda de la puerta: el precio en un solo lugar —falta la línea
del registro— y los ajustes de `/siga` —el WhatsApp ya sale de ahí y está en
«Suscripción»; falta ponerlo en la portada y en el registro—.

**La puerta**

- [x] En la portada, el botón principal lleva a `/registrarse`; hay un botón de
      WhatsApp y uno al colegio de muestra.
- [x] El botón de WhatsApp está en la portada, en el registro y en
      «Suscripción». Si el número no está puesto, no aparece en ninguna: un
      botón que abre un chat con nadie es peor que no tener botón.
- [x] La portada ya no enlaza al formulario de demostración, y quien abre su
      dirección vieja llega a la portada.
- [x] El registro muestra la línea del precio, leída de la constante y no
      escrita a mano.
- [x] El botón a la muestra se dibuja solo si se sabe dónde vive
      (`SIGA_MUESTRA_URL`); sin ella, la portada invita a probarlo en el propio
      colegio. ⚠️ Esa variable hay que ponérsela a PRODUCCIÓN al desplegar.

**Lo gratis**

- [x] Un colegio recién registrado nace en `gratis` y puede cargar e importar
      todo.
- [x] En `gratis`, todo lo que no es cargar responde con el muro: calificar,
      pasar lista, cerrar el lapso, reparaciones, valoraciones, informes,
      cobranza, correos a las familias, los portales del representante y del
      alumno, y cualquier archivo PDF o Excel, salvo la plantilla del
      importador y el manual.
- [x] Un test recorre TODOS los controladores y falla si alguno no está
      clasificado como entrada, con suscripción o siempre abierto.
- [x] El muro dice el precio de ese colegio y enlaza a «Suscripción», también en
      la respuesta JSON de la planilla de notas.
- [x] Ningún colegio queda sin suscripción: el alta desde `/siga/colegios` le
      abre la suya con el mismo `Subscription.abrir_gratis!` que el registro, y
      un colegio sin fila cuenta como gratis.

**El precio**

- [ ] El precio por alumno y el mínimo viven en un solo lugar del código.
      Cambiarlos cambia la portada, el registro, la ficha para buscadores, la
      pantalla «Suscripción», el muro y la Cartera; lo cuida una versión nueva
      de `los_precios_de_un_solo_lugar_test`.
- [x] Con 360 alumnos: 126,00 $. Con 100: el mínimo, 45,00 $.
- [x] Ninguna pantalla ni correo dice «IVA»: el precio es final (decisión 28).
- [x] Al activarse, la suscripción congela su precio por alumno y su mínimo:
      cambiar la constante no le cambia el precio a un colegio que ya entró.
- [x] El monto de cada mes se calcula con la matrícula del día de la renovación.
- [x] Ninguna pantalla ni correo dice «Plan Inicial», «Estándar» ni «Grande».

**El salto**

- [x] Dirección y finanzas ven «Suscripción» en el menú; académico, no.
- [x] La pantalla dice el estado, la matrícula que se usó, el precio y cómo
      pagar por los tres medios.
- [ ] Desde `/siga`, el fundador cambia el número de WhatsApp y los datos para
      pagar (Pago Móvil y Binance); la portada, el registro y «Suscripción» los
      usan en el momento, sin reiniciar nada. Operaciones los ve y no los
      cambia.
- [x] Si un dato para pagar está vacío, su medio no aparece en «Suscripción».

**El cobro**

- [x] El colegio reporta medio, monto, referencia (salvo efectivo), fecha y
      comprobante; el reporte queda «en revisión» y a SIGA le llega un correo.
- [x] No puede haber dos reportes en revisión a la vez.
- [x] Validar en `/siga` deja la suscripción activa y abre calificar, asistencia
      y salidas en el momento. Valida el fundador.
- [x] Rechazar pide motivo; el colegio lo ve en su pantalla y le llega por
      correo.
- [x] Primer pago y pago en solo lectura: el mes cuenta desde la validación.
      Pago a tiempo o en la gracia: desde el vencimiento.
- [x] Un trabajo diario mueve los estados sin que nadie abra la Cartera, a una
      hora en que la fecha en UTC es la misma que en Venezuela (12 UTC: las 8
      de la mañana).
- [x] Sale correo, con su aviso en pantalla, 5 días antes, al vencer y al pasar a
      solo lectura; cada correo, una sola vez.
- [x] A quien ya reportó su pago no se le reclama: ni «vence», ni «venció».
- [x] Mientras un reporte está en revisión, el estado no baja.
- [x] En solo lectura se siguen emitiendo constancias, boletines y certificados,
      como hoy.

**El colegio de muestra**

- [x] Desde la portada de la muestra se entra con un clic como directivo,
      profesor o representante; la clave de los tres es `123123`.
- [x] Ahí no sale ningún correo, y cada noche vuelve a su estado sembrado.
- [x] Fuera de la muestra, entrar sin clave no existe: responde 404.
- [ ] La portada del sitio de verdad enlaza a la muestra (es de la tanda 4:
      `SIGA_MUESTRA_URL` ya hace que `/muestra` mande allá).

## 7 · Lo que se puede romper

- **Más de una docena de lugares leen las bandas** (`Subscription::PLANES`,
  `plan_para`, `precio_para`, `etiqueta_de_plan`): la portada, `metadatos_helper`
  (la descripción y el JSON-LD, con tres `offers`), el panel de `/siga`
  (`plan_por_matricula`, `tramos_de_los_planes`), la Cartera («hoy le
  tocaría…»), `db/seeds/07_dia_a_dia.rb` y cinco tests: `suscripciones_test`
  —«los cortes del contrato»—, `portada_publica_test`, `seo_test`,
  `los_precios_de_un_solo_lugar_test` y `plan_gratis_test`.
- **`subscriptions.precio_mensual` es entero.** Un precio por alumno da centavos
  (347 alumnos a 0,35: 121,45 $): pasa a decimal, como `payment_reports.monto`
  (`numeric(10,2)`).
- **El `CHECK` de `plan` admite de 0 a 4.** Cambiar los valores lo cambia. En
  producción no hay suscripciones; en la base local sí, sembradas por bandas.
- **«Sin fila es acceso completo» está probado a propósito**
  (`plan_gratis_test`: «un colegio sin suscripción no está en plan gratis»;
  `suscripciones_test`: «un colegio sin suscripción escribe normalmente»). Con
  la decisión 16 esos tests cambian de sentido: no es un descuido.
- **Y toda la suite lo da por hecho.** 95 archivos de test arman sus colegios
  con `dos_colegios_completos` y ninguno les crea suscripción: con la decisión
  16 nacerían en gratis y fallaría todo lo que califica, pasa lista o emite.
  El colegio de prueba nace PAGANDO (`escenario_academico`, `suscripcion:
  :por_alumno` por defecto); el que prueba lo gratis lo pide con `:gratis`.
- **El botón de WhatsApp vive hoy solo en el formulario de demostración**
  (`demo_requests/new` y `success`). Al sacar el formulario se iría con él si no
  se muda antes a la portada, el registro y «Suscripción».
- **El número de WhatsApp deja de ser una constante.** `ContactoHelper::SIGA_WHATSAPP`
  se lee del entorno al arrancar; pasa a leerse del ajuste de `/siga` en cada
  petición. Si la variable está puesta en producción, sirve de valor inicial
  del ajuste, para que el botón no desaparezca el día del cambio. La razón por
  la que no estaba en el repo —es un teléfono personal— sigue cumplida: en la
  base tampoco está en el repo.
- **Los ajustes son de la plataforma, no de un colegio.** La tabla no lleva
  `school_id` ni RLS, como `siga_staffs` y `demo_requests`; por eso se edita solo
  desde `/siga`.
- **La frontera por formato atrapa archivos que deben seguir abiertos:** la
  plantilla del importador (`importaciones#plantilla`) y el manual en PDF
  (`manual#show`). Van en la lista de excepciones, con su test.
- **El muro en JSON:** la planilla de notas recibe `402` con un `mensaje`. Si el
  mensaje trae un enlace, la planilla tiene que pintarlo.
- **«Inicial» es también un nivel** (Educación Inicial). La guarda que prohíbe
  los nombres viejos busca «Plan Inicial», no «Inicial», o se lleva por delante
  el preescolar.
- **Dos guardas dan por hecho el formulario de demostración.** El humo pide
  `/demo_requests/new` y espera 200 (`bin/smoke`, línea 152), y el sitemap lo
  anuncia (`seo_test`: «el sitemap trae las públicas y NINGUNA del panel»). Si
  la ruta pasa a llevar a la portada, las dos cambian con ella.
- **La zona horaria.** La app corre en UTC (`config.time_zone` está comentada):
  `Date.current` ya es «mañana» desde las 8 p. m. de Venezuela. Si el trabajo
  diario corre de noche, un colegio pasa a la gracia un día antes.
- **Los correos nuevos** entran a `correos_con_identidad_test` y
  `correos_en_el_telefono_test`: con versión en texto, su adelanto y su vista
  previa en `correos_de_siga_preview.rb`. Son correos DE SIGA: no llaman
  `a_nombre_de`.
- **El colegio de muestra aparte** se siembra con `SIGA_ENTORNO_DEMO=1` y
  `SIGA_SEED_PASSWORD=123123` escritos a mano: `SeedGuard` lo permite, y su
  comentario advierte en contra. Es una decisión consciente para una base sin
  nadie real, y por lo mismo esa base no puede ser la de producción: los seeds
  crean además una cuenta del equipo de SIGA que ve todos los colegios.
- **Guardas que dejan de guardar en silencio.** Un test que buscaba «Plan
  Inicial» o los tres precios en la portada pasa en verde cuando el texto
  desaparece. Hay que reemplazarlo por uno que busque lo nuevo, no solo
  borrarlo.

**Lo que enseñó la tanda 2**

- **El correo al colegio se encola DENTRO del colegio.** `/siga` no tiene
  colegio, y un trabajo se lleva el que haya al encolarlo (`CarriesSchool`). Sin
  él, el worker busca el pago con el RLS puesto, no lo encuentra y el correo no
  sale — sin que validar falle. ⚠️ Un test que entrega el correo dentro de la
  misma petición NO lo ve: ahí se ven todos los colegios. Lo cuida el que mira
  la carga del trabajo encolado.
- **Las dos salidas son dos listas.** «Suscripción» y el reporte están en
  `SIEMPRE_ABIERTO` —o el muro de lo gratis cerraría la pantalla donde se paga—
  y el reporte, además, en `SIEMPRE_PERMITIDO` —o la solo lectura, que rechaza
  todo verbo que escriba, cerraría la única puerta para dejar de estar vencido—.
- **Un doble clic son dos peticiones a la vez.** Validar bloquea la fila
  (`with_lock`), o el colegio recibe dos meses por un pago; el reporte se guarda
  en su `SAVEPOINT` y con la red del índice único, o el segundo envío es un 500
  que además deja abortada la transacción de la petición.
- **«Uno en revisión a la vez» lo sostiene un índice parcial.** Y un índice
  único con una condición de negocio NO es una clave: el diagrama del modelo lo
  leía como «un pago por colegio» (`modelo.rake`).
- **Una validación que busca otras filas necesita el colegio en contexto.** Sin
  él, el RLS devuelve cero y «ya hay uno en revisión» no encuentra nada. En una
  petición siempre lo hay; en un test o una consola, hay que ponerlo.
- **Los ajustes no son de la demo.** `demo:limpiar` borra a todas las personas y
  no puede llevarse el WhatsApp ni las cuentas con que SIGA cobra: `siga_settings`
  queda fuera del borrado, y su única clave foránea se pone en nulo sola.
- **`prueba:borrar` lleva su lista a mano**, y un colegio de prueba que reportó
  un pago no se dejaba borrar: hubo que sumarle los pagos y sus comprobantes.

**Lo que enseñó la tanda 5**

- **Sembrar «al límite» encuentra lo que el uso todavía no encontró.** Una
  familia con un hijo en cada nivel dejó a la vista dos huecos del portal: las
  valoraciones de Inicial salían «Pendiente» aunque estuvieran escritas, y los
  boletines del año pasado no se listaban aunque se pudieran descargar.
- **Un año terminado está terminado.** La siembra anterior tenía secciones
  completas, a medias y vacías en el mismo año: servía para «quién no cargó
  notas» y no se parecía a ningún colegio. Sin notas definitivas no hay a quién
  promover. Lo desparejo vive ahora en el año que corre, que es donde pasa.
- **Cerrar un lapso vivía en un controlador.** La siembra tenía que cerrar
  cuarenta y ocho, y la única manera sin una pantalla era copiar sus tres
  pasos. Se mudó a `BoletinesDelLapso#cerrar!`, que usan los dos.
- **Una cuenta sobre el número del alumno no es un sorteo.** Los alumnos de un
  mismo perfil comparten el resto de dividir su número: de ochenta y dos
  materias por reparar, setenta y tres «sacaron» la misma suerte. Con un
  resumen (MD5) quedó repartido.
- **El tope de una lista se decide antes de armarla.** Los reportes de pago se
  acotaban a doce al crearlos, y los que quedaban fuera tenían la cuota sin
  pagar y sin reporte: uno de cada cinco alumnos en mora.
- **Inicial no cierra lapsos ni tiene boletín por lapso.** `BoletinesDelLapso`
  cuenta notas con número. No se construyó: queda anotado en § 9.
- **El DATABASE_URL que inyecta Dokku es de superusuario.** La base de la
  muestra se montó como la de producción: el rol `siga_app`, dueño de la base y
  sin privilegios, creado ANTES de la primera migración.

## 8 · Cómo se verifica

- `bin/ci` completo.
- Un test de sistema de punta a punta: registrarse → cargar → tocar Calificar
  (el muro, con el precio) → reportar el pago → validar en `/siga` → calificar.
  Está escrito (`del_registro_al_pago_test`), y el muro se toca por la
  ASISTENCIA: quien paga es la dirección, que pasa lista y no califica —
  calificar es del profesor, que ve el muro sin precio.
- El trabajo diario con el tiempo detenido (`travel_to`): 5 días antes, al
  vencer y a los 15 días; con un reporte en revisión y sin él.
- El test que recorre todos los controladores.
- A mano, en la base local: «Suscripción» en sus seis estados, también en el
  teléfono.

## 9 · Al terminar: unificar todo

Daniel, 9 de octubre: *«Recuérdame al finalizar esto, actualizar y unificar
TODO; documentos, .md's, vistas, TODO.»*

```
   EN EL REPO    CLAUDE.md (Project Overview, § 7 y «Modelo de negocio»), ESTADO.md,
                 CHANGELOG.md, docs/manual («El plan Inicial es gratis…»),
                 docs/tareas-de-operacion.md («Cambiar el plan de un colegio»)
   FUERA         references/Proyecto SIGA.pdf · SIGA/CONTRATO DE PRESTACIÓN DE SERVICIOS
                 SIGA/DOCs/SIGA - Aliados.pdf · SIGA/DOCs/SIGA - Qué hace hoy.pdf
                 los dos videos de SIGA/ · las tarjetas de Linear
```

**Lo que enseñó la tanda 4**

- **Tres botones no cabían en el renglón del banner.** Su bloque mide lo que
  mide el texto, y el tercero caía solo a un segundo renglón, centrado, como si
  fuera otra cosa. En pantalla ancha se les deja salir de esa columna.
- **Una vez que alguien guarda los ajustes, `SIGA_WHATSAPP` deja de valer**
  —es su valor inicial—. Sembrar los ajustes deja la fila creada: en la muestra
  el número se pone con la variable ANTES de resembrar.
- **El formulario de demostración dejó reglas de estilo sin dueño** (`.solicitud…`).
  No se borraron: quitar un bloque de CSS a ciegas no falla, solo se ve feo.
  Queda para una limpieza con las pantallas delante.

**Lo que enseñó la tanda 3**

- **Para que un correo salga una sola vez hace falta acordarse de DOS cosas:**
  cuál fue el último aviso y de qué vencimiento era. Con el número solo habría
  que ponerlo en cero en cada lugar que mueve el vencimiento; con la fecha al
  lado, al validarse un pago la cuenta empieza de nuevo sin que nadie la toque.
- **Un test que pasa no dice qué cuida.** «Con un pago esperando, ni baja ni
  reclama» seguía en verde quitando la pregunta por el pago: en ese caso el
  estado ni se mueve, y no hay aviso que mandar. Lo que la pregunta protege es
  al colegio que reportó ANTES de vencer. Se encontró rompiéndola a propósito.
- **Anotar y encolar van juntos.** La cola vive en la misma base: en una
  transacción, el aviso anotado y el correo encolado se confirman a la vez.
- **El correo se encola dentro del colegio**, como en la tanda 2: el trabajo
  recorre todos y no tiene ninguno.
- **Los tres correos dicen primero lo que SIGUE funcionando.** Quien lee
  «venció» sin más cree que perdió el sistema, y llama.

**Lo que la tanda 5 dejó anotado, sin construir:**

```
   Inicial no cierra lapsos     `BoletinesDelLapso` cuenta notas con número: una sección de
                                Inicial nunca llega a «calificada», y no tiene boletín por lapso
   el boletín ANUAL no se       se emite desde «Boletines», pero liberar es del cierre de un
     libera a la familia        lapso: nadie lo libera, y la familia no lo ve
   el panel cuenta todos        «54 secciones» y «406 alumnos» con el año 2026-2027 elegido:
     los años                   suma los años anteriores
   DESPLIEGUE.md                describe el despliegue de agosto; el de la muestra está en
                                `docs/tareas-de-operacion.md`
```
