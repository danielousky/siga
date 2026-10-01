# Los certificados, en «Documentos»

> **Estado:** congelado el 1 de octubre de 2026 · **construido, sin subir**
> **PR:** — (rama `feat/certificados-en-documentos`)

---

## 1 · El problema

En la lista de Cyndi del 18 de septiembre el punto 11 decía *«certificados de
Inicial, prosecución y promoción»*, marcado como faltante. **No faltaban:**
existen desde el 11 de septiembre (`MOR-99`). Daniel, 1 de octubre:

> *«Creo que ella nunca vio los certificados, no los encontró.»*

El código le da la razón, por tres lados a la vez:

```
   DONDE UNO LOS BUSCA                   DONDE ESTÁN
   ───────────────────                   ───────────
   menú ▸ Documentos                     Alumnos ▸ un alumno ▸ bajar hasta
     [ Boletines | Constancias ]         la ÚLTIMA tarjeta de su ficha:
       └─ los certificados no están        «Documentos oficiales»
                                           [ Emitir el documento ]
```

1. **El menú «Documentos» tiene dos pestañas** y los certificados no están en
   ninguna.
2. **El manual manda al sitio equivocado**: dice que se emiten desde la pestaña
   «Alumnos» de la sección, y ahí solo está el Resumen Final.
3. **Como profesora no hay camino**: los emite la administración, y la ficha del
   alumno que ve el profesor no trae documentos.

Y hay un problema más viejo debajo. La ficha se eligió con este argumento, que
sigue escrito en la vista: *«se piden de a uno: la mamá llega a la secretaría
por el papel de SU hijo»*. Eso vale para la 31059. Los otros cuatro son papeles
de **fin de año, que se le entregan a toda la sección** — y hoy son un clic por
alumno, con la ficha abierta, veinticuatro veces.

## 2 · Qué NO entra

```
   ENTRA                               NO ENTRA
   ─────                               ────────
   la pestaña «Certificados»           el Resumen Final: es de la SECCIÓN y ya
   un alumno o toda la sección         está en su pestaña «Alumnos»
   los tres niveles                    el Excel de la 31059: sigue en la ficha,
   el manual, corregido                es para completar a mano de a uno
   la tarjeta de la ficha, igual       que el profesor los vea o los emita
                                       el TEXTO de ningún documento
                                       que Boletines y Constancias respeten el
                                       nivel de la sesión (ver § 7)
```

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Dónde se encuentran? | Tercera pestaña en Documentos, **completa**: un alumno o toda la sección en un solo PDF. La tarjeta de la ficha se queda. | Daniel |
| 2 | En «toda la sección», ¿qué pasa con quien la promoción daría por «repite»? | **Fuera del lote.** Se lista aparte con el motivo, y se le puede emitir eligiéndolo a él. | Daniel |
| 3 | ¿Entra Media con su 31059? | **Sí, los tres niveles.** En PDF; el Excel sigue en la ficha. | Daniel |
| 4 | ¿Y quien no tiene calificación definitiva? | **Sale**, con el literal como línea para llenar a mano, y la pantalla lo dice antes de emitir. | Daniel |
| 5 | ¿Los retirados? | No entran: ni en el lote ni en el desplegable. | Claude — avisado a Daniel en el plan |
| 6 | ¿A qué papeles aplica la decisión 2? | Solo a los que **afirman** la promoción: los dos de primaria. | Claude — consecuencia de la 2, a revisar |
| 7 | ¿Qué secciones se ofrecen? | Las del año y el nivel de la sesión. | Claude — `CLAUDE.md § 8` |

⚠️ **La 6 es mía y hay que mirarla.** La 31059 no dice que el alumno fue
promovido: es el historial de sus notas, y es cierta también para quien repite.
Sacar del lote a un repitiente ahí sería negarle un papel que no miente. En
Inicial la pregunta no llega a hacerse: no hay notas, así que nadie «repite».

## 4 · El dominio

**El grado decide el papel**, y no se configura:

```
   3er Nivel         Certificación de Estudios del Nivel de Educación Inicial
   1er y 2do Nivel   Constancia de Prosecución en el Nivel de Educación Inicial
   6to Grado         Certificado de Educación Primaria
   1ro a 5to Grado   Constancia de Prosecución en el Nivel de Educación Primaria
   Media             Certificación de Calificaciones (forma 31059)
```

Lo fijan `DocumentoDeInicial::ULTIMO_GRUPO` y `DocumentoDePrimaria::ULTIMO_GRADO`,
que ya existen. La pestaña **pregunta**, no decide otra vez.

**«Repite» es lo que dice la pantalla de promoción** (`CLAUDE.md § 10`): arrastra
más materias aplazadas que `schools.tope_de_arrastre`. Es una sola regla y tiene
que seguir siendo una: sale de `PromocionDeAlumnos`, que hoy la tiene enterrada
en un método privado atado a la promoción del año entero.

- ⚠️ **No sé qué dice la norma del MPPE sobre el papel de quien no pasa en
  primaria.** La decisión 2 no sale de la norma: sale del propio papel, que dice
  *«siendo promovido(a) al 4to Grado»* sin mirar las notas. Emitido de a uno, lo
  decide quien lo firma. Emitido de a veinticuatro, nadie lo mira.
- ⚠️ **«Sin datos» NO es «repite».** Un colegio en su primer año con SIGA tiene
  las notas del año pasado en papel: sus alumnos no tienen definitiva, y el
  certificado sale igual con la línea en blanco — que es lo que hace el formato
  del ministerio. Tratarlo como repitiente dejaría la pestaña vacía justo para el
  cliente nuevo.
- **La deuda es del colegio, no del alumno** (`CLAUDE.md § 7`): un colegio con la
  suscripción vencida sigue emitiendo. El plan gratuito no emite.

## 5 · Cómo se ve

```
   ANTES                                  DESPUÉS
   ─────                                  ───────
   Documentos                             Documentos
   [ Boletines | Constancias ]            [ Boletines | Constancias | Certificados ]
```

```
   Documentos
   [ Boletines | Constancias | Certificados ]

   Sección  [ 3er Grado – A · 2025-2026          ▾ ]

   Constancia de Prosecución en el Nivel de Educación Primaria

   Alumno   [ Toda la sección (22 alumnos)       ▾ ]

   ⚠ 2 alumnos no tienen calificación definitiva: su literal sale como una
     línea para llenar a mano.
   ⚠ 1 alumno queda fuera de «toda la sección»:
       Castro Díaz, Ana — repite: arrastra Lenguaje, Matemática y Ciencias
     Se le puede emitir eligiéndolo en «Alumno».

            [ Emitir y descargar ]   →  un PDF, una página por alumno
```

El desplegable dice **cuántos salen** —22—, no cuántos tiene la sección —23—:
es lo que el botón va a hacer.

## 6 · Criterios de aceptación

- [ ] La dirección emite el certificado de un alumno y sale un PDF.
- [ ] «Toda la sección» devuelve un PDF con **una página por alumno**, cada una
      con el nombre del suyo.
- [ ] El grado decide el papel: 6to Grado → certificado; otro grado →
      prosecución; 3er Nivel → certificación; Media → 31059.
- [ ] Quien repite queda **fuera del lote**, la pantalla dice quién y por qué, y
      eligiéndolo a él sí se emite.
- [ ] En Media el repitiente **sí** entra en el lote.
- [ ] Quien no tiene definitiva entra en el lote y la pantalla lo avisa.
- [ ] Un retirado no aparece ni en el lote ni en el desplegable.
- [ ] Una sección de otro colegio da 404.
- [ ] Un profesor y un alumno no entran a la pestaña.
- [ ] En el plan gratuito la pestaña **se ve** y emitir se bloquea.
- [ ] Con la suscripción vencida **sí** se emite.
- [ ] Queda el rastro de quién emitió: contra el alumno si es uno, contra la
      sección si es el lote.
- [ ] Las tres pestañas encienden «Documentos» en el menú.
- [ ] `PromocionDeAlumnos` propone exactamente lo mismo que antes.

## 7 · Lo que se puede romper

- **El colegio con la suscripción vencida.** Hoy emite certificados porque se
  piden por `GET`. La pestaña emite por `POST`, y `exigir_suscripcion_al_dia!`
  bloquea los `POST`. Sin `["certificados", "create"]` en `SIEMPRE_PERMITIDO`, el
  colegio endeudado pierde por la puerta nueva un papel que por la vieja saca.
- **El plan gratuito.** `documentos_oficiales` está en `CONTROLADORES_CON_PLAN`;
  un controlador nuevo no lo está. Sin `["certificados", "create"]` en
  `ACCIONES_CON_PLAN`, el plan gratuito emitiría certificados por aquí.
- **Los tres PDF guardan los datos de UN alumno en el objeto** (`@d`, `@tipo`, y
  `CertificacionPdf` memoriza el colegio). Dibujando varios, una página puede
  arrastrar un dato de la anterior sin fallar: el PDF sale, y dice otra cosa.
- **`PromocionDeAlumnos` se toca** para sacar la regla a donde se pueda
  preguntar. Escribe inscripciones: su test tiene que seguir en verde sin
  cambiarle una línea.
- `menu_test` — *«boletines y constancias son pestañas de la misma pantalla»*
  cuenta DOS pestañas y recorre dos rutas. Va a fallar, y está bien que falle:
  pasa a contar tres y a recorrer la tercera.
- **Boletines y Constancias no respetan el nivel de la sesión** y esta pestaña
  sí. No se arregla aquí —es otra discusión— pero con «Primaria» elegido arriba
  las tres pestañas no van a listar lo mismo.

## 8 · Cómo se verifica

`bin/ci`, y además **mirar el PDF de una sección entera**: que la segunda página
empiece arriba, con su escudo, y con el nombre del segundo alumno. Un test que
solo comprueba que el archivo empieza por `%PDF` pasa igual con las veinticuatro
páginas diciendo el mismo nombre.


---

## 9 · Lo que apareció al construir

Tres cosas que el spec no preveía. Van aquí y no solo en el commit porque dos de
ellas cambian lo que este documento afirmaba.

**① El documento de Educación Inicial estaba roto en producción.** Emitirlo
desde la ficha levantaba un `NoMethodError` en cualquier colegio con director
cargado, desde el 11 de septiembre:

```
   el controlador   →  le pasa al armador el REGISTRO del director (`Admin`)
   el armador       →  le pedía `nombre_completo` a lo que recibiera
   su único test    →  lo llamaba sin director, y pasaba
```

Lo encontró el test de la pestaña, que emite por el mismo camino. Se arregló y
se cubrió el controlador (`documentos_desde_la_ficha_test`), que no tenía ni un
test. **Corrige el § 1**: aun encontrando el botón, a Cyndi le habría fallado el
de Inicial.

**② El papel de primaria ya decía «promovido» de cualquiera**, también desde la
ficha. La decisión 2 lo saca del lote; de a uno sigue saliendo, que es lo
decidido. Queda anotado porque es el mismo hueco por la otra puerta, y la
respuesta de fondo —qué papel le toca a quien no pasa— depende de una norma que
no tengo.

**③ La 31059 recorta el año de la fecha de expedición.** «LIBERTADOR, DISTRITO
CAPITAL 1 DE OCTUBRE DE» y ahí termina: el «2026» no cabe en la casilla. Es del
dibujante de siempre, no de este cambio, y **no se tocó** —el texto de los
documentos quedó fuera en el § 2—. Hay que arreglarlo aparte: un documento
oficial sin el año de emisión no sirve.

Y una del § 7 que resultó distinta: `menu_test` no «seguía pasando sin probar la
tercera». Contaba dos pestañas, así que **falló**, que es lo que tenía que
hacer.
