# Los pagos de la familia

**Estado:** construido y revisado · **Ramas:** `feat/pagos-de-la-familia`,
`feat/un-pago-para-varios-hijos`
**Pedido por Daniel**, 13 de septiembre de 2026.

> *«El representante reporta y el administrador, la parte financiera de la
> escuela, debe poder validar esos pagos.»*

---

## El problema

Un colegio venezolano cobra por WhatsApp y anota en un cuaderno. La mamá
transfiere, manda la foto del voucher al grupo, y alguien en la oficina tacha un
nombre en una lista impresa. Cuando en octubre hay que saber quién debe agosto,
la respuesta está en tres cuadernos y en el teléfono de la secretaria.

SIGA no va a cobrar el dinero —eso lo hace el banco— pero sí puede ser **el
lugar donde consta quién pagó qué**.

```
   LA MAMÁ                              LA OFICINA
   ───────                              ──────────
   ve qué debe y de qué mes             ve los reportes que entran
   transfiere por su banco              abre el voucher y lo compara
   reporta el pago + la foto            valida  →  el cobro queda pagado
   queda «en revisión»                  rechaza →  dice por qué
```

---

## Lo que se cobra, lo que se debe y lo que se reporta

Son **tres** cosas distintas y confundirlas es lo que hace inservibles a los
sistemas de cobranza escolares:

```
   ConceptoDeCobro    lo que el COLEGIO cobra ese año
                      «Inscripción · 120 $ · vence 15/08»
                      se define al crear el año escolar

   Cobro              lo que UN ALUMNO debe
                      una fila por (inscripción × concepto)
                      nace al inscribirse, muere cuando se paga

   ReporteDePago      lo que la MAMÁ dice que pagó
                      con su referencia, su banco y su voucher
                      en_revision → validado | rechazado
```

⚠️ **Un reporte no paga nada por sí solo.** Marca uno o varios cobros como
«reportados»; es la validación de la oficina la que los da por pagados. Sin esa
separación, quien escribe cualquier número de referencia se libera el acceso.

---

## ⚠️ Agosto se paga en julio, y NO todos los meses van adelantados

Daniel, corrigiendo: *«ese mes en particular, ¿ok? Ese mes en particular, no
todos»*.

La consecuencia de diseño es que **la fecha de vencimiento es un campo**, no una
regla. SIGA propone el calendario habitual al crear el año escolar —la
inscripción, y una mensualidad por mes con agosto venciendo en julio— y el
colegio corrige lo que sea distinto en su caso.

Una regla escrita en Ruby («la mensualidad vence el día 5 del mes anterior»)
habría que cambiarla por despliegue cada vez que un colegio cobre distinto. Un
campo lo arregla la secretaria.

---

## ⚠️ La deuda que bloquea NO es la deuda del colegio con SIGA

Son dos, y se parecen lo suficiente como para mezclarlas —pasó al escribir la
primera versión de esto:

```
   EL COLEGIO le debe a SIGA          LA FAMILIA le debe al COLEGIO
   ─────────────────────────          ─────────────────────────────
   el sistema pasa a solo lectura     el representante entra igual
   las constancias SIGUEN saliendo    pero no ve notas, asistencia
   (el perjuicio no puede ser          ni constancias
    del alumno — § MOR-108)
```

Daniel: *«ellos deben siempre poder ingresar a la sesión. Lo que no pueden ver
es… ni las constancias de estudios, ni ver las boletas, ni la asistencia, ni
nada del contenido relevante»*.

⚠️ **Se entra, no se expulsa.** La sesión funciona, el menú está, y las tres
pantallas bloqueadas muestran un aviso amable que explica qué pasa y lleva a
reportar el pago. Una puerta cerrada sin explicación es una llamada al colegio.

⚠️ **El bloqueo es por INSCRIPCIÓN, no por representante.** Una madre con dos
hijos puede estar al día con uno y deber por el otro: bloquearle los dos la
castiga por una deuda que no tiene.

---

## El formulario del reporte

Lo que pidió Daniel, más lo que hace falta para que un pago se pueda encontrar
en el estado de cuenta del banco:

| campo | por qué |
|---|---|
| **Referencia** | indispensable: es lo que la oficina busca en el banco |
| **Banco de origen** | lista cerrada de los bancos venezolanos, con su código |
| **Monto** | lo que se transfirió |
| **Fecha del pago** | cuándo salió el dinero — **no** es `created_at` |
| **Depositante** | nombre y cédula: casi nunca es la madre, es el papá o la abuela |
| **Voucher** | la foto de la transferencia |
| **Nota** | opcional, para lo que no cabe en un campo |
| **Qué cobros paga** | uno o varios, que es como paga la gente |

⚠️ **Dos fechas, y la diferencia importa.** `created_at` es cuándo se reportó;
`pagado_el` es cuándo se transfirió. Un pago del 3 reportado el 28 está al día o
en mora según cuál se mire, y la que manda es la del banco.

⚠️ **El calendario no ofrece el año pasado.** Se reporta lo de estos días, no lo
de 2024: el selector abre acotado y eso evita el dedazo de año que después nadie
encuentra.

⚠️ **La referencia es única POR COLEGIO, no global.** Dos bancos distintos
emiten el mismo número de referencia todo el tiempo; un índice global le
impediría a una familia reportar un pago legítimo porque otro colegio, de otro
estado, ya usó ese número.

---

## El voucher: disco local, pero encogido

Daniel: *«hoy en día la gente le toma foto al voucher… el peso a veces llega
hasta unos cuantos MB, 3 MB, 4 MB… creo que aun así podemos mantener el disco
local por ahora»*.

```
   entra          3–4 MB     la foto tal cual sale del teléfono
   se guarda      ~250 KB    1600 px de lado mayor, JPEG al 78 %
```

⚠️ **Se encoge al recibirla, y se guarda la encogida.** A 1600 px la referencia
del voucher se lee sin esfuerzo —lo comprobamos— y es la diferencia entre 10 GB
y 900 MB al año en un colegio de 360 alumnos. El disco local de Dokku ya está
montado en un volumen (`/rails/storage`), así que sobrevive a los despliegues.

⚠️ **S3 cuando haga falta, no antes.** La cuenta de Contabo es una pieza más que
configurar, respaldar y pagar; con el volumen actual no hace falta todavía.

---

---

## Lo que cambió al revisarlo con Daniel

### La deuda con el colegio es UNA

> *«La deuda con el colegio es una, debe ser vista y reportada como tal, sin
> importar los hijos que se tengan estudiando.»*

Era una tarjeta por hijo, cada una con su total y su botón: la madre tenía que
sumar de cabeza y decidir por cuál empezar. Ahora es un encabezado con el total
del colegio y una pestaña por hijo, con un punto que marca cuál está en mora.

### Y un pago cubre a varios hijos

> *«Yo tengo dos hijos, uno en el liceo y otro en primaria, y cuando hago un
> pago no hago un pago para uno y un pago para el otro. Hago el pago de los dos.
> Eso es lo natural.»*

Se borró `payment_reports.enrollment_id`: era un duplicado —la inscripción ya
viaja en cada cuota— y era justo lo que obligaba a partir una transferencia en
dos. Lo que ya existía y no se perdió:

```
   UN reporte  ──►  MUCHAS cuotas     ya funcionaba
   UNA cuota   ──►  UN reporte        ya funcionaba
```

⚠️ **N:N queda para después.** Una cuota pagada por dos reportes son ABONOS
PARCIALES: cada enlace necesita su monto, la cuota gana estados intermedios, y
«al día / en mora» —que es lo que bloquea el acceso— deja de ser sí/no.

### Corregir después de equivocarse, por las DOS partes

> *«El error humano es posible, entonces deben poder corregir.»*

```
   LA FAMILIA, antes de que lo miren     LA OFICINA, después
   ─────────────────────────────────     ───────────────────
   corregir cualquier dato               revertir una validación
   retirar el reporte entero             revalidar un rechazo
```

⚠️ El corte es la **revisión**, no el tiempo: antes no se aplicó nada, así que
cambiar la referencia no deshace ninguna decisión. Después sí — un validado que
la familia edita convierte el papel que la oficina ya comparó con el banco en
otro papel.

⚠️ Y la oficina **ve** que se corrigió (`corregido hace 3 minutos`). El caso que
muerde no es que la familia se equivoque: es que finanzas abra el reporte, se
vaya al banco a buscar la referencia, y al volver valide unos números que nunca
leyó.

⚠️ Revalidar un rechazado **no pisa** lo que la familia reportó después: solo
recupera las cuotas que siguen libres.

### Validar sin abrir el voucher

> *«Si tiene que revisar 400 vouchers en un día… si lo comparas contra el banco
> y ves que todo está ok, no necesitas revisar.»*

La bandeja valida de a uno, **sin diálogo de confirmación** —cuatrocientos clics
de más son el trabajo que el botón viene a quitar— y lo que lo hace responsable
es «Revertir la validación».

### El vacío legal de la moneda

> *«Hay un vacío legal en el país que en este momento se está discutiendo… si el
> personal de finanzas avala un pago, quiere decir que ese pago tiene su
> equivalente en dólares.»*

```
   LO QUE SE DEBE        en $     la unidad de cuenta del colegio
   LO QUE SE TRANSFIERE  en Bs    lo que dice el voucher
   LA VALIDACIÓN         el puente
```

⚠️ **SIGA no guarda ninguna tasa, y no le hace falta**: la equivalencia no es un
dato, es un ACTO. Y el día que se resuelva el vacío legal no hay nada que
migrar.

⚠️ A la familia se le muestra el número **sin unidad** —SIGA no afirma una
moneda que hoy no puede respaldar—; adentro sí, porque quien cobra necesita ver
la unidad de cuenta para avalar la equivalencia.

⚠️ Y **no se comparan**: restar bolívares de dólares no significa nada, y el
aviso de «no cuadra» habría saltado siempre.

### La lista de morosos lleva a algún lado

> *«Esta lista debería tener enlaces al detalle del deudor.»*

`/finanzas/deudor/:inscripcion`, y el orden de esa pantalla es el del trabajo:
primero **a quién llamar** —con `tel:` y WhatsApp— y después qué debe. Quien la
abre ya sabe que hay una deuda; lo que necesita es el teléfono.

---

## Lo que NO entra en esta primera etapa

- **Cobrar dentro de SIGA.** Esto registra pagos hechos por fuera; no hay
  pasarela.
- **Montos distintos por grado.** Un concepto es del año y vale lo mismo para
  todos. El colegio que cobre distinto crea dos conceptos.
- **Recargos por mora, descuentos por hermano, becas.** Se anotan a mano bajando
  el monto del cobro.
- **Conciliación bancaria automática.** La oficina compara a ojo con el voucher.
- **Abonos parciales** (N:N entre cuota y reporte). Ver arriba.
- **Una tasa de cambio.** La equivalencia la avala quien valida.
- **Factura.** Daniel: «más adelante deberíamos tener una factura, pero eso es
  aparte».
- **El histórico de años anteriores.** Hoy un año sin cuotas cargadas
  simplemente no se muestra.
