# El catálogo de planteles

`planteles.csv` es la lista de planteles del MPPE que SIGA **sugiere** cuando
alguien escribe el nombre de su colegio al registrarse.

```
   15.954 planteles · 13.441 con código DEA (84 %) · los 24 estados
```

## ⚠️ Sugiere, no decide

Daniel, 11 de septiembre de 2026: *«es sugerencia, no verdad»*. Lo que se elige
rellena los campos y ahí termina su trabajo: **se registra lo que la persona
deje escrito.** Por eso el código DEA aparece como un campo de texto normal y no
viaja ningún «id del plantel» por detrás.

Y por eso el catálogo puede estar incompleto sin que eso le cueste el registro a
nadie: quien no encuentra su colegio escribe el nombre y sigue. Es la misma
regla que `DivisionPolitica::OTRO`.

## Cómo se actualiza

```bash
   python3 db/catalogos/extraer.py     # arma planteles.csv del directorio público
   python3 db/catalogos/limpiar.py     # quita el estado pegado al nombre, ordena
   bin/rails catalogo:planteles        # lo siembra
```

El archivo se versiona **con el código**. Un catálogo que se descarga al
desplegar haría que el registro dependiera de que un tercero esté en pie — y el
registro es la puerta del producto.

⚠️ `extraer.py` pide **una página por segundo**. No hay ninguna prisa y sí un
servidor ajeno del otro lado.

## De dónde salen los datos

Los códigos DEA y los nombres de los planteles los publica el MPPE: son hechos
públicos. No hay una descarga oficial única —circulan en PDF y en hojas por
estado— así que esta copia se armó del directorio público de
[trosell.net](https://trosell.net/planteles-venezuela), que los tiene en
`schema.org/School` con el código etiquetado.

⚠️ **Antes de crecer con esto, conviene hablar con ellos**: los datos son
públicos, pero el directorio compilado es su trabajo. Un enlace de crédito es
barato.

## ⚠️ El código DEA lleva el ESTADO adentro, y está comprobado

Los dos dígitos que anteceden a los dos últimos son el código INE de la entidad
federal. Contrastado contra las 13.441 filas con código:

```
   Amazonas   163/163 → 02      Apure    725/725 → 04
   Anzoátegui 483/483 → 03      Bolívar  915/915 → 07
```

Sirve para detectar un código mal tecleado: si alguien escribe un DEA cuyo
estado no coincide con el suyo, hay algo que revisar.

## ✅ Y los dos ÚLTIMOS son el MUNICIPIO — confirmado

    O D 0489 02 03
            │  │  └── municipio dentro del estado  ── «03» = Atures
            │  └───── entidad federal (código INE) ── «02» = Amazonas
            └──────── el registro ante la zona educativa

Los cuatro dígitos finales son el `Co_municip` de la **División Político
Territorial del INE**, tal cual. Contrastado contra las 13.441 filas con
código: **casan 13.434, el 99 %.**

⚠️ Las siete que no casan y las dos excepciones son reales, no ruido:

- **Distrito Capital y La Guaira tienen UN SOLO municipio** —Libertador y
  Vargas— y el MPPE usa ahí códigos 02, 03, 04 y 05 que son subdivisiones
  suyas. Cualquier código de un estado con un municipio cae en ese municipio,
  y eso no es una suposición: es aritmética.
- Siete filas con códigos que no existen en la DPT: erratas de la fuente.
  Quedan **sin municipio**, no con uno inventado.

El catálogo de la DPT vive en `db/catalogos/division_politica.csv` y lo lee
`DivisionPolitica`. Se bajó del servicio público del INE:

    24 entidades · 334 municipios · 1.123 parroquias

⚠️ La ortografía viene del catálogo anterior, escrito a mano: la capa del INE
trae los nombres **sin acentuar** —«Andres Bello», «Brion»— y esos nombres
salen impresos en los documentos del MPPE.

## Lo que el catálogo NO trae

- **La dirección.** La ficha de cada plantel SÍ la tiene
  (`schema.org/PostalAddress` → `streetAddress`), pero está en la ficha y no en
  el listado: traerla son ~16.000 peticiones más, unas cuatro horas y media a
  una por segundo.
- **Municipio y parroquia.** No están en ninguna de las dos: la ficha solo trae
  el estado y la calle. Ver arriba lo del código.
- **Acentos en los nombres.** La fuente los tiene sin acentuar («JOSE», no
  «JOSÉ»). Como se puede corregir al registrarse, no se inventaron.
