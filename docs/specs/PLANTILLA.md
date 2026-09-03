# MOR-000 · Título en una línea

> **Estado:** borrador · en discusión · **congelado** · en construcción · entregado
> **PR:** —

Un spec se escribe ANTES de la primera línea de código y se **congela** antes de
empezar. Si algo cambia después, se cambia acá primero.

---

## 1 · El problema

Qué NO puede hacer hoy un director, un profesor o una madre. En sus palabras
cuando se tengan: una cita textual vale más que un párrafo nuestro.

> *«los 8 pasos son engorrosos incluso para mí, que tengo todo el contexto»*

⚠️ El problema, no la solución. Si esta sección ya dice «hay que agregar un
botón», el spec empezó por el final.

## 2 · Qué NO entra

El límite, escrito. Es la sección que evita que un issue de tres días se vuelva
de dos semanas.

```
   ENTRA                          NO ENTRA
   ─────                          ────────
   …                              …  (y por qué: otro issue, otra discusión)
```

## 3 · Las decisiones

Las preguntas que hay que responder **antes** de programar, con su respuesta y
quién la tomó. Una pregunta abierta acá es un spec que todavía no se congela.

| # | Pregunta | Decisión | Quién |
|---|----------|----------|-------|
| 1 | | | |

## 4 · El dominio

Qué dice la ley, el MPPE o el negocio. Es lo que un programador no puede
deducir del código y lo que hace que SIGA sea correcto y no solo funcional.

- Artículo / circular / decisión de producto que aplica
- ⚠️ Lo que parece razonable y está mal

## 5 · Cómo se ve

Wireframes ASCII. **Antes / después** cuando algo cambia de forma.

```
   ANTES                          DESPUÉS
   ─────                          ───────
```

## 6 · Criterios de aceptación

Frases verificables, en el orden en que se van a probar. **Cada una se convierte
en un test**; si una no se puede escribir como test, está mal redactada.

- [ ] Dado … cuando … entonces …
- [ ] …

## 7 · Lo que se puede romper

⚠️ **La sección que más tiempo ahorra.** Qué se comporta distinto después de
esto, qué test va a fallar y por qué está bien que falle.

- `…` — qué asumía, por qué deja de ser cierto
- Guardas que podrían **dejar de guardar** en silencio: una prueba que apunta a
  una clase CSS, a una ruta o a un texto que este cambio mueve, deja de probar
  sin fallar.

## 8 · Cómo se verifica

Qué se corre y qué se mira. `bin/ci` siempre; lo que necesite navegador va como
test de sistema, porque hay cosas —un formulario que no se puede enviar, un
tooltip recortado, un target de Stimulus mal ubicado— que **no se ven leyendo el
HTML**.
