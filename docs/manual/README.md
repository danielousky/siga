# El manual de SIGA

El documento que se le entrega a un colegio: las 36 funciones del sistema, en
orden, con una captura de pantalla por cada una. Vive publicado como artifact.

```
   capturar.rb ──► png/  ──► optimizar.sh ──► opt/  ──► armar.py ──► a_pdf.sh
   53 pantallas    ~45 MB    sips a JPEG      2,7 MB       │         PDF 72 pág.
                                                           │
                       ┌───────────────────────────────────┴──────────┐
                       ▼                                              ▼
        manual_de_siga.html  3,5 MB                 docs/manual/publicado/
        capturas en base64                          public/manual/capturas/
        → el artifact y el PDF                      → /manual en el servidor
```

## Dos versiones del mismo texto, y por qué

⚠️ **La del servidor NO lleva las imágenes adentro.** En base64 son 3,5 MB que
hay que bajar ENTEROS antes de ver la primera línea — y el lector típico es un
colegio con conexión mala. Sueltas, el texto aparece de una y las capturas van
llegando con `loading="lazy"`, que en el archivo de una pieza no hace nada.

⚠️ **Y el HTML publicado NO vive en `public/`.** Ahí
`public_file_server.headers` le pone a todo un `max-age` de un año: correcto
para un asset con huella en el nombre, veneno para un documento que se corrige.
Lo sirve `ManualController` con una hora. Las capturas sí van en `public/`.

## Por qué el texto y las imágenes viven separados

`m1`…`m4.html` son **fragmentos**, no páginas: `m1` abre el `<style>`, el índice
y `<main>`, y `m4` los cierra. Se concatenan en ese orden.

Dentro del texto, cada captura es un marcador `{{IMG:nombre}}` con su
`<figcaption>` en la línea siguiente. `armar.py` los cambia por un `<figure>`
con la imagen en base64. ⚠️ **El marcador es a propósito**: el HTML final pesa
3 MB y editarlo a mano —o pasarlo por el contexto de un modelo— no es viable.
Se edita el fragmento; el ensamblado es de un comando.

## Rehacerlo

```bash
bin/rails server                  # con los seeds cargados
ruby docs/manual/capturar.rb      # ~4 min, entra como cada rol
docs/manual/optimizar.sh          # PNG → JPEG de 980 px
python3 docs/manual/armar.py      # → docs/manual/manual_de_siga.html
docs/manual/a_pdf.sh              # → docs/manual/manual_de_siga.pdf
```

⚠️ **El PDF no es una segunda versión que mantener.** Chrome imprime el MISMO
HTML, y cómo se ve en papel lo deciden los estilos de `@media print` de
`m1.html`: el índice deja de ser una barra fija y sale como primera hoja a dos
columnas, cada apartado empieza en página nueva y una captura no se parte entre
dos hojas.

`armar.py` avisa de dos cosas que no fallan solas: un marcador cuyo archivo no
existe (**FALTAN**) y un `<figcaption>` que quedó fuera de su `<figure>`
(**pies sueltos**) — un pie suelto no es HTML válido y el estilo cuelga de
`figure img`, así que se vería sin borde y sin ancho.

⚠️ **Ni las capturas ni lo generado están versionados** (`png/`, `opt/`, el HTML
y el PDF están ignorados): son
2,7 MB que se regeneran de los seeds en cuatro minutos, y quedarían viejos en
cuanto cambie una pantalla.

⚠️ **`capturar.rb` registra un colegio de cero y lo borra al terminar.** La
puesta en marcha solo se ve en un colegio que todavía no acabó de armarse, y los
seeds están completos. Lo borra `borrar_el_de_prueba.rb`, por el CORREO de quien
lo registró y no por el nombre del colegio: el nombre sale impreso en tres
capturas, así que tiene que parecer real — y un nombre creíble puede ser el de
alguien.

⚠️ **Los ids de las capturas se buscan por NOMBRE en la siembra de hoy**
(`ids.rb`, que `capturar.rb` corre al empezar). Estuvieron escritos a mano y
cambiaban con cada `db:seed`: el 13 de octubre de 2026 no existía ninguno, y el
manual seguía mostrando una siembra de septiembre. Los personajes son los de la
muestra: el director, García y Andreína Suárez.