# El nivel de la sesión

> **Estado:** **congelado** — 3 de septiembre de 2026
> **Issue:** por crear en Linear
> **PR:** —

---

## 1 · El problema

Un colegio venezolano de tamaño medio dicta preescolar, primaria y bachillerato
a la vez. En SIGA los tres viven mezclados en cada pantalla: al armar una
sección el desplegable de grados ofrece los catorce, de «1er Nivel» a «5to Año»,
y al listar alumnos salen los de tres años de vida escolar distintos en la misma
tabla.

Daniel, después de mirar la gestión completa:

> *«Creo que la gestión de todo, además de dividirse en Año Escolar, el otro
> gran elemento divisor son los tipos que maneja la institución. Puede ser
> confuso crear una sección y que me aparezcan preescolar, primaria y
> bachillerato juntos. Creo que la gestión se realiza dividido. Entonces, seteas
> un Año Escolar que trabajas en ese momento y luego un tipo: "Vamos a trabajar
> Primaria". Ocasionalmente se quisiera ver cosas en conjunto, pero creo que por
> la naturaleza de la gestión van separados.»*

Y no es solo comodidad visual: **el trabajo del colegio está partido por nivel
en la realidad.** La coordinadora de primaria no toca bachillerato, el boletín
de preescolar no se parece al de quinto año, y la reunión de septiembre para
armar secciones se hace un nivel por vez.

Hoy, además, cada pantalla lo resuelve por su cuenta o no lo resuelve. En el
mockup de `/grados` hay una columna «Nivel» que repite en catorce filas lo que
un encabezado diría una vez, y Daniel la tachó.

⚠️ Esto es la **prioridad A1 de UX**, y es además el piso del módulo de
evaluación de preescolar y primaria: ese módulo **es** específico de nivel —la
escala de preescolar es cualitativa, la de primaria literal, la de bachillerato
del 1 al 20— así que si el nivel no es un concepto de primera clase antes,
ese módulo lo va a inventar por su cuenta y mal.

## 2 · Qué NO entra

```
   ENTRA                                    NO ENTRA
   ─────                                    ────────
   el selector en la barra de contexto      el rediseño de /grados con KPIs y
   el scope `del_nivel_de_la_sesion`          quick-create — su propio spec
   las pantallas que se filtran             pestañas por nivel dentro de una
   decir cuándo el filtro NO aplica           pantalla — las reemplaza esto
   quitar la columna «Nivel» de /grados      permisos por nivel (que una
                                              coordinadora SOLO vea primaria)
                                              es autorización, no preferencia
```

**Permisos por nivel es otra cosa y hay que decirlo fuerte.** Esto es una
preferencia de quien mira, igual que el año escolar: no da acceso a nada nuevo
y no lo quita. El día que un colegio pida «la coordinadora de primaria no puede
ver bachillerato», eso vive en el ROL —como `Current.school`— y no acá. Mezclar
los dos es la manera de terminar con un límite de seguridad que se apaga desde
un desplegable.

## 3 · Las decisiones

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | ¿Cuál es el nivel por defecto? | **«Todos».** Ver § 4 | ✅ Daniel |
| 2 | ¿Quién ve el selector? | Solo dirección, igual que el año. El profesor ya ve solo sus secciones | ✅ deducido de MOR-165 |
| 3 | ¿Aparece si el colegio dicta un solo nivel? | No. Igual que el selector de año con un solo año | ✅ deducido de MOR-165 |
| 4 | ¿El panel del director respeta el nivel? | **Sí**, salvo la matrícula que factura. Ver § 7 | ✅ Daniel |
| 5 | ¿Media Técnica es una opción del selector? | **No.** Cae dentro de «Bachillerato». Ver § 4 | ✅ dominio |
| 6 | ¿Qué pasa donde el nivel no aplica? | **El selector se apaga y dice por qué.** Ver § 5 | ✅ Daniel |
| 7 | ¿Es `default_scope`? | **No**, explícito, igual que `DelAnioEscolar`. Ver § 7 | ✅ deducido |
| 8 | ¿Cómo se llama en pantalla? | «Nivel». No «tipo»: `school_type` se borró en MOR-160 por excluyente | ✅ dominio |

## 4 · El dominio

**Los niveles los fija el Reglamento de la LOE**, y ya viven en
`GradoOficial::NIVELES`. El nivel de un grado **se deduce de su nombre** —«4to
Grado» es primaria, «4to Año» es bachillerato— así que no hay nada que capturar.

⚠️ **Media Técnica NO es un cuarto botón del selector.** Un colegio técnico
dicta 1er a 5to Año como cualquier bachillerato y agrega un 6to. Si el selector
ofreciera «Bachillerato» y «Media Técnica» por separado, elegir «Bachillerato»
**escondería el 6to Año** — que es exactamente la trampa que `Grade#media?`
existe para evitar, y la que dejó ciega a la certificación 31059 en su momento.

```
   EL SELECTOR OFRECE          Y FILTRA POR
   ──────────────────          ────────────
   Preescolar                  level: preescolar
   Primaria                    level: primaria
   Bachillerato                level: [secundaria, media_tecnica]   ← las dos
```

**Y por eso el nivel por defecto es «Todos».** Es la misma trampa que
`AcademicPeriod.en_operacion` resolvió y que ya apareció tres veces en este
proyecto: un valor por defecto «razonable» que hace que el colegio abra su panel
y lea un número que no es el suyo.

```
   defecto = un nivel        un colegio de 360 alumnos abre el panel y lee 140.
                             Su primera conclusión no es «estoy en primaria»:
                             es «se perdieron los datos».

   defecto = «Todos»         el panel dice 360. Elegir primaria es un ACTO,
                             y después de ese acto el 140 se explica solo.
```

Daniel lo dijo como un modo de trabajo —*«vamos a trabajar Primaria»*— y un modo
de trabajo se **entra**, no se hereda.

## 5 · Cómo se ve

**La barra de contexto gana un selector, al lado del año.**

```
   ANTES
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ SIGA  LA ESCUELITA NUEVA   AÑO ESCOLAR [2026-2027 ▾] 📅  comienza el 15  │
   └──────────────────────────────────────────────────────────────────────────┘

   DESPUÉS
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ SIGA  LA ESCUELITA NUEVA   [2026-2027 ▾] 📅   NIVEL [Todos ▾]            │
   └──────────────────────────────────────────────────────────────────────────┘

   con un nivel elegido — se ve que ESTÁ elegido, no es un desplegable más:
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ SIGA  LA ESCUELITA NUEVA   [2026-2027 ▾] 📅   ▌PRIMARIA ▾▐               │
   └──────────────────────────────────────────────────────────────────────────┘
```

⚠️ **Con un nivel activo el control se pinta, no se queda gris.** Un filtro
puesto que no se ve es la manera de que alguien cargue veinte alumnos en el
lugar equivocado y culpe al sistema. Es la misma razón por la que la barra ya
muestra «finalizado el 31 de julio» al lado del año.

**Los listados dicen sobre qué están contando.**

```
   ANTES                          DESPUÉS (con Primaria elegida)
   ─────                          ──────────────────────────────
   290 alumnos                    142 alumnos de Primaria
```

**Y `/grados` pierde su columna «Nivel»** — la que Daniel tachó. Con el nivel
arriba, repetirlo en catorce filas es decir lo mismo catorce veces:

```
   ANTES                                    DESPUÉS (con Primaria elegida)
   ┌──────────┬────────────┬──────────┐     ┌──────────┬────────────────────┐
   │ NOMBRE   │ NIVEL      │ COORD.   │     │ NOMBRE   │ COORDINADOR        │
   │ 1er Nivel│ Preescolar │ —        │     │ 1er Grado│ —                  │
   │ 2do Nivel│ Preescolar │ —        │     │ 2do Grado│ —                  │
   │ 1er Grado│ Primaria   │ —        │     │ …                             │
   │ …                                │     └──────────┴────────────────────┘
```

Con «Todos» elegido la columna vuelve, porque ahí sí distingue.

**Donde el nivel no aplica, el selector lo dice.** Un departamento, un año
escolar, un lapso y un administrador son del COLEGIO, no de un nivel:

```
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ SIGA  …   [2026-2027 ▾]   ▌PRIMARIA ▾▐  ⓘ los departamentos son de todo  │
   │                                            el colegio                     │
   └──────────────────────────────────────────────────────────────────────────┘
```

⚠️ Esta es la parte que más fácil se hace mal: **un filtro que aparece puesto y
no filtra es peor que no tenerlo.** Quien ve «PRIMARIA» arriba y una lista de
ocho departamentos concluye que primaria tiene ocho departamentos.

## 6 · Criterios de aceptación

- [ ] Dado un colegio que dicta un solo nivel, cuando entro como director,
      entonces **no** hay selector de nivel en la barra.
- [ ] Dado un colegio con preescolar, primaria y bachillerato, cuando entro por
      primera vez, entonces el nivel de la sesión es «Todos» y el panel cuenta
      los 290 alumnos.
- [ ] Dado que elijo «Primaria», cuando abro `/secciones`, entonces solo veo
      secciones de grados de primaria, y el conteo lo dice.
- [ ] Dado que elijo «Bachillerato» en un colegio técnico, entonces **6to Año
      aparece**: `media_tecnica` cae dentro de bachillerato.
- [ ] Dado que elijo «Primaria», cuando abro `/departamentos`, entonces veo
      todos los departamentos y la barra dice que ahí el nivel no aplica.
- [ ] Dado que elijo «Primaria», cuando recargo o navego a otra pantalla,
      entonces sigue elegido: vive en la sesión.
- [ ] Dado que elijo «Primaria», cuando cierro y abro sesión, entonces vuelve a
      «Todos» — como el año.
- [ ] Dado un profesor, cuando entra, entonces no hay selector de nivel.
- [ ] Dado que elijo «Primaria», entonces la **matrícula que factura la
      suscripción sigue siendo la del colegio entero**.
- [ ] Dado que elijo «Primaria», cuando subo una planilla que trae bachillerato,
      entonces se importa completa.
- [ ] Dado «Todos», entonces `/grados` muestra la columna «Nivel»; con un nivel
      elegido, no.

## 7 · Lo que se puede romper

⚠️ **`DelNivel` NO puede ser un `default_scope`, y por las mismas razones que
`DelAnioEscolar` (MOR-165) más una peor.**

```
   el COLEGIO   límite de SEGURIDAD           →  default_scope, siempre
   el AÑO       preferencia de quien mira     →  scope explícito
   el NIVEL     preferencia de quien mira     →  scope explícito
```

Con `default_scope` se rompen cosas que **tienen** que funcionar: el historial
de un alumno **cruza niveles por definición** —el mismo niño hace 6to Grado y
después 1er Año—, la constancia de un egresado de bachillerato se pide desde una
sesión que puede estar en primaria, y `School#niveles` —que es quien DECIDE qué
niveles ofrecer— tendría que consultar grados sin filtrar por el nivel que
todavía no eligió. Eso último es una recursión.

**Lo que se comporta distinto y hay que revisar uno por uno:**

- `Subscription.matricula_de` — cuenta alumnos para **facturar**. Si le entrara
  el filtro, un colegio de 360 alumnos con primaria elegida se factura como uno
  de 140. Es la peor consecuencia posible de este cambio y es silenciosa: la
  factura sale, más barata, y nadie la mira.
- `PasosDeArranque` — cuenta `Grade.count`, `Section.count`, `Student.count`.
  Si el nivel entrara ahí, un paso se pondría «pendiente» por estar mirando el
  nivel equivocado.
- `CargaDeMatricula` / `CargaDePensum` / `CargaDeHistorial` — una planilla trae
  varios niveles. El importador **nunca** filtra.
- `CopiarLaEstructura` y `PromoverAlumnos` — copian y promueven el año entero.
  Promover solo primaria dejaría bachillerato sin inscribir en septiembre, y el
  director no tendría cómo saberlo.
- `School#niveles` usa `Grade.unscoped` a propósito (MOR-160). No se toca.

**Guardas que podrían dejar de guardar en silencio:**

- `bin/smoke` recorre 18 pantallas y asegura 200. Un nivel en sesión no cambia
  el código de respuesta: si el filtro dejara una lista vacía, el humo pasa.
- `cabecera_de_lista_test` cuenta `.cabecera-de-lista--compacta`. Si `/grados`
  gana un control por el nivel, deja de ser compacta y el test lo va a decir —
  bien.
- Los tests que usan `dos_colegios_completos` cuentan filas. Con «Todos» por
  defecto **ninguno cambia**; es el segundo argumento para ese valor por
  defecto, y desaparece si se elige otro.
- `anio_escolar_de_la_sesion_test` y `barra_de_contexto_test` afirman qué hay en
  la barra. Van a fallar y está bien: la barra cambia.

## 8 · Cómo se verifica

- `bin/ci` — completo, verde antes de abrir el PR.
- Un test de integración nuevo, `nivel_de_la_sesion_test`, con los once
  criterios de § 6.
- ⚠️ Un test de **sistema** (Chrome de verdad) para dos cosas que no se ven
  leyendo el HTML: que el selector se envíe solo al cambiar —es el mismo
  `auto-envio` del año, y un target de Stimulus fuera del elemento del
  controlador ya falló en silencio una vez— y que con tres controles la barra no
  desborde en un teléfono.
- A mano: entrar como director de un colegio con los tres niveles, elegir
  primaria, y recorrer secciones → inscripciones → notas → boletines
  comprobando que el conteo dice «de Primaria» en todas.
