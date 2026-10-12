# Despliegue

> ⚠️ **Este archivo describe el primer despliegue, de agosto de 2026**, y varias
> cosas ya no son así: el registro existe, el colegio de muestra tiene su propia
> instancia (`demo.sigaeducando.com`) y las cuentas de los seeds cambiaron. Lo
> que manda hoy para operar es [`docs/tareas-de-operacion.md`](docs/tareas-de-operacion.md).

Dos caminos, y el primero sirve **hoy**: un túnel de Cloudflare contra la máquina
de desarrollo, para tener una demo pública en minutos. El segundo es Dokku sobre
un servidor propio, que es donde esto termina viviendo.

---

## ⚠️ Lo único que no se puede equivocar

La app se conecta a PostgreSQL con un rol que **no puede ser superusuario ni
tener `BYPASSRLS`**. Con cualquiera de los dos, PostgreSQL se salta las políticas
de Row-Level Security **antes de mirarlas** y los datos de todos los colegios
quedan visibles entre sí.

Y no lo notaría nadie: la capa de la aplicación filtra igual, los tests siguen en
verde, y las pantallas se ven bien. Es exactamente lo que pasó durante el
desarrollo (`MOR-87`).

```bash
bin/rails rls:verificar    # SUPERUSER: false / BYPASSRLS: false
```

`bin/docker-entrypoint` lo corre en cada arranque del contenedor. **Un contenedor
que no arranca es infinitamente preferible a uno que arranca con el aislamiento
apagado.**

---

## 1 · Demo pública en minutos, con Cloudflare Tunnel

Sirve para mostrarle la app a alguien hoy. No es un despliegue: es la máquina de
desarrollo expuesta por un túnel.

```bash
# 1 · Datos frescos
bin/rails db:seed:replant

# 2 · El server, aceptando el dominio del túnel
#     Rails bloquea cualquier `Host` que no reconozca — sin esto la app responde
#     "Blocked hosts" y parece un problema del túnel.
SIGA_HOSTS=".trycloudflare.com" bin/rails server

# 3 · El túnel, en otra terminal
cloudflared tunnel --url http://localhost:3000
```

`cloudflared` imprime una URL `https://algo-algo.trycloudflare.com`. Esa es la demo.

### Qué mostrar

| Entrar como | Ver |
| -- | -- |
| `director.bolivar@mail.com` | El panel de SU colegio — sus alumnos, no los de la plataforma |
| `director.bello@siga.edu` | Mismo sistema, otro colegio, cero cruce — y con la suscripción vencida |
| `profesor.bolivar@mail.com` | Mis Evaluaciones → **Cargar Notas**. Escribir una nota: se guarda sola |
| `sofia.ramos002@bolivar.edu` | Mis Notas. Su lapso da 9,50 crudo y se ve **10** — Art. 108 |

Contraseña de todos: `123123`.

Y el remate: como director, **Emitir Boletines** → sale un PDF con una página por
alumno. Copiar el código del pie, cerrar sesión, y entrar a `/verificar` sin
cuenta: el boletín se verifica contra la fuente.

### Lo que NO hay que hacer con este camino

* No dejarlo levantado sin mirar. Es la base de desarrollo, con `123123`.
* No usarlo para datos de un colegio real.
* La URL de `trycloudflare.com` cambia en cada arranque y es pública para
  cualquiera que la tenga.

---

## 2 · Dokku

### Antes, en el servidor

```bash
# Postgres y la app
dokku apps:create siga
dokku postgres:create siga-db
dokku postgres:link siga-db siga        # inyecta DATABASE_URL
```

> El rol que crea el plugin de Postgres es **dueño** de la base pero **no
> superusuario**, que es justamente el caso que `FORCE ROW LEVEL SECURITY` cubre.
> `rls:verificar` lo confirma en cada arranque igual.

### Variables

```bash
dokku config:set siga \
  SECRET_KEY_BASE=$(openssl rand -hex 64) \
  SIGA_HOST=siga.tudominio.com \
  SIGA_HOSTS=siga.tudominio.com \
  SIGA_MAIL_FROM=no-responder@tudominio.com
```

| Variable | Para qué | Si falta |
| -- | -- | -- |
| `SECRET_KEY_BASE` | firmar sesiones y cookies | la app no arranca |
| `SIGA_HOST` | dominio en los enlaces del correo | los enlaces apuntan a `localhost` |
| `SIGA_HOSTS` | qué dominios acepta | **no filtra nada** — hay que ponerlo |
| `SIGA_FORCE_SSL` | `false` para el primer arranque | queda en `true` |
| `SIGA_HSTS_SEGUNDOS` | vida del HSTS | 1 hora |
| `SMTP_ADDRESS` y compañía | envío de correo | "olvidé mi contraseña" **no envía nada** |

> ⚠️ **`SECRET_KEY_BASE` se genera en el servidor y no se guarda en ningún lado.**
>
> SIGA no usa `config/credentials.yml.enc`: guardaba exactamente un valor —este— y
> todo lo demás ya vivía como variable de entorno, así que era un segundo sistema
> de secretos con su propia llave que cuidar. Rails lee `ENV["SECRET_KEY_BASE"]`
> antes que las credenciales; en desarrollo y en tests se genera solo.
>
> Cambiarlo **desconecta a todo el mundo**: invalida las sesiones y las cookies
> firmadas. Los códigos de activación NO se ven afectados —Devise los guarda
> digeridos en la base, no firmados con esta llave—.

#### Sobre `force_ssl` y HSTS

`force_ssl` activa HSTS, y **HSTS es difícil de deshacer**: el navegador recuerda
"esta gente solo habla HTTPS" durante `max_age` y no acepta que le digan lo
contrario. Si el certificado no está en orden, el sitio queda inaccesible **en el
navegador del visitante** hasta que ese plazo expire.

Por eso el `max_age` arranca en **una hora**. Se sube a un año cuando el dominio
y el certificado llevan unos días asentados:

```bash
dokku config:set siga SIGA_HSTS_SEGUNDOS=31536000
```

Para el primer arranque, antes de tener certificado:

```bash
dokku config:set siga SIGA_FORCE_SSL=false SIGA_ASSUME_SSL=false
```

### Desplegar

```bash
git remote add dokku dokku@<servidor>:siga
git push dokku main
```

Dokku detecta el `Dockerfile`. El `bin/docker-entrypoint` corre `db:prepare` y
`rls:verificar` antes de levantar Puma.

### Dominio y certificado

```bash
dokku domains:set siga siga.tudominio.com
dokku letsencrypt:enable siga
```

### Health check

`GET /up` responde 200 y está fuera de la autenticación, del redirect a HTTPS y
del filtro de dominios — Dokku lo consulta por IP desde adentro del servidor.

---

## 3 · El primer colegio real

Los seeds **no corren fuera de desarrollo**: crean cuentas con contraseña
conocida, una con rol `desarrollador` (`MOR-104`).

Para una demo pública en el servidor, con datos de prueba, hay una puerta y
cuesta escribirla:

```bash
dokku run siga env SIGA_ENTORNO_DEMO=1 SIGA_SEED_PASSWORD=<una-clave-de-verdad> \
  bin/rails db:seed
```

La contraseña **no tiene default** fuera de desarrollo. Una demo en internet con
`123123` es una cuenta de administrador abierta a cualquiera que lea este
repositorio.

Para un colegio de verdad, hoy el alta es por consola:

```bash
dokku run siga bin/rails console
```

```ruby
colegio = School.create!(name: "…", dea_code: "…", location: "…", school_type: :secondary)

Current.school = colegio
usuario = User.create!(name: "…", last_name: "…", email: "…", password: SecureRandom.alphanumeric(16))
Admin.create!(user: usuario, school: colegio, role: :director)
```

Desde ahí el director da de alta al resto desde el panel. **No existe registro
público** (`MOR-101`): las cuentas nacen de la matrícula o de la nómina.

> Que este paso sea manual es una deuda conocida. El camino bueno es el importador
> de matrícula (`MOR-126`), que además es lo que un colegio necesita para traer su
> histórico de notas.

---

## 4 · Lo que todavía no está

| | |
| -- | -- |
| **Respaldos** | no hay nada automatizado (`MOR-106`) |
| **Monitoreo** | tampoco (`MOR-106`) |
| **Cola de trabajos** | el adaptador es `:async` y **pierde lo encolado al reiniciar**. Hoy el único job es el recálculo masivo de notas, y `bin/rails notas:recalcular` repara lo que se pierda |
| **Almacenamiento de adjuntos** | disco local. En Dokku hay que montar un volumen o se pierden en cada despliegue |

El último es el más urgente de los cuatro si se sube el logo de un colegio:

```bash
dokku storage:ensure-directory siga-storage
dokku storage:mount siga /var/lib/dokku/data/storage/siga-storage:/rails/storage
```
