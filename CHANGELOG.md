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

## 1.20.5 — 14 de octubre de 2026

- **En una tableta, las listas anchas ya no corren la pantalla de lado.**
  Administradores, profesores, representantes, la auditoría y las
  importaciones: la tabla se desliza dentro de su recuadro, como en el
  teléfono.
- **El formulario de competencias tiene sus botones en fila,** como el resto.
- **Tres avisos del plan de evaluación ya hablan de usted:** se le habían
  escapado a la 1.20.2.

---

## 1.20.4 — 14 de octubre de 2026

- **El mínimo de la suscripción baja a 39 $ al mes.** Lo paga el colegio de
  hasta 111 alumnos; desde ahí, cada alumno suma 0,35 $, con el IVA adentro.
  El contrato, «Aliados» y «Qué hace hoy» ya lo dicen.

---

## 1.20.3 — 14 de octubre de 2026

- **El botón «Buscar» de la barra de arriba se ve.** Tenía letra blanca sobre
  fondo blanco: funcionaba, pero no se veía. Ahora se ve en todas las pantallas,
  con su atajo ⌘K.
- **En una laptop o una tableta, la pantalla ya no se corre de lado.** Entre
  los anchos de un teléfono y de una pantalla grande, la barra de arriba era más
  ancha que la ventana. Ahora va guardando lo que menos se extraña —el municipio
  del colegio, la palabra «Cerrar sesión», el nombre de quien entró— hasta que
  cabe. Lo que queda en su icono dice qué es al pasar el ratón.

---

## 1.20.2 — 13 de octubre de 2026

- **SIGA le habla de usted en todas sus pantallas.** Quedaban un centenar de
  textos que tuteaban —«Elige un alumno», «No tienes permiso», los avisos al
  iniciar sesión, el título de la portada— y ahora todos dicen «Elija», «No
  tiene permiso», «Inicie sesión»: al director, a la secretaria, al profesor y
  a la familia por igual.

---

## 1.20.1 — 13 de octubre de 2026

- **«Evaluaciones» es un mapa del colegio.** Una tabla por nivel, con una fila
  por sección y una casilla por área: ✓ si su plan cerró en 100 %, el
  porcentaje si va a medias y un punto si no tiene evaluaciones. Se mira un
  lapso a la vez —abre en el que está corriendo— y cada casilla lleva al plan
  de esa sección. Antes era una barra por cada sección, área y lapso, de todos
  los años escolares juntos.

---

## 1.20.0 — 13 de octubre de 2026

- **La constancia y el boletín de un alumno, a un clic desde su ficha.** El
  botón «Constancia» emite y descarga la de ese alumno, sin ir a buscarlo en su
  sección. Y la tarjeta «Documentos oficiales» trae la constancia de estudio y
  el boletín de cada lapso —y el anual—, además del papel del ministerio que le
  toca por su grado.
- **«Documentos oficiales» en cada sección.** Un botón del encabezado lleva a
  «Documentos» con esa sección ya elegida, y sigue elegida al pasar de los
  boletines a las constancias o a los certificados.
- **«Áreas y profesores» es una pestaña de la sección**, después de
  «Alumnos», y dice también qué área del grado no tiene profesor todavía. Era
  una tabla al final de la lista de alumnos.
- **Una sección nueva se agrega desde su grado, con dos datos:** el
  identificador —SIGA propone la letra que sigue— y el profesor guía. Y el
  grado muestra solo las secciones del año escolar que se está mirando.
- Al editar una inscripción, la sección se elige entre las de su mismo grado y
  año: editarla es cambiar de sección o retirar. Para pasar a otro grado, se
  retira y se inscribe de nuevo.
- Crear una sección sin abrir «Guía, cupo y aula» ya no da error: el cupo nace
  en 30, y se corrige cuando se ve la matrícula.
- En la portada, las tres cifras ya no dejan un hueco gris en las pantallas
  medianas.

---

## 1.19.1 — 13 de octubre de 2026

- **El WhatsApp de SIGA, fijo en la esquina de la portada.** Además de los
  botones de arriba y del cierre, un botón verde abajo a la derecha, que no se
  pierde al bajar.

---

## 1.19.0 — 13 de octubre de 2026

- **La suscripción también se paga por PayPal.** «Suscripción» muestra el
  correo al que se paga, y el reporte del pago lo ofrece junto con Pago Móvil o
  transferencia, Binance y efectivo. Como Binance, va en dólares, con el número
  de la transacción y su comprobante.

---

## 1.18.1 — 12 de octubre de 2026

- El WhatsApp de SIGA y la dirección del colegio de muestra se cambian desde el
  panel del equipo de SIGA, sin tocar el servidor. Para el colegio no cambia
  nada: el botón de WhatsApp y el de «Vea un colegio funcionando» llevan a
  donde llevaban.

---

## 1.18.0 — 12 de octubre de 2026

- **SIGA avisa antes de que la suscripción venza, y no hay que estar pendiente.**
  El colegio recibe tres correos, cada uno una sola vez, y lee lo mismo arriba
  de su pantalla:

  ```
     5 días antes      «su suscripción vence el 9 de noviembre»     todo funciona
     el día que vence  «venció: todo sigue funcionando 15 días»     todo funciona
     pasados 15 días   «su colegio quedó en solo lectura»           ve y descarga todo
  ```

  Le llegan a la dirección y a finanzas, que son quienes pagan.

- **Nada se pierde en ningún momento.** En solo lectura el colegio sigue
  entrando, consultando y emitiendo boletines y constancias; lo que queda en
  pausa es calificar, pasar lista y cargar información nueva. Al validarse el
  pago vuelve todo, y los días en solo lectura no se cobran.

- **A quien ya reportó su pago no se le reclama nada:** mientras el reporte
  espera validación, el colegio no baja de estado ni recibe avisos.

## 1.17.0 — 12 de octubre de 2026

- **La portada invita a registrar el colegio.** El botón principal ya no pide
  agendar una demostración: lleva al registro, que es por donde un colegio
  entra y empieza a cargar, gratis. Al lado van dos más:

  ```
     [Registre su colegio →]   [Escríbanos por WhatsApp]   [Vea un colegio funcionando ↗]
  ```

- **El registro dice el precio antes de pedir un dato:** cargar el colegio es
  gratis y no vence; calificar, pasar lista y emitir cuestan 0,35 $ por alumno
  al mes. Nadie se entera después, al tocar «Calificar».

- **El WhatsApp de SIGA está también en la portada y en el registro,** además de
  «Suscripción». Es el número que el equipo de SIGA tiene cargado; si no hay
  ninguno, el botón no se dibuja.

- **El formulario de «pedir una demostración» ya no existe.** Quien abra su
  dirección —desde un buscador o un mensaje viejo— llega a la portada.

## 1.16.0 — 12 de octubre de 2026

- **Hay un colegio de muestra para ver SIGA funcionando antes de registrarse:**
  `demo.sigaeducando.com`. Es un colegio inventado y completo —de preescolar a
  sexto año, con sus notas, sus boletines, su asistencia y su cobranza—, y se
  entra con un clic, sin crear una cuenta:

  ```
     [Entrar como director]   [Entrar como profesor]   [Entrar como representante]
  ```

  Se puede tocar y cambiar lo que se quiera: cada noche vuelve a su estado
  inicial. Desde ahí no sale ningún correo, y no hay nadie real adentro.

- **El colegio de muestra tiene la fecha de hoy.** El año pasado está completo y
  cerrado; el que corre, calificado y con la asistencia hasta ayer. No es una
  foto: en enero tendrá su primer lapso cerrado, con sus boletines.

- **En el portal de la familia, Educación Inicial ya se lee.** La maestra de
  Inicial no pone notas: describe. La familia leía «Pendiente» en cada área
  aunque la valoración estuviera escrita; ahora lee lo que la maestra escribió,
  y la pantalla dice «Valoraciones» y no «Calificaciones».

- **La familia encuentra los boletines de los años anteriores.** Se listaban
  solo los del año que corre, así que entre septiembre y diciembre la lista
  estaba vacía. Ahora están todos los que el colegio liberó, con su año al lado.

- El aviso de una falta sin justificar, en el portal, trataba de tú. Ya trata
  de usted, como el resto de lo que lee una familia.

## 1.15.0 — 12 de octubre de 2026

- **La suscripción se paga desde SIGA, sin llamar a nadie.** En el menú de la
  dirección y de finanzas hay una pantalla nueva, «Suscripción», que dice en qué
  está el colegio, cuánto le toca este mes —con su matrícula de hoy— y cómo
  pagar: Pago Móvil o transferencia en bolívares a la tasa BCV del día, Binance
  (USDT) o efectivo en dólares.

  ```
     «Suscripción»  ──►  Reportar el pago  ──►  SIGA lo valida  ──►  activa por un mes
  ```

- **El colegio reporta su pago** con el medio, el monto, la referencia, la fecha
  y la foto del comprobante. Queda «en revisión», y al validarse se activan
  calificar, pasar lista y emitir, en el momento. Si no se puede validar, el
  colegio lee por qué en esa misma pantalla y en su correo, y lo reporta de
  nuevo.
- **Al validarse el pago llega un correo** que dice hasta cuándo queda activa.
- **Donde antes decía «se activa con la suscripción», ahora hay un enlace** que
  lleva a esa pantalla: en el aviso de arriba y al tocar algo que la pide.
- **Pagar tarde no regala días, ni cuesta de más.** El mes cuenta desde el día
  en que vencía si el pago se reporta a tiempo o dentro de los 15 días de
  gracia, y desde que se valida si el colegio ya estaba en solo lectura.
  Mientras un pago espera validación, el colegio no baja de estado.
- **Cinco días antes de vencer**, la dirección y finanzas ven el aviso con la
  fecha.
- El botón de WhatsApp ahora lleva al número que SIGA tiene cargado, y aparece
  también en «Suscripción».

---

## 1.14.0 — 12 de octubre de 2026

- **SIGA se paga por alumno: 0,35 $ al mes por alumno inscrito, con un mínimo
  de 45 $.** Se acaban los tres planes y el salto del alumno 151, que duplicaba
  la factura: cada alumno cuesta lo mismo, y todos los colegios tienen el
  sistema completo. El precio es final: no se le suma nada.

  ```
     alumnos       100      150      250      360      800
     al mes         45    52,50    87,50      126      280     dólares
  ```

- **Cargar el colegio sigue siendo gratis**, sin tope y sin fecha: alumnos,
  familias, profesores, áreas, secciones, el plan de evaluación y el importador.
  Todo lo demás se activa con la suscripción: calificar, pasar lista, cerrar el
  lapso, las reparaciones, los informes, la cobranza, los correos a las familias,
  los documentos y las listas en Excel, y los portales de la familia y del
  alumno.
- **Al tocar algo que pide la suscripción, la dirección ve cuánto le cuesta** a
  su colegio. El profesor, la familia y el alumno ven que esa parte todavía no
  está activa, sin precios.
- **Todo colegio empieza en gratis**, también el que da de alta el equipo de
  SIGA.

---

## 1.13.0 — 5 de octubre de 2026

- **Cambian los precios de la suscripción.** Los tramos de matrícula son los
  mismos, y entre planes sigue sin recortarse ninguna función:

  ```
     Inicial     hasta 150 alumnos     39 $ al mes     (antes 30)
     Estándar    hasta 400 alumnos     79 $ al mes     (antes 60)
     Grande      hasta 800 alumnos    119 $ al mes     (antes 90)
  ```

---

## 1.12.0 — 5 de octubre de 2026

- **Los correos de SIGA ahora se ven como del colegio.** Llevan su escudo, su
  nombre y sus datos arriba —como un boletín— y cómo ubicarlo al pie. Antes
  llegaban como texto suelto, sin nada que dijera de quién eran.
- **El remitente dice quién escribe**: «U.E. Simón Bolívar · SIGA», y no una
  dirección de correo.
- El correo para recuperar la contraseña sale con el escudo del colegio cuando
  la persona es de uno solo; con hijos en dos colegios, sale a nombre de SIGA.
- Todos los correos se leen también en los programas que no muestran diseño, y
  el enlace del pie —«Administrar avisos»— está en español.
- En el aviso del boletín decía «El 1er Lapso de Daniela ya está listo»; ahora
  dice «El boletín del 1er Lapso de Daniela».

---

## 1.11.3 — 5 de octubre de 2026

- Arreglado: **el equipo de SIGA vuelve a enterarse cuando un colegio nuevo se
  registra.** El aviso había dejado de salir el 2 de septiembre; para el colegio
  no cambia nada.

---

## 1.11.2 — 5 de octubre de 2026

- **«Materia» pasó a «Área de aprendizaje» en todo el sistema**: las pantallas,
  los avisos, la puesta en marcha, el buscador y lo que el importador muestra.
  Es la palabra con la que el colegio llena las planillas del ministerio, y ya
  estaba en el menú y en el boletín.
- Las plantillas de Excel del importador no cambian: sus columnas se siguen
  llamando «MATERIA» y «CÓDIGO DE LA MATERIA», así que la planilla que un
  colegio ya tenga llenada sirve igual.

---

## 1.11.1 — 5 de octubre de 2026

- Arreglado: **«Descargar las listas» fallaba en todo colegio con escudo
  cargado**, tanto la de una sección como la del colegio entero. Ahora bajan, y
  llevan el escudo arriba a la izquierda, que era la idea y nunca había salido.

---

## 1.11.0 — 5 de octubre de 2026

- **Los certificados están ahora en «Documentos»**, en una pestaña propia al lado
  de Boletines y Constancias. Ya existían, pero había que abrir la ficha de cada
  alumno y bajar hasta la última tarjeta para encontrarlos.
- **Se emiten de un alumno o de toda la sección**, en un solo PDF con una página
  por alumno, listo para mandar a imprimir. El grado decide cuál papel le toca
  —certificado, constancia de prosecución o la 31059— y la pantalla lo dice antes
  de emitir.
- **Quien repite no sale con «toda la sección» en primaria**, porque su papel
  diría «promovido». La pantalla dice quién quedó fuera y por qué, y eligiéndolo
  en la lista se le emite igual.
- **La pantalla avisa antes** si algún alumno no tiene calificación definitiva:
  su literal sale como una línea para llenar a mano.
- Arreglado: **el documento de Educación Inicial fallaba** al pedirlo desde la
  ficha del alumno cuando el colegio tenía a su director cargado.
- Arreglado: **la certificación 31059 salía sin el año en la fecha de
  expedición** cuando el nombre del municipio era largo — en Caracas, siempre.
  Ahora un dato que no cabe en su casilla se achica antes que cortarse.
- **El boletín de bachillerato cabe en una hoja.** Eran dos: las notas en una y
  la «situación con respecto a la sección» en otra, que repetía cada materia con
  su nota. Ahora es una sola tabla —la nota, el promedio de la sección y la
  barra, en el mismo renglón— y el colegio imprime la mitad del papel.
- En ese boletín, la comparación con la sección va **aparte de las notas, más
  angosta y rayada en vez de rellena**: es un complemento, y se imprime con la
  quinta parte de la tinta. Y su columna dice «Promedio de la sección», que es
  lo que es; decía «Sección».
- **El boletín ocupa las hojas justas.** La firma y el código de verificación ya
  no se cortan contra el borde ni quedan solos arriba de una hoja en blanco: si
  no caben, pasan a la siguiente junto con parte de las notas. Y cuando por unas
  pocas líneas el boletín se iba a una hoja más, las filas se aprietan un poco
  para que quepa.
- **Emitir los boletines de una sección tarda dos segundos**, no medio minuto.
- En el boletín, los datos del alumno van en un renglón, y la asistencia y el
  puesto en otro. El nombre del colegio sube al lado del escudo.
- En el boletín anual, «Sin nota» ya no se parte en dos renglones: cada fila
  medía el doble de lo necesario.
- En la boleta de primaria, las competencias y los indicadores salen con letra
  más chica que la materia y sangrados debajo de ella, como estaban pensados.
  Salían todos del mismo tamaño y alineados al mismo borde.
- El manual decía que los certificados se emitían desde la pestaña «Alumnos» de
  la sección. Ahora dice dónde están.

---

## 1.10.1 — 24 de septiembre de 2026

- **El nombre de la evaluación ya no se come la fila.** En un monitor grande
  crecía sin tope para un texto de cuatro palabras, mientras el deslizador del
  peso se quedaba corto. Ahora el nombre llega hasta la mitad de la fila y lo
  que sobra se lo lleva el deslizador, que es el único que mejora con el largo:
  poner un 40 exacto pasó de 1,3 puntos por píxel a casi tres píxeles por punto.

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
