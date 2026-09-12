#!/usr/bin/env python3
"""Deja el catálogo listo para versionar.

  · quita el estado que el directorio pega al final del nombre
    («… Sánchez Ostos, Apure» → «… Sánchez Ostos»)
  · descarta los que quedaron sin nombre
  · quita repetidos por (nombre, dea)
  · ordena por estado y nombre, para que el diff del día que se actualice
    muestre lo que cambió y no un archivo entero movido
"""
import csv, re, sys, unicodedata

def sin_acentos(s):
    return "".join(c for c in unicodedata.normalize("NFD", s) if not unicodedata.combining(c)).lower()

filas, vistos = [], set()
with open("planteles.csv", encoding="utf-8") as f:
    for fila in csv.DictReader(f):
        estado = (fila["estado"] or "").strip()
        nombre = (fila["nombre"] or "").strip()
        # El directorio agrega «, <estado>» al final del nombre. No es del colegio.
        nombre = re.sub(rf",\s*{re.escape(sin_acentos(estado))}\s*$", "", nombre, flags=re.I) \
            if sin_acentos(nombre).endswith(", " + sin_acentos(estado)) else nombre
        nombre = nombre.strip(" ,")
        if not nombre:
            continue
        clave = (sin_acentos(nombre), fila["dea"])
        if clave in vistos:
            continue
        vistos.add(clave)
        filas.append({"dea": (fila["dea"] or "").strip(), "nombre": nombre, "estado": estado})

filas.sort(key=lambda f: (f["estado"], sin_acentos(f["nombre"])))

with open("planteles-limpio.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["dea", "nombre", "estado"])
    w.writeheader()
    w.writerows(filas)

con = sum(1 for f in filas if f["dea"])
print(f"── {len(filas)} planteles · {con} con código DEA ({con * 100 // max(len(filas),1)} %)")
for f in filas[:4]:
    print(f"   {f['dea'].ljust(11)} {f['nombre'][:48].ljust(50)} {f['estado']}")
