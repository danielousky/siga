# Los correos de SIGA, con identidad

> **Estado:** **congelado** el 5 de octubre de 2026 · en construcción
> **PR:** — (rama `feat/correos-con-identidad`)

---

## 1 · El problema

Daniel, 5 de octubre de 2026, con el correo de «recuperar contraseña» abierto en
Gmail:

> *«Esto no parece para nada un correo institucional de SIGA. Parece cualquier
> cosa.»*

Y no es solo ese. De los ocho correos que manda SIGA, **siete salen sin
cabecera, sin pie y casi sin estilo**: texto negro sobre blanco con un enlace
azul. Una mamá que recibe «el boletín de Daniela ya está disponible» no tiene
cómo distinguirlo, de un vistazo, de un correo cualquiera — ni de uno falso.

```
   CORREO                                   PLANTILLA      CÓMO SE VE
   ──────                                   ─────────      ──────────
   Recuperar contraseña (Devise)            mailer         texto pelado
   Contraseña cambiada (Devise)             mailer         texto pelado — y en inglés (hoy no se envía)
   Activar el acceso (AccesoMailer)         mailer         texto pelado
   Boletín disponible (BoletinMailer)       mailer         un botón, nada más
   Mensaje del colegio (ComunicacionMailer) mailer         texto y una firma
   Colegio registrado (PlataformaMailer)    mailer         interno, sin diseño
   Bienvenida (BienvenidaMailer)            mailer_siga    el único con banner
```

Dos cosas más que se ven antes de abrirlo, o al final:

- El remitente es `no-responder@sigaeducando.com`, sin nombre.
- Al pie aparece «MANAGE NOTIFICATIONS», en inglés. No es nuestro: lo agrega
  ElasticEmail a todo correo transaccional.

## 2 · Qué NO entra

```
   ENTRA                                   NO ENTRA
   ─────                                   ────────
   una plantilla para los ocho correos     cambiar lo que dicen los mensajes
   cabecera y pie del colegio o de SIGA    ENCENDER «contraseña cambiada»: hoy Devise no lo
   el remitente con nombre                   manda; queda traducido y con su diseño
   el enlace de avisos, en español         las letras de la portada (DM Serif Display):
   el texto plano de los ocho                Gmail las ignora siempre
   traducir «contraseña cambiada»          que el colegio escriba desde su dominio:
   vistas previas de todos                   ElasticEmail solo despacha el de SIGA
                                           enterarse de los rebotes (MOR-145)
                                           pedirle a ElasticEmail que quite su enlace: es
                                             de la cuenta, que comparten otros tres sistemas
```

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿De quién es el correo de la contraseña? | **Del colegio, si la persona es de uno solo**; de SIGA si es de dos o de ninguno | Daniel, 5 oct. |
| 2 | ¿Qué tipografía? | **La misma en todos los clientes**: la serif y la sans de la app, sin descargar letras | Daniel, 5 oct. |
| 3 | ¿Sobre qué fondo va el mensaje? | **Azul muy suave** (`#e8eef5`) | Daniel, 5 oct. |
| 4 | ¿Una plantilla o dos? | **Una** (`layouts/mailer`) con dos variantes de cabecera; `mailer_siga` se retira | Claude |
| 5 | ¿Cómo viajan los logos? | **Alojados**, con dirección permanente, cada uno sobre una ficha blanca | Claude |
| 6 | ¿Qué se hace con «MANAGE NOTIFICATIONS»? | Se reemplaza por un enlace propio, con la etiqueta `{unsubscribe}` de ElasticEmail | Claude |
| 7 | ¿Cómo se llama el remitente? | «U.E. … · SIGA» en los del colegio; «SIGA» en los demás. La dirección no cambia | Claude |

## 4 · El dominio

Lo que manda acá no es una ley: es cómo se comporta el correo, que no es la web.

- **Tablas y estilos en línea.** Outlook dibuja con el motor de Word, que no
  entiende flexbox ni grid; Gmail descarta buena parte de un `<style>`.
- **Gmail ignora las tipografías web**, y Outlook clásico, al no encontrarlas,
  cae en Times New Roman. Por eso la decisión 2: la pila del sistema se ve igual
  en todos.
- **Gmail muestra las imágenes alojadas sin preguntar**; Outlook de escritorio
  las bloquea hasta que la persona acepta. Incrustadas (CID) tienen soporte
  dudoso en correo web. Por eso la decisión 5 — y por eso **el nombre del
  colegio es texto**, nunca parte de una imagen.
- **Un correo vive años.** La dirección de una imagen no puede llevar la huella
  de un despliegue: `public/correo/siga.png`, y la variante de Active Storage
  del escudo.
- ⚠️ **Nada de `.processed` en un mailer.** Una variante nueva se guarda al
  confirmar la transacción, y en SIGA la transacción es la petición entera: es
  el `IOError` de «Descargar las listas» (`CLAUDE.md § 1`). Acá solo se ARMA la
  dirección; la miniatura la procesa Active Storage cuando alguien la pide.
- **ElasticEmail agrega su enlace de baja a todo correo**, también por SMTP; en
  los transaccionales lo rotula «Manage Notifications». No se apaga por código.
  Si el cuerpo ya trae `{unsubscribe}`, usa ese.
- ⚠️ **Un correo SOBRE un colegio no es un correo DEL colegio.** El aviso a SIGA
  de «colegio nuevo» tiene `@colegio` y es de la plataforma. Por eso de quién es
  cada correo se DICE (`a_nombre_de`), no se deduce.

## 5 · Cómo se ve

```
 ┌──────────────────────────────────────────────────────────────┐
 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  azul oscuro #07142f,
 │▓ ┌────┐   U.E. SIMÓN BOLÍVAR                         ┌────┐ ▓│  el de la portada
 │▓ │ESC.│   Libertador, Distrito Capital · DEA BOL001  │SIGA│ ▓│
 │▓ └────┘                                              └────┘ ▓│  logos sobre ficha blanca
 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
 │──────────────────────────────────────────────────────────────│  franja azul cielo
 │░  El boletín de Daniela ya está disponible          (serif) ░│
 │░                                                            ░│  el mensaje, sobre azul
 │░  Buen día,                                                 ░│  muy suave #e8eef5
 │░  El boletín del 1er Lapso de Daniela Bastidas ya está      ░│
 │░  listo en SIGA.                                            ░│
 │░                                                            ░│
 │░  ┌──────────────────┐                                      ░│
 │░  │  Ver el boletín  │                                      ░│  botón #1e4a7a
 │░  └──────────────────┘                                      ░│
 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  pie, mismo azul oscuro
 │▓ U.E. Simón Bolívar                       Enviado con SIGA  ▓│
 │▓ Av. Casanova con calle El Colegio · 0212-555-1234         ▓│
 │▓ Este mensaje se envió a maria@…  ·  Administrar avisos    ▓│
 │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
 └──────────────────────────────────────────────────────────────┘
```

```
   DEL COLEGIO   escudo (si lo tiene) · nombre y datos del colegio · logo de SIGA
                 → activar el acceso · boletín disponible · mensaje del colegio
                 → los dos de la contraseña, si la persona es de UN solo colegio

   DE SIGA       logo de SIGA · «SIGA — Sistema Integrado de Gestión Académica»
                 → bienvenida · colegio registrado
                 → los dos de la contraseña, si es de dos colegios o de ninguno
```

En la bandeja, antes de abrirlo:

```
   ANTES    no-responder@sigaeducando.com    Instrucciones de recuperación de contraseña
   DESPUÉS  U.E. Simón Bolívar · SIGA        U.E. Simón Bolívar: el boletín de Daniela ya está…
            SIGA                             Cómo crear una contraseña nueva
```

## 6 · Criterios de aceptación

- [ ] Los tres correos del colegio llevan su nombre y sus datos en la cabecera,
      y el logo de SIGA.
- [ ] Con escudo cargado llevan su imagen; sin escudo, no hay imagen rota: sale
      el nombre.
- [ ] La bienvenida y el aviso de «colegio nuevo» llevan la cabecera de SIGA,
      aunque el segundo hable de un colegio.
- [ ] El de recuperar la contraseña sale del colegio para quien es de uno solo,
      y de SIGA para quien es de dos, de ninguno, o del equipo de SIGA.
- [ ] El remitente lleva nombre —el del colegio o «SIGA»— y la dirección de
      siempre.
- [ ] Los ocho correos traen parte HTML **y** de texto.
- [ ] Ninguno dice nada en inglés.
- [ ] El pie trae el enlace de avisos con `{unsubscribe}` solo cuando el correo
      sale por ElasticEmail.
- [ ] Las direcciones de las imágenes no llevan huella de despliegue.
- [ ] Ningún correo se corre de lado a 600 ni a 380 px.
- [ ] El canal de ElasticEmail, `trackclicks`, `trackopens` e `IsTransactional`
      quedan como estaban.

## 7 · Lo que se puede romper

- `correo_saliente_test` — «Devise usa el mismo remitente que la app» compara
  `default from` con `Devise.mailer_sender`: los dos pasan a llevar nombre, y
  tienen que hacerlo juntos. Y llama a `Devise::Mailer` a secas: los correos de
  la cuenta pasan a salir de `CuentaMailer`.
- **El canal de los correos de Devise** se arma del nombre de la clase. Con
  `CuentaMailer` pasaría a `siga-cuenta-…` y partiría las estadísticas en dos:
  se conserva `siga-devise-…` a propósito.
- `correo_de_bienvenida_test` — busca el banner tipográfico de `mailer_siga`,
  que desaparece.
- `sistema_de_diseno_test` exime `layouts/mailer*` y `*_mailer/`, **no**
  `devise/mailer/`: esas plantillas no pueden llevar `style=`. Por eso el botón
  y la nota son helpers.
- ⚠️ `User#unico_colegio` **apaga el aislamiento** para leer los roles de una
  persona sin sesión. Es la misma salida que ya usa `colegio_de`, acotada a sus
  filas; si se escribe de más, deja ver colegios ajenos.
- **El modo oscuro de Gmail** invierte los fondos claros a su manera. No se
  puede probar con un test: se mira en el teléfono.

## 8 · Cómo se verifica

- `bin/ci`.
- Las vistas previas en `/rails/mailers`, a ancho de escritorio y de teléfono.
  Las mira Daniel: es donde se decide si se ve institucional.
- ⚠️ **Lo que solo se ve en producción**, con un envío real a Gmail después de
  desplegar: que los dos logos carguen, que «MANAGE NOTIFICATIONS» ya no
  aparezca y esté el nuestro, y cómo queda en Gmail web y en el teléfono.
