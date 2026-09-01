# MOR-189 · Los correos, de punta a punta

> **Cómo usar esta card.** Es el contrato de UNA sesión. Leela entera antes de
> tocar nada, y en particular «Lo que ya está hecho»: el esquema existe y está
> commiteado, así que la sesión NO empieza por una migración.

**Estado:** esquema listo (`7f10e06`). Falta modelo, envío, webhook, inbound y pantalla.
**No desplegar.** Daniel: *«estamos trabajando en local, hagamos el despliegue cuando ya esté todo»*.

---

## Qué pidió Daniel

> *«Emails, completo. Agregar incluso webhooks en ElasticEmail que nos indiquen
> cuándo lo reciban, y le colocamos una pequeña tabla de envíos, no editables,
> con opciones de ver si lo recibieron, si lo abrieron y responder directamente.
> Creo que también valdría la pena agregar la visualización de inbound. ¡Tipo CRM!»*

Tres cosas, y conviene no mezclarlas:

```
   SEGUIMIENTO   qué pasó con lo que mandamos      →  eventos del webhook
   RESPONDER     contestarle a la familia          →  desde la misma tabla
   INBOUND       lo que la familia escribe sola    →  requiere plan Pro + MX
```

---

## Lo que ya está hecho — no rehacerlo

`MOR-186` dejó el envío funcionando: `Mensaje`, `ComunicacionMailer`,
`MensajesController`, el compositor plegado en la ficha del representante, y el
enlace de WhatsApp (`Contacto.whatsapp_url`). Eso **anda**; esta card lo extiende.

`7f10e06` agregó el esquema y **la migración ya corrió**:

| Tabla | Para qué |
| -- | -- |
| `mensajes.token` | el identificador de correlación, único |
| `mensaje_eventos` | `tipo` · `ocurrio_en` · `detalle` (jsonb) |
| `mensajes_entrantes` | `de` · `asunto` · `cuerpo` · `recibido_en` · `leido_en` · `crudo` |

Las dos tablas nuevas ya tienen RLS con `FORCE`, como las otras 24.

---

## ⚠️ La pieza que hace que todo funcione: el token

El `messageid` de ElasticEmail **no sirve para correlacionar**: lo asigna él
después de recibir el correo por SMTP, y nosotros nunca lo vemos.

La salida es un identificador nuestro que viaje con el correo y vuelva en el
aviso. ElasticEmail lo llama `postback` — un header propio que devuelve tal cual
en cada notificación. El **mismo** token va en el `Reply-To`:

```
   sale      →  X-PostBack: k3f9…      Reply-To: respuesta+k3f9…@sigaeducando.com
   abren     →  GET /webhooks/…?postback=k3f9…&status=Opened
   responden →  el sobre trae  respuesta+k3f9…@sigaeducando.com
```

Un solo dato ata el envío, sus eventos y la respuesta.

---

## Lo que dice la documentación de ElasticEmail (verificado, 1 sep 2026)

- El webhook es un **`GET` con query params**, no un POST JSON.
- `status` ∈ `Sent · Opened · Clicked · Unsubscribed · Error · AbuseReport`.
  **Los rebotes llegan como `Error`** y las quejas como `AbuseReport` — no
  existe un `Bounced`.
- Campos: `from · to · date · subject · status · channel · account · category ·
  messageid · transaction · postback`; en opens y clicks además `IP ·
  Useragent · Country · State · City`, y `target` para el enlace del clic.
- **El endpoint tiene que contestar `2xx` a un `GET` de validación** o
  ElasticEmail no acepta la configuración.
- `X-PostBack` exige tener **«Custom headers» activado** en
  Account → Settings → Sending → Advanced. Sin eso el header se descarta y el
  aviso vuelve sin `postback`: el seguimiento queda mudo, sin ningún error.
- **Inbound** necesita plan **Email API Pro** y apuntar el **MX** a
  `mx.inbound.elasticemail.com`.

Fuentes: [Notification Settings](https://help.elasticemail.com/en/articles/4804685-notification-settings) ·
[Custom headers](https://help.elasticemail.com/en/articles/2376848-how-to-manage-custom-headers) ·
[Inbound routing](https://elasticemail.com/inbound-routing)

---

## ⚠️ Lo que hay que cuidar

**El webhook es una puerta pública y sin sesión.** Va con
`skip_before_action :authenticate_user!` —igual que `/salud`— y por lo tanto
**no puede confiar en `Current.school`**: el colegio sale del `Mensaje` que el
token identifica. Si el token no existe, se responde `2xx` igual y se descarta:
un `404` hace que ElasticEmail reintente para siempre.

**Y hay que fijar el colegio antes de escribir.** El evento es `SchoolScoped`,
así que sin `Current.school` puesto el RLS rechaza el `INSERT`. El patrón que ya
existe es `Current.en_el_colegio(mensaje.school) { ... }`.

**Nadie puede adivinar un token.** Es lo único que separa a un tercero de
escribir eventos falsos en la ficha de una familia. `SecureRandom.urlsafe_base64`,
no un id ni un hash del correo.

**El evento repetido no puede duplicar la fila.** ElasticEmail reintenta lo que
no contestó 2xx; el índice único `(mensaje, tipo, ocurrio_en)` ya está puesto,
pero el código tiene que tolerar el choque en vez de reventar. Ojo: **no** es
único por `(mensaje, tipo)` a propósito — abrir un correo el martes y el jueves
son dos hechos, y el segundo es el que dice que la familia volvió a mirarlo.

**«No abierto» no es «no lo leyó».** El píxel de apertura no dispara si el
cliente bloquea imágenes, que hoy es la mayoría. La pantalla tiene que decir
«sin registro de apertura», nunca «no lo leyó» — es la misma disciplina de
«Pendiente» vs. cero en las notas.

**El inbound entra sin autenticar y con contenido de un tercero.** Se guarda y
se muestra escapado; nunca se ejecuta ni se renderiza como HTML.

---

## La pantalla

Daniel pidió **una tabla de envíos, no editable**. Va en la ficha de la persona,
donde ya vive la lista de `MOR-186`, más una entrada propia en el menú para ver
todo el colegio junto.

- Estado del envío legible: enviado / abierto / rebotado, con **cuándo**.
- **Responder** desde la misma fila (reusa el compositor que ya existe).
- Lo entrante se ve en el mismo hilo, con `leido_en` para saber qué falta atender.
- Color: **verde/rojo/ámbar solo para el DATO** —el estado del envío es un dato,
  el botón «Responder» no—. Ver `[[regla-de-color-siga]]` y `MOR-172`.

---

## Lo que hay que preguntarle a Daniel

1. **¿El plan de ElasticEmail es Pro?** Sin eso el inbound no existe, y hay que
   cambiar el MX del dominio — que es una decisión suya, no técnica.
2. **¿La barra de texto enriquecido entra acá?** Quedó pendiente de `MOR-186`;
   aceptó «una primera etapa» sin ella.
