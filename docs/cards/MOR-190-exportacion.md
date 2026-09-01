# MOR-190 · La exportación

> **Cómo usar esta card.** Es el contrato de UNA sesión. La primera sección es
> una pregunta sin responder: **leela y resolvela con Daniel antes de escribir
> código.** El resto asume una respuesta concreta que puede no ser la suya.

**Estado:** sin empezar.
**No desplegar.** Daniel: *«estamos trabajando en local, hagamos el despliegue cuando ya esté todo»*.

---

## ⚠️ Primero: qué significa «exportar» acá

Daniel lo nombró en una lista —*«¡Falta un tema sumamente importante: la
Exportación!»*— y no lo detalló. **Hay tres cosas distintas con ese nombre**, y
una de ellas ya está hecha:

```
   1. LOS DOCUMENTOS DEL MPPE     ya existe  →  boletines, constancias, la 31059
                                                 en PDF y en Excel editable
   2. BAJAR UN LISTADO            ← lo que asume esta card
   3. SACAR TODO EL COLEGIO       irse de SIGA con sus datos
```

**Lo que esta card asume es (2):** bajar a Excel **lo que estás viendo**, con los
filtros y el año escolar puestos. Es lo que falta y lo que se pide todos los
días —«mandame la lista de 3er Año A»—, y es lo que hoy obliga a copiar de la
pantalla a mano.

**(3) es otra card**, y probablemente otra conversación: es la contracara del
importador y toca el argumento de venta de Edudatos (*«usted es dueño de sus
datos»*). No la mezcles acá.

---

## Lo que ya está hecho — no rehacerlo

- **`caxlsx` ya está en el Gemfile** y ya se usa: `CertificacionXlsx` genera un
  `.xlsx` de verdad, con anchos, combinaciones y estilos.
- **`PlantillaDeImportacion`** ya baja una planilla modelo — el camino inverso,
  con el mismo mecanismo.
- **El patrón de descarga ya existe** en cinco controllers:
  `send_data documento.to_stream.read, filename: …`
- **`Planilla`** resuelve el otro lado: adivina separador y codificación al leer.

⚠️ El principio del proyecto aplica en serio acá: *«si podemos implementar
funciones REUTILIZABLES y COHERENTES, hazlo»*. Una exportación pegada a mano en
cada controller es exactamente lo que esto NO tiene que ser.

---

## Los listados que existen hoy

```
   students · teachers · representatives · admins · sections · grades
   subjects · departments · enrollments · asistencias · evaluation_activities
   academic_periods · evaluation_moments · reparaciones · importaciones
```

No todos merecen exportarse, y conviene no hacerlos todos por simetría. Los que
un colegio pide de verdad: **alumnos** (con su sección y su representante),
**inscripciones**, **asistencia** y **notas**.

---

## ⚠️ Lo que hay que cuidar

**Lo que se exporta es lo que se está viendo.** Si la pantalla tiene un filtro
puesto y el archivo trae todo el colegio, el colegio manda por correo una lista
que no revisó. El botón hereda los parámetros de la petición — es la mitad del
valor de la función.

**Y hereda el año escolar de la sesión** (`MOR-165`). Un export sin año es un
archivo con tres años mezclados.

**Ojo con Pagy.** El listado en pantalla está paginado; el archivo **no** puede
traer solo la página 1. Se exporta el scope completo, sin `pagy`.

**Encabezados en español y en Tipo Título**, como se leen en la pantalla — el
archivo lo abre una secretaria, no un programador. Y el nombre de la materia sale
por `Subject#name`, que ya devuelve Tipo Título (`MOR-188`): **no uses `pluck`**,
que se salta el getter y escribe MAYÚSCULAS.

**El formato es `.xlsx`, no CSV.** Ya está la gema, y un CSV en un Excel en
español abre mal —la coma es el separador decimal, ver `## ⚠️ Estado conocido § 3`—.
Justo el problema que el importador tuvo que resolver al leer: no lo reintroduzcas al escribir.

**Cédulas y teléfonos como TEXTO.** Excel se come el cero de «0414…» y convierte
una cédula larga a notación científica. Hay que forzar el tipo.

**Exportar es sacar datos del sistema, y eso se audita.** `Auditable` +
`ActivityLog` ya existen. Qué se exportó y quién — no el contenido.

**¿Entra en el plan gratis?** El corte del plan Inicial es **por función**
(`## ⚠️ Estado conocido § 7`), así que esto es una decisión, no un detalle:
listar es libre, y emitir documentos se activa con el plan. Un export de la
matrícula se parece más a listar; uno de notas, más a emitir.

---

## Lo que hay que preguntarle a Daniel

1. **¿(2) o (3)?** — es la pregunta de arriba, y cambia toda la card.
2. **¿Qué listados?** Empezar por alumnos e inscripciones, o hacerlo genérico.
3. **¿Entra en el plan gratis?**
