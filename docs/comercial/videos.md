# Los dos videos de 30 segundos

Daniel, 14 de octubre de 2026: *«necesitamos crear un video con Notebook…
ponlo con prioridad 1»*, y después: *«los 2, deben ser de 30 segundos cada
uno»*. Reemplazan a los de septiembre —«Siga 01 - Principal» y «Siga 02 -
Roles»—, que mostraban las bandas de 30/60/90 $ y la portada vieja.

```
   VIDEO          PARA QUIÉN                                  CIERRA CON
   1 · Principal  el director que lleva las notas en Excel    demo.sigaeducando.com
   2 · Roles      el mismo director, que quiere ver más:      demo.sigaeducando.com
                  qué ve la dirección, el profesor y la familia
```

Se hacen en NotebookLM, a mano. Instalar un MCP se descartó (decisión 1 del 14
de octubre): Google no tiene uno oficial, y los que hay usan accesos que
Google no documenta y pueden dejar de funcionar cualquier día.

## ⚠️ Sin precios, a propósito

Un video vive meses. Los de septiembre siguieron circulando con tres precios
viejos encima, y el precio de SIGA es un número que cambia en `Subscription`.
El video dice lo que no vence: qué hace SIGA, que cargar el colegio es gratis,
y dónde verlo funcionando. El precio lo dicen la portada, el registro y
«Suscripción».

`documentos_comerciales_test` lo cuida. Exige que cada guion no tenga montos,
hable de usted, diga «área» y no «materia», y quepa en 30 segundos: unas 75
palabras leídas sin apuro.

## Las fuentes del cuaderno

1. **`SIGA/DOCs/SIGA - Qué hace hoy.pdf`**: lo que el sistema hace hoy, por
   rol. Sale del repo (`bin/rails comercial:documentos`), así que se usa el de
   esa carpeta y no una copia guardada en otro lado.
2. **Los dos guiones de abajo**, cada uno pegado como fuente de texto (la
   opción de pegar texto copiado), con su título: «Guion · Principal» y
   «Guion · Roles».

## Cómo se hace cada video

1. En notebooklm.google.com, crear un cuaderno «SIGA — videos» con las tres
   fuentes.
2. En la configuración, poner el idioma de salida en **español**.
3. Dejar marcadas dos fuentes: «Qué hace hoy» y el guion del video que se va a
   hacer. El otro guion, desmarcado.
4. En el panel «Studio», el **resumen en video** (Video Overview) → el lápiz
   para personalizar:
   - el formato **breve** (Brief), que es el más corto;
   - un estilo visual sobrio;
   - el prompt de ese video, pegado tal cual.
5. Generar, mirarlo entero antes de usarlo y descargarlo.

⚠️ **NotebookLM no deja fijar la duración.** El guion está escrito para 30
segundos. Si el video sale más largo, se genera otra vez. Si insiste, está el
plan B: grabar la pantalla de la muestra con QuickTime (una toma por puerta) y
ponerle la voz del guion en iMovie.

⚠️ **Mirarlo antes de mandarlo:** que no aparezca un precio, una pantalla
inventada o la palabra «materia». La IA a veces agrega lo que no le pidieron.

## Video 1 · Principal

```guion
¿Las notas de su colegio todavía viven en Excel y en Word?
SIGA reúne en un solo lugar las notas, la asistencia, los boletines
y los documentos del ministerio.
El profesor carga las notas desde su teléfono, el promedio se calcula solo,
y la familia las ve el mismo día.
Cargar su colegio es gratis.
Véalo funcionando en demo.sigaeducando.com.
```

```prompt
Video de 30 segundos para el director de un colegio privado de Venezuela.
Narra el texto de la fuente «Guion · Principal» casi palabra por palabra, sin
agregar ideas ni datos. Español de Venezuela, tratando de usted. No menciones
precios, planes, descuentos ni fechas. Di «área de aprendizaje», nunca
«materia». Tono cercano y seguro, sin exagerar. Termina con la dirección
demo.sigaeducando.com escrita en pantalla.
```

## Video 2 · Roles

```guion
Un mismo sistema, tres miradas.
La dirección ve todo el colegio: sabe quién no ha cargado notas,
y emite boletines y constancias con un clic.
El profesor pasa lista y califica desde el teléfono, en el aula.
La familia ve las notas y la asistencia de cada hijo el mismo día,
y descarga el boletín sin ir a secretaría.
Entre como cualquiera de los tres en demo.sigaeducando.com.
```

```prompt
Video de 30 segundos que muestra lo que ve cada quien en SIGA: la dirección,
el profesor y la familia, en ese orden y con una escena para cada uno. Narra
el texto de la fuente «Guion · Roles» casi palabra por palabra, sin agregar
ideas ni datos. Español de Venezuela, tratando de usted. No menciones
precios, planes, descuentos ni fechas. Di «área de aprendizaje», nunca
«materia». Termina con la dirección demo.sigaeducando.com escrita en pantalla.
```

## Lo que dice cada frase, y dónde se comprueba

Cada afirmación es de algo que existe hoy. Si una función cambia, se cambia el
guion y se vuelve a hacer el video.

```
   «documentos del ministerio»           la 31059, los certificados, el Resumen Final
   «carga las notas desde su teléfono»   la planilla de notas, que guarda cada nota sola
   «el promedio se calcula solo»         GradeCalculator: del 1 al 20, artículos 108 y 111
   «la familia las ve el mismo día»      el portal del representante
   «cargar su colegio es gratis»         la entrada libre de RespetaLaSuscripcion
   «quién no ha cargado notas»           «Quién no cargó», que mira la dirección (manual, 27)
   «boletines y constancias con un clic» la ficha del alumno
   «pasa lista»                          la asistencia del profesor guía
   «descarga el boletín»                 los boletines liberados al cerrar el lapso
   «como cualquiera de los tres»         las tres puertas de la muestra
```
