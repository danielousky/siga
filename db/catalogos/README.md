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

## Lo que el catálogo NO trae

- **Municipio y parroquia.** El directorio los tiene en la ficha de cada
  plantel, no en el listado. Traerlos serían ~16.000 peticiones más, y hoy no
  hacen falta: el registro no pregunta la ubicación.
- **Acentos en los nombres.** La fuente los tiene sin acentuar («JOSE», no
  «JOSÉ»). Como se puede corregir al registrarse, no se inventaron.
