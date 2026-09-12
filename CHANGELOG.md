# Qué cambió, y qué significa para un colegio

Los números son SemVer con los significados puestos **desde el colegio**, no
desde una API: de SIGA no depende nadie, hay una sola versión corriendo y todos
los colegios la tienen. Ver `Siga::VERSION` en `config/application.rb`.

```
   MAYOR    cambia CÓMO TRABAJA el colegio    hay que avisarle y enseñarle
   MENOR    una función nueva                  se cuenta acá
   PARCHE   un arreglo o un ajuste             nadie tiene que enterarse
```

⚠️ **`1.0.0` no significa «está completo»: significa que un colegio real opera
con esto.** Y esta lista se escribe para quien usa SIGA, no para quien lo
programa: si una entrada no se puede explicar sin nombrar un archivo, no va acá
— va en el mensaje del commit, que es donde vive el detalle técnico.

---

## Por salir · 1.0.0

- **Sacar los datos de demostración de producción** (`MOR-146`). Es lo único que
  falta para el 1.0: hoy la base que ve el mundo tiene 290 alumnos inventados y
  usuarios con la contraseña de los seeds.

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
