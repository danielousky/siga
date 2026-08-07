# Investigación de mercado

## `sae-cartera-subdominios.txt`

194 subdominios de colegio bajo `asistescolar.com` (Sistemas SAE, el incumbente venezolano).

**Cómo se obtuvo.** Certificate transparency — todo certificado TLS emitido queda en un registro
público. Consulta a `crt.sh`:

```bash
curl -s "https://crt.sh/?q=%25.asistescolar.com&output=json" > ct.json
```

4.095 certificados → 444 nombres únicos → 230 tras normalizar `www.` → **194 tras descartar
infraestructura** (cpanel, webmail, whm, webdisk, autodiscover, soporte, etc.).

**Verificación.** Muestra de 60 al azar: 52 responden HTTP 200 (87 %). Se estiman ~170 portales
activos.

**Para qué sirve.** SAE declara "+900 instituciones" pero solo ~195 tienen portal web ⇒ el ~78 %
de su cartera usa el producto de escritorio, **sin acceso web**. Ese segmento —colegios que ya
pagan software y no pueden ver notas desde la casa— es el mejor prospecto para SIGA: no hay que
convencerlos de digitalizarse, solo de actualizarse.

**Composición.** Concentración en centro-occidente: Guanare 5, Bolívar 7, Carora 3, Lara 3,
Barquisimeto 2, Mérida 2, más cola larga (Chivacoa, Sanare, Quíbor, Turén, La Grita, El Vigía,
Amazonas). **Caracas y Maracaibo aparecen ausentes.** Redes religiosas: 5 salesianas (Mazzarello),
5 adventistas, 3 Divina Pastora, 2 La Salle, 2 Calasanz, Fe y Alegría, Don Bosco.

**Límites.** Es un **piso**, no un total: los colegios con dominio propio no aparecen
(se vio `colegiosantateresita.com.ve.asistescolar.com`, que lo sugiere). Y el "900" de SAE es su
cifra de marketing, que puede incluir clientes históricos inactivos.

Fecha: agosto 2026.
