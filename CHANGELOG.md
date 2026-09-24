# Qué cambió, y qué significa para un colegio

Los números son SemVer con los significados puestos **desde el colegio**, no
desde una API: de SIGA no depende nadie, hay una sola versión corriendo y todos
los colegios la tienen. Ver `Siga::VERSION` en `config/application.rb`.

```
   MAYOR    cambia CÓMO TRABAJA el colegio    hay que avisarle y enseñarle
   MENOR    una función nueva                  se cuenta acá
   PARCHE   un arreglo o un ajuste             nadie tiene que enterarse
```

⚠️ **El número comunica.** Daniel, 18 de septiembre: *«lo que quiero con estas
versiones es que se genere confianza; un producto en 0.algo se ve como una
beta»*. SIGA no lo es: opera un año escolar completo, con los documentos del
ministerio, desde hace semanas. Por eso el **salto de 0.10 a 1.5**, que es
deliberado y no esconde versiones que falten — nunca existieron la 1.0 ni la
1.4, y esta lista no las inventa.

⚠️ Y esta lista se escribe para quien usa SIGA, no para quien lo programa: si
una entrada no se puede explicar sin nombrar un archivo, no va acá — va en el
mensaje del commit, que es donde vive el detalle técnico.

---

## 1.10.0 — 24 de septiembre de 2026

- **El botón de borrar una evaluación se apaga cuando tiene notas**, y dice
  cuántas lo impiden. Antes se podía tocar, la app lo rechazaba, y el error
  aparecía arriba de la pantalla — lejos de la fila que lo produjo.
- **Cuántas notas tiene cada evaluación se ve mejor**: una pastilla con su
  icono y su color, en vez de un número al margen que se perdía entre el peso
  y la fecha.
- **Al borrar una evaluación se borran sus indicadores**, y el aviso lo dice
  antes. Quedaban sueltos: sin salir en la boleta y sin verse en el plan.
- **Traer el plan del año pasado de otro profesor ya no trae indicadores.** Sin
  las evaluaciones que los midan no tienen dónde vivir; vienen las competencias,
  que son las que describen qué enseña el grado.
- **Agregar una evaluación se ve igual que editarla.** Eran dos pantallas
  distintas para lo mismo: un panel aparte con sus campos, y en el plan una
  fila que se edita en su sitio. Ahora al tocar «Agregar evaluación» aparece
  la misma fila —nombre, peso y fecha en una línea— con el borde punteado de
  lo que todavía no está guardado, un ✓ verde para crearla y una ✗ donde va el
  basurero de las demás.
- **Los indicadores se escriben en un solo lugar.** Al crear una evaluación se
  pedían en un bloque de texto, uno por línea; al editarla, uno por campo. Se
  quedó la segunda: la evaluación nace con su nombre y su peso, y los
  indicadores se agregan sobre ella, en su bloque «Indicadores que mide».
- **Competencias, Evaluaciones e Indicadores se leen más**: los tres rótulos
  del plan ganaron peso y una línea que los separa de lo que cuelga de ellos.
- **El peso se puede deslizar.** Al lado del número hay ahora una barrita con
  su punto: se arrastra y el porcentaje cambia con ella, con la barra de
  ponderación moviéndose al mismo tiempo. El número sigue estando para escribir uno exacto,
  y es el único que queda en el teléfono — sesenta píxeles con el dedo encima no
  alcanzan para poner un 40.
- **Lo que aparece y lo que se va ya no dan un salto**: la fila nueva, el panel
  de la competencia y el indicador recién escrito entran con un desvanecido, y
  lo que se borra se apaga antes de irse.
- Arreglada la **intermitencia del login en las pruebas**, que hacía fallar
  pruebas que no hablaban de login. No afecta a la aplicación.

## 1.9.1 — 22 de septiembre de 2026

- **Cada evaluación dice cuántas notas tiene**, de cuántos alumnos: «notas 18 de
  21», en verde si están todas, ámbar si faltan y rojo si no hay ninguna. Antes
  eso solo se sabía intentando borrar la evaluación y leyendo el error de que no
  se podía. Es el mismo lenguaje de la libreta y del menú.
- **La competencia nueva se agrega al final del plan**, no en el medio. Nacía
  sin número de orden, así que caía entre las primeras.

## 1.9.0 — 21 de septiembre de 2026

**El plan de evaluación se reordenó**, después de verlo en uso: primero el
componente, dentro sus evaluaciones, y dentro de cada evaluación los
indicadores que mide. Cada nivel en su propio contenedor.

```
   ┌ Resuelve problemas de adición ──────────────────┐
   │   EVALUACIONES                                  │
   │   ┌ Examen                    40 %   5 nov ─┐   │
   │   │   INDICADORES QUE MIDE                  │   │
   │   │     · Suma con reagrupación             │   │
   │   │     · escribe un indicador…             │   │
   │   └─────────────────────────────────────────┘   │
   └─────────────────────────────────────────────────┘
```

- **Un indicador nuevo nace midiendo su evaluación.** Antes quedaba colgado
  solo del componente, o sea sin salir en la boleta y sin verse en el plan.
- **Se retiró el menú que ofrecía competencias ajenas.** Bajo una evaluación de
  «Reconoce figuras geométricas» ofrecía engancharle «Resuelve problemas de
  adición»: contradecía lo que la pantalla enseña.
- **Los indicadores ya no se escriben desde el formulario del componente.** Un
  segundo lugar donde escribirlos era un segundo lugar donde perderlos.
- **Borrar una evaluación no borra sus indicadores**, y el aviso lo dice: quedan
  listados en ámbar dentro de su componente, para copiarlos o borrarlos.
- La pestaña se llama **«Plan de Evaluación»**, no «Planificar».

## 1.8.0 — 19 de septiembre de 2026

- **El informe descriptivo es obligatorio para cerrar el lapso.** Salió como un
  aviso y Daniel lo cerró: una boleta sin una línea del docente es una factura
  — el «PA» dice en qué banda cayó el niño, y el informe dice que lee mejor que
  en octubre. La pantalla dice **cuáles alumnos** están sin informe y lleva
  directo a escribirlos.
- Cuando las notas ya están completas, el aviso **habla de los informes y no de
  las notas**: mandar a buscar algo que ya está hecho es peor que no decir nada.

## 1.7.0 — 19 de septiembre de 2026

**Control de Estudio cierra el lapso.** Las notas de un lapso nunca terminaban
de estar terminadas: se podían cambiar en marzo y el boletín que la familia
descargó en diciembre decía otra cosa. Y del otro lado, la familia se enteraba
por WhatsApp de que había notas.

```
   POR CALIFICAR   falta alguna nota            ──►
   CALIFICADA      están todas                  ──►
   CERRADA         Control de Estudio dio el visto bueno
```

- **Un lapso solo se cierra con el 100 % cargado.** Antes se podían liberar los
  boletines emitidos aunque a otros alumnos les faltaran materias. La pantalla
  **dice quiénes faltan y cuántas materias**, para poder perseguirlos por
  nombre en vez de buscarlos uno por uno.
- **Al cerrar pasan cuatro cosas de una vez:** se emiten los boletines que
  falten, las familias los ven, a cada una le llega su correo, y el profesor
  deja de poder cambiar las notas de ese lapso.
- **El profesor lo sabe antes de escribir.** La planilla de notas de un lapso
  cerrado se lee pero no se escribe, y lo dice arriba — no nota por nota.
- **Se puede reabrir.** Un error se descubre después de cerrar, y sin esa puerta
  la única salida sería llamar a soporte. ⚠️ Lo que no se deshace es el correo
  que ya salió, y el aviso lo advierte antes.
- **El informe descriptivo avisa, no impide.** Quien cierra ve cuántos alumnos
  salen sin una línea del docente, con el enlace para escribirlos — pero el
  informe sigue siendo opcional.
- Un **alumno retirado ya no bloquea** el cierre: no tiene notas, nunca las va a
  tener, y tampoco se le emite boletín.

## 1.6.0 — 18 de septiembre de 2026

- **El informe descriptivo es una pestaña de la sección**, al lado de
  Asistencia, Calificar y Planificar. Estaba detrás de un botón en la esquina de
  «Calificar», donde se lee como una acción sobre lo que la pantalla muestra —
  y no lo es: es otro sitio donde trabajar, en el mismo lapso y la misma
  sección. Lo pidió Cyndi en la prueba de campo.
- La pestaña aparece **para el guía y para la dirección**, que son quienes lo
  escriben. Un profesor que solo dicta un área no la ve: ofrecerla y después
  negarla enseña a desconfiar del menú.

## 1.5.0 — 18 de septiembre de 2026

**El colegio ya puede cobrar.** Era lo único de la tabla de entrada que los tres
competidores tienen y SIGA no: la suscripción sabía si el colegio estaba al día,
pero no había nada que cobrara. Ahora la familia reporta su pago, la oficina lo
valida, y la deuda tiene consecuencia.

Y dos cosas más que estaban a medias: la boleta pasa por un vistazo antes de
llegar a la casa, y el plan de primaria dice **qué indicador** midió cada
evaluación.

⚠️ **El número saltó de 0.10 a 1.5**, y es a propósito. No falta ninguna
versión: la 1.0 y la 1.4 nunca existieron. Lo que había era un producto
terminado escondido detrás de un número que decía «beta».

### Cobrarle a las familias

- **La familia reporta su pago** desde su portal: monto, referencia, fecha y la
  foto del comprobante. La oficina lo ve en su bandeja y lo **valida o lo
  rechaza**, con el motivo.
- **La deuda con el colegio es UNA.** Una madre con tres hijos ve un solo saldo
  y **un pago cubre a varios**: el recibo del banco es uno, y pedirle tres
  reportes por la misma transferencia es hacerle el trabajo del colegio.
- **El que debe no ve las notas** —ni la familia ni el alumno—, con cinco días
  de gracia y una pantalla que explica qué hacer. El bloqueo es **por
  inscripción**: el hijo que está al día no paga por el hermano que no.
- **Un reporte se puede corregir**, y no solo desde la oficina: mientras esté en
  revisión, la familia arregla la referencia que tecleó mal.
- **Un rechazo por error se deshace.** Rechazar y volver a validar deja todo
  como estaba — antes, rechazar una vez cerraba la puerta.
- **Validar sin abrir el comprobante**, desde la bandeja, y deshacerlo ahí
  mismo. Cincuenta pagos un lunes por la mañana no son cincuenta pantallas.
- **La lista de representados dice cuál está atrasado**, y la de morosos lleva
  al detalle del deudor con un clic.
- **El colegio dice lo que cobra**: matrícula, mensualidades y cuotas del año,
  en una pantalla.
- **Tres maneras de mostrar un monto, y cada una es distinta.** La deuda va en
  dólares, la transferencia en bolívares, y el reporte de la familia **sin
  unidad**: SIGA no guarda tasa de cambio, y **validar el pago ES el acto de
  cambio** — ponerle una moneda a lo que la familia escribe sería inventar una
  conversión que nadie hizo.
- **El comprobante se encoge al subirlo.** Una foto de teléfono pesa tres megas;
  la que se guarda, ochenta kilos.

### El plan de evaluación de primaria

- **Una evaluación dice qué indicadores mide**, no solo qué competencia. Y **un
  indicador no se repite entre evaluaciones**: la competencia se repite, los
  indicadores la reparten — el examen mide «suma con reagrupación» y el taller,
  «estima antes de calcular».
- Al crear una evaluación se **marcan los indicadores que ya están escritos** y
  se pueden **agregar otros ahí mismo**, sin salir del plan. Los nuevos quedan
  en la competencia para las próximas.
- **En la boleta, cada indicador sale con su propio nivel** —el de la evaluación
  que lo midió—, y salen solo los que se midieron. La competencia conserva el
  suyo, que es el ponderado de sus evaluaciones.
- **Traer el plan del año pasado trae las evaluaciones solo si lo dictaba el
  mismo profesor.** El peso de un examen y su fecha son una decisión de quien
  evalúa; las competencias sí se heredan, porque describen qué enseña el grado.

### Los documentos

- **La boleta pasa por un vistazo final** antes de que la vea la familia: se
  revisa el lapso completo y se libera. Antes salía sola.
- **El verificador comprueba constancias**, no solo boletines, y muestra el
  informe descriptivo.
- **En bachillerato la nota es el número**, sin la rúbrica: los niveles
  —«PA», «PC»— son de primaria, porque una familia de primaria no lee un 17,
  lee «va bien».

### Quién puede qué

- **Tres grupos de administración**, en una sola tabla: dirección, académico y
  finanzas. Quien lleva el dinero no ve el registro de actividad ni importa
  datos; quien coordina no crea usuarios.
- Al registrar un colegio hay **dos cargos y no tres**: director o directora, y
  otro cargo. Con tres, quien elegía el del medio quedaba **encerrada en su
  propio colegio**, sin poder crear ni siquiera al director.

### Que te encuentren

- **Directorio público de los 13.434 planteles** del país, por estado y
  municipio, con la ficha de cada uno. Son 13.434 páginas que traen a un
  director buscando el nombre de su colegio.
- **El manual completo vive en el servidor**, con su PDF de 72 páginas para
  descargar. Un enlace que se comparte, no un archivo que se manda.

## 0.9.0 — 12 de septiembre de 2026

La primera versión numerada. Todo lo que hace falta para **operar un año escolar
completo** ya está; lo que falta es limpiar producción y que un colegio entre.

### Armar el colegio

- Registro en **una sola pantalla**: quedan su cuenta y su colegio, con los
  grados, las áreas del plan de estudio y los años escolares ya creados.
- El nombre del colegio se **autocompleta desde el catálogo del ministerio**
  —15.954 planteles— y trae su código DEA, su estado y su municipio. Es una
  sugerencia: todo se puede corregir.
- Estado, municipio y parroquia salen de la **división política oficial del
  INE** (334 municipios, 1.123 parroquias).
- Los **quince grados los fija la ley**: se marcan los niveles y quedan
  sembrados, con su nombre y su orden.
- **Puesta en marcha de ocho pasos** que se miran solos: la lista no guarda
  «paso 4 completado», lee lo que hay cargado. Cargar las materias por el menú
  pone el paso en verde sin que nadie lo marque.

### La gente

- Alumnos, representantes, profesores y administradores, cada uno con su ficha,
  su foto y su documento.
- **Un alumno no necesita correo**: un niño de ocho años es un registro, no una
  cuenta. Quién sí lo necesita lo decide el rol.
- **Activar el acceso** con un código de un solo uso, que se ve una vez y dura
  72 horas.
- El colegio le escribe a la familia desde la ficha del representante, por
  **correo** (queda en la auditoría) o por **WhatsApp** (solo si el número es
  móvil).

### Traer lo que ya existe

- **Importar tres planillas**: matrícula, pensum e historial. Se sube el archivo
  o **se pega la lista** desde Excel.
- Nada se crea sin que usted vea antes la cuenta, y cada fila va en su propio
  punto de guardado: la fila 200 de 360 no se lleva las 359 buenas.
- **Clonar el año**: las secciones con su cupo, su aula, su guía y quién dicta
  qué. Los alumnos no — eso es promover.
- **Promover**: se lee la nota definitiva de cada alumno y se propone dónde
  queda. «Sin nota cargada» es el caso normal del colegio que estrena SIGA.

### El profesor

- **Asistencia** de un toque por alumno, pensada para el teléfono.
- **Planificar** el lapso con la barra de ponderación que se mueve sola y
  propone lo que falta para cerrar en 100.
- **Competencias e indicadores** que se escriben una vez y se copian a las
  secciones hermanas, o se **traen del año pasado** con sus evaluaciones y la
  fecha corrida al año actual.
- **Cargar notas sin botón de guardar**: cada nota se guarda al salir del campo,
  y si se cae la conexión lo escrito espera y se reintenta solo.
- **Educación Inicial** no lleva números: lleva la valoración escrita de cada
  área, y se guarda igual de sola.
- **Informes descriptivos** por alumno, que salen al final de la boleta.
- La **ficha corta del alumno**: a quién llamar y por dónde.

### Las notas, como las manda la ley

- **Artículo 108**: la calificación es un entero del 1 al 20, y el 0,50 sube.
- **Artículo 111**: el anual es el promedio simple de los lapsos. Un lapso **no
  tiene peso**.
- **Artículo 112**: la reparación es **una sola nota** y es la definitiva.
- **«Sin nota» no es cero**, y se sostiene en las tres capas: el cálculo
  devuelve nada, la planilla borra la fila y la pantalla del alumno escribe
  «Pendiente» en letras.
- Una calificación **importada** no la recalcula ni la borra nadie: sus
  evaluaciones están en papel.

### Los documentos

- **Boletines**, que quedan congelados con las notas tal como se imprimieron y
  con su código de verificación.
- **Constancias de estudio**, que salen con la situación de hoy y por eso **no**
  se guardan.
- Del ministerio: **Certificación 31059**, **Certificado de Educación
  Primaria**, **Constancia de prosecución**, **Certificación de Educación
  Inicial**, **prosecución entre grupos** y el **Resumen Final del
  Rendimiento** — este último en PDF y en Excel editable, con en ámbar lo que
  el colegio llena a mano.
- **Listas de la sección en Excel**, con el escudo, el encabezado y el efecto
  cebra, listas para imprimir y firmar.
- La **rúbrica**: en primaria la familia no lee un 17, lee un nivel — y el
  colegio decide con qué palabras.

### La familia

- **Portal del representante**: sus representados y sus notas, con selector de
  colegio cuando tiene hijos en más de uno.
- **Portal del alumno**, para el que tenga correo.

### Por dentro, y se nota

- **Aislamiento por colegio en dos capas**: el filtro de la aplicación y las
  políticas de PostgreSQL. Sin contexto se ven **cero** filas, no todas.
- El **año escolar** y el **nivel** se eligen una vez arriba y de ahí cuelga
  todo lo filtrable. El profesor no tiene selector de año, a propósito.
- **Un solo sistema de diseño** para los cuatro roles, con los seis tonos de
  botón según **qué hace** cada uno.
- **Buscar es palabra por palabra y sin acentos**, en las dos capas: «sofia»
  encuentra a Sofía, y «López Guzmán» son dos columnas distintas.
- **Auditoría** de quién hizo qué, cuándo y desde dónde.
- `/salud` dice si la cola avanza; `/up` dice si el proceso arrancó. No son
  intercambiables.
- **El plan Inicial es gratis y el límite es por función**, no por número de
  alumnos: la importación nunca se rompe a mitad de camino.
- **SEO**: `robots.txt`, `sitemap.xml`, canonical sin query string, `noindex`
  donde hace falta y la ficha estructurada del producto.
