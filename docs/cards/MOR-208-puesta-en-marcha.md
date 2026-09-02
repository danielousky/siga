# MOR-208 · La puesta en marcha, vista por un director

> **Estado: TOMANDO NOTA.** Daniel va dictando observaciones; el plan se arma
> después, con todas sobre la mesa. **No implementar nada desde acá todavía.**

## El hallazgo

Daniel, 2 de septiembre de 2026:

> *«Anoche le pedí a mi esposa que fungiera como director y en verdad no fue lo
> que esperaba. Los 8 pasos son engorrosos incluso para mí, que tengo todo el
> contexto; para un director puede llegar a ser frustrante. Ya tenemos el
> andamiaje inicial completo. Hay que trabajar en cómo mostrarlo de la mejor
> manera.»*

⚠️ **Es una prueba con una persona de verdad**, no una impresión: alguien que no
construyó esto intentó usarlo de punta a punta. Ese es el único tipo de
evidencia que sirve para esta clase de problema, y es la primera que tenemos.

## Lo que NO está en discusión

El andamiaje: los ocho pasos existen, funcionan y cubren lo que hace falta para
que un colegio quede operativo. Lo que se rediseña es **cómo se presentan**, no
lo que hacen.

⚠️ Conviene tenerlo presente para no confundir «son muchos pasos» con «hay que
sacar pasos»: la mitad son obligatorios para que el sistema sirva. El problema
declarado es de PRESENTACIÓN.

## Las observaciones

<!-- Se van agregando acá, en el orden en que Daniel las dicta. -->

### 1 · El registro es UN paso: la persona y su colegio juntos

> *«El registro inicial de un usuario debe ser el registro del usuario
> principal, junto con los datos iniciales de la escuela. El registro de usuario
> no debe incluir la cédula, solo lo más sencillo: nombre y correo del usuario
> que va a manejar la cuenta.*
>
> *Puedes preguntarle el cargo para saber si es director o asistente. Puede ser
> director, asistente u otro, para el renglón del usuario. Nada de cédula, logo
> o sello, ni nada de eso. Ese mismo paso, en ese mismo formulario, se le
> pregunta el nombre de la escuela y, allí mismo, el tipo: preescolar, primaria,
> bachillerato, técnico (los cuatro tipos). Ese es el primer paso, sencillo y
> directo. Luego él puede entrar a los detalles y cambiar alguna cosa que
> considere.»*

**Lo que queda en el formulario:**

```
   LA PERSONA          nombre · correo · contraseña · cargo
   EL COLEGIO          nombre · qué dicta (los cuatro tipos)
```

Nada más. El cargo es **director / asistente / otro**.

**Lo que se cae de ahí:** cédula, código DEA, ubicación, teléfono, dirección,
logo, sello. Todo eso pasa a ser algo que el director completa después, cuando
quiera.

#### Con qué se cruza esto (para el plan, no decisiones)

- **La cédula ya se fue** del registro en `MOR-196`. Falta el resto.
- **Dos pantallas se funden en una.** Hoy son `/registrarse` y después
  `/mi-colegio/nuevo`, y esa separación tenía un motivo escrito: *«son dos actos
  distintos y el segundo puede fallar solo; juntarlos haría que un error de
  tipeo en la dirección le borre el usuario»*. ⚠️ Con la dirección fuera del
  formulario ese motivo casi desaparece, pero hay que resolver qué pasa si el
  colegio falla y el usuario ya se creó.
- **El «tipo» del colegio.** `school_type` **se borró** en `MOR-160` justamente
  por ser excluyente («o primaria o bachillerato») cuando la mitad del mercado
  dicta varias cosas. Lo que hoy existe es `niveles`, que es MÚLTIPLE y se
  deduce de los grados; se elige marcando casillas en `/niveles`, que es el paso
  1 de la puesta en marcha. ⚠️ Así que esto **no es resucitar `school_type`**:
  es traer el paso de los niveles al registro. Y si va a ser marcar los cuatro
  tipos, sigue siendo múltiple —un colegio con preescolar y primaria marca dos—.
  ⚠️ Ojo con la Media Técnica: marcarla siembra también el bachillerato (no hay
  sexto año sin los cinco anteriores).
- **El cargo.** `Admin#role` es un enum con `desarrollador, director, finanzas,
  coordinador, secretaria`. «Asistente» y «otro» no están; hay que decidir si se
  mapean a los existentes o si el enum cambia.
- **`DEA` es obligatorio hoy** (`validates :dea_code, presence: true`) y sale
  del formulario. Hay que decidir qué lo reemplaza mientras no esté.

## El plan

### La forma nueva

```
   HOY                                    PROPUESTO
   ───                                    ─────────
   1  registrarse (persona)               1  CREAR LA CUENTA
   2  crear el colegio                       persona + colegio, un formulario
   3  qué niveles dicta                      ─────────────────────────────────
   4  la identidad del colegio              «Su colegio quedó en orden»
   5  departamentos                          el resumen. No lleva número:
   6  materias y profesores                  no es trabajo de nadie.
   7  año escolar y lapsos                 ─────────────────────────────────
   8  secciones                           2  TRAER SUS DATOS
   9  matrícula                              las tres planillas, en orden
  10  historial                            3  LO QUE FALTE
                                              secciones · quién dicta qué
   8 pasos, todos formularios                 matrícula · historial
```

El eslogan es la vara: **«El colegio que imaginas, en orden.»** Si un paso se
siente como trabajo del director en vez de como orden que aparece, está mal
contado.

### Los cambios, en orden de dependencia

**1 · Fundir el registro** (`RegistrosController` + `MiColegioController`)

Un formulario, dos bloques:

```
   LA PERSONA    nombre · apellido · correo · contraseña · cargo
   EL COLEGIO    nombre · código DEA · qué dicta (4 casillas)
```

⚠️ Los cuatro tipos ya existen y coinciden exactamente con lo que pidió Daniel:
`GradoOficial::NIVELES` es `preescolar · primaria · secundaria («Bachillerato»)
· media_tecnica`. No hay que inventar nada, ni resucitar `school_type`.

⚠️ **Una sola transacción**, y ahí muere la objeción que separaba las dos
pantallas: si el colegio falla, no queda un usuario huérfano. Lo que hay que
cuidar es que el error se vea —el formulario vuelve con lo escrito— y que el
correo de bienvenida salga DESPUÉS del commit, no dentro.

**2 · Sembrar el andamiaje** (un servicio nuevo, `SembrarElColegio`)

Encadena lo que ya existe y agrega lo único que falta:

```
   los GRADOS            SembrarGrados          ✓ existe, idempotente
   los AÑOS escolares    ← nuevo                el que viene + 4 anteriores
   los LAPSOS            AcademicPeriod         ✓ nacen con el año (MOR-163)
   las MATERIAS          ← nuevo, hay que investigar el pensum del MPPE
   los DEPARTAMENTOS     ← nuevo, ver decisión abierta
```

⚠️ **Idempotente y en una transacción**, como `SembrarGrados` y
`CopiarLaEstructura`: sembrar a medias deja un colegio con grados y sin años, y
eso confunde más que no sembrar nada.

⚠️ **La regla del año.** Antes del 1.º de agosto, el año en curso; desde agosto,
el que empieza en septiembre. Y `AcademicPeriod.en_operacion` tiene que seguir
devolviendo el que TIENE alumnos — es la trampa que ya apareció tres veces.

**3 · La pantalla del andamiaje** (`/arranque` o el propio panel)

No pide nada. Dice qué se creó, **con números**, y cada línea lleva a editarlo:

```
   ✓  14 grados          Preescolar · Primaria · Bachillerato   → Ver los grados
   ✓  38 materias        del pensum del MPPE                    → Ver las materias
   ✓   4 departamentos                                          → Ver
   ✓   5 años escolares  2022-2023 … 2026-2027, con sus lapsos  → Ver
```

⚠️ Sin los enlaces, «se creó esto por usted» se lee como «alguien decidió esto
por usted». Con ellos, es un regalo que se puede devolver.

**4 · La puerta del importador** (`ImportacionesController#index`)

Dos estados, no uno:

```
   COLEGIO VACÍO      las tres planillas como SECUENCIA, con su estado
                      («1 · materias y profesores — pendiente»)
   COLEGIO EN USO     lo de hoy: elija la planilla que vino a subir
```

⚠️ Y una sola secuencia en toda la app: hoy el estado vacío del importador dice
un orden y `PasosDeArranque` dice otro.

**5 · Lo que sobrevive, renumerado**

Secciones, quién dicta qué, matrícula e historial. ⚠️ Casi todo eso lo trae el
importador, así que la lista tiene que reaccionar a lo importado y no pedir dos
veces lo mismo.

### Decidido (Daniel, 2 de septiembre de 2026)

1. **El cargo:** *«podemos agregar el rol de asistente»*. Se suma `asistente` al
   enum de `Admin#role`.
2. **Los departamentos:** *«no es un drama crearle departamentos a un colegio
   pequeño, puede servirle. La idea es que igual ellos pueden luego cambiar el
   nombre del dpto y reasignar FÁCILMENTE las materias que lo componen»*. Se
   crean siempre. ⚠️ Y eso agrega trabajo: **reasignar materias entre
   departamentos tiene que ser fácil**, cosa que hoy solo se puede haciendo
   `Editar` en cada materia, una por una.
3. **El correo:** se valida al escribir, como se pidió. La objeción que levanté
   no aplicaba: el formulario **ya** dice «Correo ya está en uso» al enviar, así
   que hacerlo en vivo no expone nada nuevo — solo llega antes.
4. **Cuatro años atrás**, y las fechas son una AYUDA, no una ley. Daniel: *«al
   final lo que hace falta es el año; las fechas de inicio y culminación son un
   estimado, no una regla inquebrantable»*. ⚠️ Vale para el código: se proponen
   fechas razonables y el colegio las corrige; nada debe romperse si no
   coinciden con el calendario real.

### El pensum oficial (investigado, 2 de septiembre de 2026)

⚠️ **Hay una diferencia entre lo que dice el currículo y lo que un colegio
escribe en un boletín, y no se puede ignorar.** El Currículo Bolivariano agrupa
en pocas «áreas de aprendizaje» amplias; un colegio privado califica materias
más finas. Sembrar las áreas oficiales daría un boletín que ningún
representante reconoce.

**Media General — las 14 áreas de formación (MPPE, 2017), con su año exacto.**
Esta parte es oficial y está completa, así que se puede sembrar tal cual, con
sus `GradeSubject` por año:

| Área de formación | Años |
| -- | -- |
| Castellano | 1.º a 5.º |
| Matemáticas | 1.º a 5.º |
| Educación Física | 1.º a 5.º |
| Inglés y otras lenguas extranjeras | 1.º a 5.º |
| Orientación y Convivencia | 1.º a 5.º |
| Participación en Grupos de Creación, Recreación y Producción | 1.º a 5.º |
| Geografía, Historia y Ciudadanía | 1.º a 5.º |
| Ciencias Naturales | 1.º y 2.º |
| Arte y Patrimonio | 1.º y 2.º |
| Física · Química · Biología | 3.º a 5.º |
| Formación para la Soberanía Nacional | 4.º y 5.º |
| Ciencias de la Tierra | 5.º |

⚠️ **Esto explica algo del modelo que ya está**: Física, Química y Biología
empiezan en 3.º y Ciencias Naturales termina en 2.º. Sembrarlas en todos los
años llenaría el boletín de un primer año con materias que no cursa.

**Primaria — las cuatro áreas oficiales son demasiado gruesas.** El currículo
de 2007 define «Lenguaje, Comunicación y Cultura», «Matemática, Ciencias
Naturales y Sociedad», «Ciencias Sociales, Ciudadanía e Identidad» y «Educación
Física, Deportes y Recreación». Lo que un colegio califica, y lo que Daniel
nombró, es más fino: **Lengua, Matemática, Ciencias Naturales, Ciencias
Sociales, Educación Física y Deporte**, más lo que cada colegio agregue —Inglés,
Educación Estética, Computación—.

⚠️ **Propuesta: sembrar lo que se califica, no lo que se legisla**, y decirlo en
la pantalla del resumen. Es la misma lógica de `GradoOficial`: se propone lo
correcto y el colegio ajusta.

**Preescolar — no se califica por materias.** El currículo de Educación Inicial
tiene DOS áreas de aprendizaje: «Formación Personal, Social y Comunicación» y
«Relación entre los Componentes del Ambiente». ⚠️ Eso encaja con que SIGA ya
califique preescolar en escala LITERAL y no numérica; sembrar «Matemática» en
preescolar sería un error de dominio.

**Fuentes:** [las 14 áreas de Media General](https://lanacionweb.com/reportajes-y-especiales/14-areas-conforman-el-plan-de-estudio-de-media-general/) ·
[Currículo Nacional Bolivariano](https://ve.scielo.org/scielo.php?script=sci_arttext&pid=S1316-49102007000400020) ·
[Educación Inicial Bolivariana](http://www.cerpe.org.ve/tl_files/Cerpe/contenido/documentos/Actualidad%20Educativa/Curriculo%20Educacion%20Inicial%20Bolivariana.%202007.pdf)

⚠️ **Dónde vive esto:** es el mismo tipo de dato que `GradoOficial` —lo fija la
ley, es igual en los 3.900 colegios— así que va como constante, no en la base:
`MateriaOficial`, con su nivel, su código propuesto y los años en que se cursa.

### Lo que queda por decidir

1. **El cargo.** `Admin#role` es `desarrollador · director · finanzas ·
   coordinador · secretaria`. «Asistente» y «otro» no están. ¿Se agregan al
   enum, o «asistente» se mapea a `secretaria` y «otro» a `coordinador`?
2. **Los departamentos.** Crearlos solos contradice que sean opcionales y
   omitibles («un colegio de 150 alumnos no los tiene»). ¿Se crean siempre, solo
   si dicta bachillerato, o el resumen ofrece quitarlos de un clic?
3. **El correo que ya existe.** Avisarlo al escribir es un oráculo de
   enumeración de toda la plataforma. ¿Se acepta —como ya se aceptó el registro
   abierto— o se avisa recién al enviar?
4. **Cuántos años atrás.** Daniel dijo «por lo menos los cuatro anteriores».
   ¿Cuatro fijos?
5. **Las materias.** Hace falta INVESTIGAR el pensum del MPPE por nivel. Es la
   única pieza que no se puede escribir sin datos de afuera, y la que decide si
   el paso 2 impresiona o miente.

### Lo que NO se toca

El importador por dentro, el aislamiento, `SembrarGrados`, el cálculo de notas y
los documentos del MPPE. Esto es una redistribución de PANTALLAS.

### 2 · El correo se valida MIENTRAS se escribe

> *«Tenemos que validar que el correo no exista. Eso sí es importante. Tiene que
> ser una validación muy rápida. Incluso, no sé si puede: cuando él lo
> transcriba, después que lo transcriba, validamos de una vez allí si el correo
> está correcto y no existe y todo bien.»*

Al salir del campo, no al guardar. Que el error llegue antes de llenar el resto
del formulario.

⚠️ **Esto es un oráculo de enumeración, y hay que decidirlo a conciencia.** Un
endpoint que contesta «ese correo ya existe» permite averiguar, uno por uno, qué
direcciones están registradas en SIGA. `users.email` es único en TODA la
plataforma, así que la respuesta habla de cualquier colegio, no solo del suyo.
`CLAUDE.md § 4` ya acepta el riesgo del registro abierto por la misma lógica
—facilidad por encima de seguridad mientras el acceso sea compartir el enlace a
mano— y esto es la misma decisión un paso más allá. Conviene decirlo, no
descubrirlo.

### 3 · El correo de bienvenida sale AL GUARDAR

> *«De entrada, cuando él guarde el usuario y los primeros datos de la escuela,
> en ese momento ya le debería llegar un correo de que fue registrado en el
> sitio… "dio el primer paso para el cambio en su escuela". Algo así, que rime
> con el eslogan que tenemos en la landing que estamos construyendo.»*

El correo ya existe y ya sale al registrarse (`BienvenidaMailer`, `MOR-206`).
Lo que cambia es el TEXTO: hoy dice «Su cuenta ya está creada. El próximo paso
son los datos de su colegio», y con el registro fundido esa frase deja de ser
cierta.

**El eslogan es:**

> ## El colegio que imaginas, en orden.

⚠️ **Y ordena más que el correo.** «En orden» es exactamente lo que este trabajo
promete: el director no viene a llenar ocho formularios, viene a que su colegio
quede ordenado. Sirve de vara para cada pantalla de acá —si un paso se siente
como trabajo del director y no como orden que aparece, está mal contado— y para
el paso 2, que es literalmente «esto ya quedó en orden».

### 4 · El andamiaje se DEDUCE, no se pregunta

> *«Ya con el tipo de colegio podemos construir los grados. Estaba pensando que
> las materias básicas también las podemos deducir: no hay que pedirle que
> cargue matemáticas, castellano, biología, historia. Hay que buscar en internet,
> en el ministerio de educación, cuáles son las materias elementales. Vuelvo y
> repito: luego lo puede ajustar, pero inicialmente debe ser así. Lapsos
> también.»*

```
   qué dicta el colegio  ──►  los GRADOS        ya existe (SembrarGrados)
                         ──►  las MATERIAS      ← NUEVO, hay que investigar
                         ──►  los LAPSOS        ya existe (nace con el año)
```

- **Grados:** `SembrarGrados` ya hace exactamente esto y es idempotente.
- **Lapsos:** un año escolar ya nace con sus tres lapsos (`MOR-163`).
- **Materias: es lo único nuevo.** ⚠️ Hay que INVESTIGAR el pensum del MPPE por
  nivel —no inventarlo—, y decidir dónde vive ese catálogo. Es el mismo tipo de
  dato que `GradoOficial`: lo fija la ley, es igual en los 3.900 colegios del
  país, y por eso no se le pregunta a nadie.
- ⚠️ Y **el código de cada materia es un invento** cuando no viene de una
  planilla (`§ 3`): un catálogo propuesto tiene que traer códigos propuestos, y
  el colegio corregirlos.

### 5 · El DEA vuelve al registro

> *«Del paso anterior: creo que el DEA sí lo debemos incluir, como para estar
> seguros de que el colegio está registrado. Creo que no es algo que haría tanto
> ruido.»*

⚠️ **Corrige la nota 1**, donde el DEA salía del formulario. Queda adentro.

Y encaja con lo que ya hay: es obligatorio en el modelo, es único en toda la
plataforma, y su pista ya dice que si no lo tiene a mano puede escribir algo
provisional y corregirlo después.

### 6 · Los años escolares también se deducen — y los ANTERIORES

> *«Podemos crear el año escolar, porque nosotros sabemos el día de hoy.
> Entonces sabemos que, si está cerca de septiembre, es porque va a iniciar el
> año escolar: en este caso 2026-2027. Y puedo incluso crear los anteriores, por
> lo menos los cuatro anteriores: 2025-2026, 2024-2025, etc. Y con los años
> anteriores puedo crear también los lapsos. No tengo que preguntarlo, lo puedo
> deducir.»*

⚠️ **Los años PASADOS no son relleno: son lo que hace posible el historial.**
Un colegio que ya venía funcionando sube sus notas de años anteriores (`§ 8` de
la puesta en marcha) y hoy tiene que crear esos años a mano o aceptarlos de a
uno desde la previsualización del importador. Creados de entrada, ese paso deja
de tener fricción.

⚠️ **Hay que fijar la regla del corte, y agosto es el mes traicionero.** Es la
misma trampa que ya apareció tres veces —`Subscription.matricula_de`,
`periodo_en_curso` y `anio_por_defecto`—: en agosto el año más nuevo es el que
todavía no empezó. Con cinco años creados de golpe eso importa más, no menos:
`AcademicPeriod.en_operacion` tiene que seguir devolviendo el que TIENE alumnos.

⚠️ Y hay que decidir las FECHAS. `AcademicPeriod` tiene `start_date` y
`end_date`; el año escolar venezolano va de mediados de septiembre a mediados de
julio, pero eso es una convención, no una ley — el colegio tiene que poder
corregirlo.

### 7 · Un paso crea todo, y el paso 2 es un RESUMEN, no un formulario

> *«Fíjate que con un solo paso ya yo creé la escuela, el andamiaje y todas las
> cosas que se necesitan. Un paso, que es el registro. El paso 2, que no lo ven,
> pero sí se debería decir: "Se ha construido un andamiaje para su escuela, uno
> de los cimientos de su escuela", o algo así, de modo que él sepa qué se creó, o
> se le dé un resumen:*
> - *se crearon los grados para primaria*
> - *se crearon los grados para bachillerato*
> - *se crearon las materias elementales*
>
> *Incluso vamos a hacer los departamentos también, que ellos los modifiquen
> luego si consideran que no están del todo bien.»*

```
   PASO 1   registro          la persona + el colegio          (un formulario)
   PASO 2   «ya está listo»   qué se creó, con sus números     (una pantalla que
                                                                 solo informa)
```

**Lo que el paso 2 tiene que listar** —y con CUÁNTOS, que es lo que lo vuelve
creíble—: los grados por nivel, las materias, los departamentos, los años
escolares y sus lapsos.

⚠️ **Es una pantalla que no pide nada, y ese es su valor.** El plan de ocho
pasos era una lista de tareas pendientes; esto es lo contrario: la prueba de que
el sistema ya hizo el trabajo. Pero **tiene que ser honesta** — si dice «se
crearon las materias» y son las de primaria cuando el colegio también dicta
bachillerato, se pierde justo la confianza que vino a construir.

⚠️ **Y cada cosa listada necesita su salida a editar.** Daniel lo dice dos
veces: *«luego lo puede ajustar»*, *«que ellos los modifiquen»*. Un resumen sin
enlaces convierte «se creó esto por usted» en «alguien decidió esto por usted».

⚠️ **Cuidado con los departamentos.** Hoy son OPCIONALES y se pueden omitir
para siempre —*«un colegio de 150 alumnos no tiene departamentos»*—. Crearlos
solos contradice eso: hay que decidir si se crean siempre, si dependen del nivel
(un colegio de solo preescolar no los necesita), o si el resumen ofrece
quitarlos de un clic.

### 8 · Y entonces, ¿qué queda del plan de ocho pasos?

Con 1 y 2 arriba, de los ocho pasos actuales quedarían en pie **las secciones**,
**la matrícula**, **quién dicta qué** y **el historial** — o sea lo que SÍ es
del colegio y nadie puede deducir.

⚠️ Anotado como consecuencia, no como decisión: falta que Daniel diga cómo se
presenta lo que sobrevive.

### 9 · La migración inicial: la función está, falta CÓMO se pide

> *«Luego vendría el paso 3 para nosotros, 2 para ellos, que sería la
> importación/migración inicial de la data. La funcionalidad está, pero creo que
> podemos mejorar la manera como la pedimos y ordenarla mejor, al menos en una
> etapa inicial: es decir, cuando no hay contenido cargado de un año escolar o
> período.»*

⚠️ **«3 para nosotros, 2 para ellos» no es un detalle de conteo: es la regla.**
El paso 2 —el resumen del andamiaje— no es trabajo de nadie, así que no debería
gastar un número en la lista que el director ve. Lo que se numera es lo que hay
que HACER.

**Lo que ya está y no se rehace:** el importador de las tres planillas
(`§ 3`), con su previsualización, su distinción entre ERROR y AVISO, el
`SAVEPOINT` por fila y las plantillas descargables. Lo que se rediseña es la
PUERTA.

⚠️ **La clave es «cuando no hay contenido cargado».** Un colegio vacío y uno
que ya viene usando SIGA no necesitan la misma pantalla: al primero hay que
llevarlo de la mano por las tres planillas en orden; al segundo, dejarlo subir
la que vino a subir. Hoy `/importaciones` es la misma para los dos.

**El orden ya está escrito** en el estado vacío de esa pantalla —*«las materias
con sus profesores (de ahí salen también las secciones), después la matrícula
con alumnos y representantes, y por último las notas de años anteriores»*— pero
vive como un párrafo, no como una secuencia que se pueda seguir.

⚠️ Y ese orden **se contradice con el de la puesta en marcha desde `MOR-197`**:
allá las secciones van DESPUÉS del año escolar y de las materias. Al armar el
plan hay que dejar UNA sola secuencia, no dos.

