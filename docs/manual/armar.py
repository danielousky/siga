#!/usr/bin/env python3
"""Junta las cuatro partes del manual y arma las DOS versiones que se publican.

    manual_de_siga.html        una sola pieza, con las capturas en base64
                               → es lo que se sube como artifact y lo que
                                 imprime `a_pdf.sh`

    docs/manual/publicado/     la del servidor: el HTML y el PDF, que sirve
    public/manual/capturas/    `ManualController`, y las capturas sueltas

⚠️ La del servidor NO lleva las imágenes adentro, y la diferencia importa donde
importa: un colegio con conexión mala. En base64 son 3,5 MB que hay que bajar
ENTEROS antes de ver la primera línea; sueltas, el texto aparece de una y las
cuarenta y nueve capturas van llegando con `loading="lazy"` — que en el archivo
de una pieza no hace nada, porque ya están todas adentro.

El marcador {{IMG:nombre}} y el <figcaption> que le sigue se envuelven juntos en
un <figure>: la hoja de estilo cuelga de `figure img`, y un <figcaption> suelto
no es HTML válido.
"""
import base64, pathlib, re, shutil, sys

AQUI  = pathlib.Path(__file__).parent
FOTOS = AQUI / "opt"
RAIZ  = AQUI.parent.parent
# ⚠️ El HTML NO va en `public/`, y no es capricho: `public_file_server.headers`
# le pone a TODO lo de ahí un `max-age` de un año, que es correcto para un
# asset con huella en el nombre y veneno para un documento que se corrige —el
# navegador de un colegio se quedaría con el manual viejo hasta 2027. Lo sirve
# `ManualController`, que le pone una hora.
#
# Las CAPTURAS sí van en `public/`: son las mismas 49 imágenes, no cambian de
# contenido sin cambiar de manual, y así no pasan por Ruby.
WEB      = RAIZ / "docs" / "manual" / "publicado"
CAPTURAS = RAIZ / "public" / "manual" / "capturas"

MARCADOR = re.compile(
    r"\{\{IMG:([a-z0-9_]+)\}\}[ \t]*\n(?:[ \t]*(<figcaption>.*?</figcaption>)\n)?",
    re.DOTALL,
)

# ⚠️ El esqueleto SOLO lo lleva la del servidor. La de una pieza se publica como
# artifact, y ahí el `<head>` lo pone la plataforma: duplicarlo daría dos.
ESQUELETO = """<!doctype html>
<html lang="es-VE">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="Manual de SIGA: las 37 funciones del sistema, en orden y con pantallas, desde crear la cuenta del colegio hasta imprimir el papel que la familia se lleva.">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
</head>
<body>
{cuerpo}
</body>
</html>
"""

cuerpo_original = "\n".join((AQUI / f"m{n}.html").read_text() for n in (1, 2, 3, 4))

# ⚠️ El enlace al PDF solo existe en la del SERVIDOR. En el artifact esa ruta
# no lleva a ninguna parte, y un enlace roto enseña a desconfiar de los demás.
DESCARGA = ('<p class="descarga"><a href="/manual.pdf">Descargar en PDF</a> '
            "<span>72 páginas, para imprimir o mandar por WhatsApp</span></p>")

faltan = []


def figura(coincidencia, ruta_de_la_imagen):
    nombre, pie = coincidencia.group(1), coincidencia.group(2) or ""
    archivo = FOTOS / f"{nombre}.jpg"
    if not archivo.exists():
        faltan.append(nombre)
        return ""
    alt = pie and re.sub(r"<[^>]+>", "", pie).replace('"', "'")
    return (f'<figure>\n<img loading="lazy" alt="{alt or nombre}" '
            f'src="{ruta_de_la_imagen(nombre, archivo)}">\n{pie}\n</figure>\n')


def en_base64(_nombre, archivo):
    return "data:image/jpeg;base64," + base64.b64encode(archivo.read_bytes()).decode()


def como_archivo(nombre, _archivo):
    # ⚠️ Absoluta: el HTML se sirve desde `/manual` y las capturas viven en
    # `/manual/capturas/`. Con una ruta relativa, `/manual` resolvería contra
    # la raíz y pediría `/capturas/…`.
    return f"/manual/capturas/{nombre}.jpg"


def armar(destino, ruta_de_la_imagen, envolver=None, descarga=""):
    cuerpo = MARCADOR.sub(lambda m: figura(m, ruta_de_la_imagen), cuerpo_original)
    cuerpo = cuerpo.replace("{{PDF}}", descarga)
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(envolver(cuerpo) if envolver else cuerpo)
    return destino.stat().st_size / 1024 / 1024


# ── de una pieza, para el artifact y para imprimir ──────────────────────────
peso = armar(AQUI / "manual_de_siga.html", en_base64)
print(f"manual_de_siga.html         {peso:5.1f} MB   (capturas adentro)")

# ── la del servidor ────────────────────────────────────────────────────────
peso = armar(WEB / "index.html", como_archivo, descarga=DESCARGA,
             envolver=lambda cuerpo: ESQUELETO.format(cuerpo=cuerpo))
shutil.rmtree(CAPTURAS, ignore_errors=True)
CAPTURAS.parent.mkdir(parents=True, exist_ok=True)
shutil.copytree(FOTOS, CAPTURAS)
sueltas = sum(f.stat().st_size for f in CAPTURAS.iterdir()) / 1024 / 1024
print(f"docs/manual/publicado/…     {peso:5.1f} MB   + {sueltas:.1f} MB de capturas sueltas")

publicado = (WEB / "index.html").read_text()
sueltos = publicado.count("<figcaption>") - publicado.count("<figure>")
if sueltos:
    print(f"⚠️  {sueltos} pies de foto fuera de su <figure>")
if faltan:
    print("FALTAN:", ", ".join(sorted(set(faltan))))
    sys.exit(1)
