# Del registro al cobro

> **Estado:** **congelado el 12 de octubre de 2026.** Decisiones de Daniel del
> 8, 9 y 12 de octubre. Si algo cambia, se cambia aquí primero.
> **PR:** — (rama `feat/del-registro-al-cobro`)

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
                lista y emitir: 0,30 $ por alumno            representante, clave 123123
                al mes + IVA»
                       │
                       ▼
               CARGA, gratis y sin fecha: alumnos, familias, profesores, secciones, importador
                       │
                       ▼  toca Calificar, Asistencia o Emitir
               EL MURO: «125,28 $ al mes por 360 alumnos»  ──►  SUSCRIPCIÓN: cómo pagar
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
| 7 | ¿Cuánto? | **0,30 $ por alumno al mes, mínimo 39 $** | Daniel, 9 oct. |
| 8 | ¿Lleva factura? | **Sí, con IVA aparte:** «0,30 $ por alumno + IVA». La emite Daniel, fuera de SIGA | Daniel, 9 oct. |
| 9 | ¿Por qué medios se paga? | **Pago Móvil o transferencia,** en bolívares a la tasa BCV del día; **Binance (USDT)**; **efectivo en dólares.** Zelle, no | Daniel, 9 oct. |
| 10 | ¿El registro dice el precio? | **Sí, en una línea** | Daniel, 9 oct. |
| 11 | ¿Cuántos días de gracia? | **15**, como hoy | Daniel, 9 oct. |
| 12 | Si paga tarde, ¿desde cuándo cuenta el mes? | **Si paga en la gracia, desde que venció; si paga en solo lectura, desde que se valida** | Daniel, 9 oct. |
| 13 | ¿Dónde vive el colegio de muestra? | **En una instancia aparte, con su propia base.** Ver § 4.3 | Daniel, 12 oct. |
| 14 | ¿Quién ve «Suscripción»? | **Dirección y finanzas:** quien lleva el dinero es quien paga | Claude; confirmada por Daniel, 12 oct. |
| 15 | ¿Qué pasa con los nombres Inicial, Estándar y Grande? | **Desaparecen.** Con un solo plan, el colegio tiene la suscripción activa o no la tiene. De paso se acaba el choque de hoy: «Inicial» es a la vez el plan gratis y el de 39 $ | Claude; confirmada por Daniel, 12 oct. |
| 16 | ¿Puede un colegio quedarse SIN suscripción? | **No.** Hoy «sin fila» es acceso completo y sin fecha: es la puerta A. Todo colegio nace en `gratis`, y una cortesía o un piloto es una suscripción activa a 0 $, con su vencimiento | Claude; confirmada por Daniel, 12 oct. |
| 17 | ¿Se congela el precio del que entra? | **Sí:** cada colegio conserva su precio por alumno y su mínimo, y subirlos toca solo a los que entran después. Hoy ya se congela `precio_mensual` | Claude; confirmada por Daniel, 12 oct. |
| 18 | ¿Cómo se ajusta el precio? | Si cuatro de los primeros cinco colegios a los que se les cotiza aceptan sin discutir el precio, los siguientes entran a 0,40 | Claude; confirmada por Daniel, 12 oct. |
| 19 | ¿Qué pasa con el formulario de demostración? | **Sale de la portada;** su dirección lleva a la portada, y `/siga/solicitudes` se queda como historia | Claude; confirmada por Daniel, 12 oct. |
| 20 | ¿Dónde está el botón de WhatsApp, y de dónde sale el número? | **En la portada, el registro y «Suscripción».** Hoy vive solo en el formulario de demostración, que sale con la decisión 19. **El número es un ajuste que Daniel cambia desde `/siga`,** sin tocar el servidor; reemplaza a la variable `SIGA_WHATSAPP` | Daniel, 12 oct. |
| 21 | ¿Y los datos para pagar —Pago Móvil, Binance—? | **En el mismo ajuste de `/siga`,** por la misma razón: cambiar de cuenta no puede exigir un despliegue | Claude, por la misma razón que la 20 |
| 22 | ¿Quién valida pagos y cambia los ajustes? | **El fundador**, como ya pasa con tocar suscripciones (`SigaStaff#puede_dar_de_alta_colegios?`); operaciones los ve | Claude, siguiendo el código |

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

### 4.4 · El dinero

- Precio en dólares, más IVA (16 %). Un colegio de 360 alumnos:
  108,00 + 17,28 = **125,28 $ al mes.** Uno de 100: el mínimo,
  39,00 + 6,24 = **45,24 $.**
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
   Inicial 39 · Estándar 79 · Grande 119           0,30 $ por alumno al mes + IVA · mínimo 39 $
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
   0,30 $ por alumno al mes + IVA.
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
   │  360 alumnos inscritos × 0,30 $                         108,00 $       │
   │  IVA 16 %                                                17,28 $       │
   │  Al mes                                                 125,28 $       │
   │                                                                        │
   │  CÓMO PAGAR                                                            │
   │  Pago Móvil o transferencia    en bolívares, a la tasa BCV del día     │
   │  Binance (USDT)                en dólares                              │
   │  Efectivo en dólares           se coordina por WhatsApp                │
   │                                                                        │
   │  [ Reportar el pago ]    [ Escribir por WhatsApp ]                     │
   └────────────────────────────────────────────────────────────────────────┘
```

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
    y emitir documentos se activan con un plan.    125,28 $ al mes por 360 alumnos.
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
primero.

### 5.6 · Validar, en /siga

```
   ┌─ Cartera · Pagos por validar ─────────────────────────────────────────────────┐
   │  U.E. COLEGIO SAN JOSÉ    Pago Móvil    Bs 109.586,17    ref. 0012345   9 oct │
   │  le toca: 125,28 $  (360 alumnos × 0,30 + IVA)        [ Validar ] [ Rechazar ] │
   └───────────────────────────────────────────────────────────────────────────────┘

   Validar   ──►  la suscripción queda activa por un mes (§ 5.7) y se abre todo, en el momento
   Rechazar  ──►  pide el motivo; el colegio lo ve en su pantalla y le llega por correo
```

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

## 6 · Criterios de aceptación

**La puerta**

- [ ] En la portada, el botón principal lleva a `/registrarse`; hay un botón de
      WhatsApp y uno al colegio de muestra.
- [ ] El botón de WhatsApp está en la portada, en el registro y en
      «Suscripción». Si el número no está puesto, no aparece en ninguna: un
      botón que abre un chat con nadie es peor que no tener botón.
- [ ] La portada ya no enlaza al formulario de demostración, y quien abre su
      dirección vieja llega a la portada.
- [ ] El registro muestra la línea del precio, leída de la constante y no
      escrita a mano.

**Lo gratis**

- [ ] Un colegio recién registrado nace en `gratis` y puede cargar e importar
      todo.
- [ ] En `gratis`, todo lo que no es cargar responde con el muro: calificar,
      pasar lista, cerrar el lapso, reparaciones, valoraciones, informes,
      cobranza, correos a las familias, los portales del representante y del
      alumno, y cualquier archivo PDF o Excel, salvo la plantilla del
      importador y el manual.
- [ ] Un test recorre TODOS los controladores y falla si alguno no está
      clasificado como entrada, con suscripción o siempre abierto.
- [ ] El muro dice el precio de ese colegio y enlaza a «Suscripción», también en
      la respuesta JSON de la planilla de notas.
- [ ] Ningún colegio queda sin suscripción: el alta desde `/siga/colegios` le
      abre la suya con el mismo `Subscription.abrir_gratis!` que el registro, y
      un colegio sin fila cuenta como gratis.

**El precio**

- [ ] El precio por alumno, el mínimo y el IVA viven en un solo lugar del código.
      Cambiarlos cambia la portada, el registro, la ficha para buscadores, la
      pantalla «Suscripción», el muro y la Cartera; lo cuida una versión nueva
      de `los_precios_de_un_solo_lugar_test`.
- [ ] Con 360 alumnos: 108,00 + 17,28 = 125,28 $. Con 100: 39,00 + 6,24 = 45,24 $.
- [ ] Al activarse, la suscripción congela su precio por alumno y su mínimo:
      cambiar la constante no le cambia el precio a un colegio que ya entró.
- [ ] El monto de cada mes se calcula con la matrícula del día de la renovación.
- [ ] Ninguna pantalla ni correo dice «Plan Inicial», «Estándar» ni «Grande».

**El salto**

- [ ] Dirección y finanzas ven «Suscripción» en el menú; académico, no.
- [ ] La pantalla dice el estado, la matrícula que se usó, el precio con su IVA y
      cómo pagar por los tres medios.
- [ ] Desde `/siga`, el fundador cambia el número de WhatsApp y los datos para
      pagar (Pago Móvil y Binance); la portada, el registro y «Suscripción» los
      usan en el momento, sin reiniciar nada. Operaciones los ve y no los
      cambia.
- [ ] Si un dato para pagar está vacío, su medio no aparece en «Suscripción».

**El cobro**

- [ ] El colegio reporta medio, monto, referencia (salvo efectivo), fecha y
      comprobante; el reporte queda «en revisión» y a SIGA le llega un correo.
- [ ] No puede haber dos reportes en revisión a la vez.
- [ ] Validar en `/siga` deja la suscripción activa y abre calificar, asistencia
      y salidas en el momento. Valida el fundador.
- [ ] Rechazar pide motivo; el colegio lo ve en su pantalla y le llega por
      correo.
- [ ] Primer pago y pago en solo lectura: el mes cuenta desde la validación.
      Pago a tiempo o en la gracia: desde el vencimiento.
- [ ] Un trabajo diario mueve los estados sin que nadie abra la Cartera, a una
      hora en que la fecha en UTC es la misma que en Venezuela.
- [ ] Sale correo, con su aviso en pantalla, 5 días antes, al vencer y al pasar a
      solo lectura; cada correo, una sola vez.
- [ ] Mientras un reporte está en revisión, el estado no baja.
- [ ] En solo lectura se siguen emitiendo constancias, boletines y certificados,
      como hoy.

**El colegio de muestra**

- [ ] Desde la portada se entra con un clic como directivo, profesor o
      representante; la clave de los tres es `123123`.
- [ ] Ahí no sale ningún correo, y cada noche vuelve a su estado sembrado.

## 7 · Lo que se puede romper

- **Más de una docena de lugares leen las bandas** (`Subscription::PLANES`,
  `plan_para`, `precio_para`, `etiqueta_de_plan`): la portada, `metadatos_helper`
  (la descripción y el JSON-LD, con tres `offers`), el panel de `/siga`
  (`plan_por_matricula`, `tramos_de_los_planes`), la Cartera («hoy le
  tocaría…»), `db/seeds/07_dia_a_dia.rb` y cinco tests: `suscripciones_test`
  —«los cortes del contrato»—, `portada_publica_test`, `seo_test`,
  `los_precios_de_un_solo_lugar_test` y `plan_gratis_test`.
- **`subscriptions.precio_mensual` es entero.** 0,30 por alumno da centavos
  (347 alumnos: 104,10 $): pasa a decimal, como `payment_reports.monto`
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

## 8 · Cómo se verifica

- `bin/ci` completo.
- Un test de sistema de punta a punta: registrarse → cargar → tocar Calificar
  (el muro, con el precio) → reportar el pago → validar en `/siga` → calificar.
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
