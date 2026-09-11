#!/usr/bin/env python3
"""Arma el catálogo de planteles: nombre, código DEA y estado.

Lee el directorio público por estado y por página. Una petición por segundo:
no hay ninguna prisa y sí un servidor ajeno del otro lado.
"""
import csv, html, re, sys, time, urllib.request

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
BASE = "https://trosell.net/dir/planteles_educativos_de_venezuela"
ESTADOS = [
    ("amazonas", 41), ("anzoategui", 42), ("apure", 43), ("aragua", 44),
    ("barinas", 45), ("bolivar", 46), ("carabobo", 47), ("cojedes", 48),
    ("delta_amacuro", 49), ("distrito_capital", 50), ("falcon", 51),
    ("guarico", 52), ("la_guaira", 53), ("lara", 54), ("merida", 55),
    ("miranda", 56), ("monagas", 57), ("nueva_esparta", 58), ("portuguesa", 59),
    ("sucre", 60), ("tachira", 61), ("trujillo", 62), ("yaracuy", 63), ("zulia", 64),
]

def bajar(url):
    pedido = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(pedido, timeout=30) as r:
        return r.read().decode("utf-8", "replace")

def entradas_de(pagina, slug):
    patron = (rf'href="(/dir/planteles_educativos_de_venezuela/{slug}/[a-z0-9_\-]+/\d+-[\d\-]+)"'
              r'[^>]*>(.*?)</a>(.{0,700}?)(?=href="/dir/planteles_educativos|$)')
    for ruta, titulo, cola in re.findall(patron, pagina, re.S):
        nombre = html.unescape(re.sub(r"<[^>]*>", "", titulo)).strip()
        if not nombre:
            continue
        dea = re.search(r"\b([A-Z]{1,2}\d{6,10})\b", re.sub(r"<[^>]*>", " ", cola))
        yield ruta, nombre, (dea.group(1) if dea else "")

def paginas_de(pagina, slug, ident):
    """La última página, leída de los ENLACES del paginador.

    ⚠️ Antes se buscaba dentro del bloque «Páginas:» y eso fallaba en la mitad
    de los estados —Anzoátegui declaraba una sola página y tiene trece—, así
    que el catálogo habría salido con el 8 % de lo que hay. Los enlaces están
    igual en la página; el rótulo es el que no es de fiar.
    """
    paginas = re.findall(rf'href="/dir/planteles_educativos_de_venezuela/{slug}/{ident}-(\d+)"', pagina)
    return max([1] + [int(n) for n in paginas])

def main():
    salida = open("planteles.csv", "w", newline="", encoding="utf-8")
    escritor = csv.writer(salida)
    escritor.writerow(["dea", "nombre", "estado", "ruta"])
    vistos, total = set(), 0

    for slug, ident in ESTADOS:
        primera = bajar(f"{BASE}/{slug}/{ident}")
        n = paginas_de(primera, slug, ident)
        print(f"── {slug}: {n} páginas", flush=True)
        for p in range(1, n + 1):
            pagina = primera if p == 1 else bajar(f"{BASE}/{slug}/{ident}-{p}")
            nuevos = 0
            for ruta, nombre, dea in entradas_de(pagina, slug):
                if ruta in vistos:
                    continue
                vistos.add(ruta)
                escritor.writerow([dea, nombre, slug.replace("_", " ").title(), ruta])
                nuevos += 1
                total += 1
            salida.flush()
            if p < n:
                time.sleep(1)
        print(f"   {slug}: {total} acumulados", flush=True)

    salida.close()
    print(f"══ LISTO · {total} planteles", flush=True)

main()
