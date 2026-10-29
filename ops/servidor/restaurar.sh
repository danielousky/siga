#!/usr/bin/env bash
# Pone un volcado de PostgreSQL en la base de una app, y le devuelve las tablas
# a `siga_app`.
#
#   ssh siga-deploy postgres:export siga-db \
#     | ssh siga-casa 'sudo siga-ops/restaurar.sh siga'
#
# ⚠️ El orden no es negociable (references/SERVIDOR-PRODUCCION.md § 10):
#
#   montar.sh (el rol siga_app)  ──►  restaurar.sh  ──►  git push (el release verifica)
#
# Las tablas que trae un volcado quedan de quien lo restauró, `postgres`, y
# `FORCE ROW LEVEL SECURITY` solo somete al DUEÑO de la tabla. Si no se le
# devuelven a `siga_app`, el RLS de la app deja de evaluarse y nada lo avisa:
# los colegios se verían entre sí con todas las pantallas en verde.
#
# Se niega a pisar una base que ya tiene tablas, salvo con FORZAR=1.
set -euo pipefail

app=${1:?uso: … | restaurar.sh <app>}
servicio="$app-db"
base=${servicio//-/_}
contenedor="dokku.postgres.$servicio"

falla() { echo "✗ $*" >&2; exit 1; }
sql() { docker exec -i "$contenedor" psql -U postgres -d "$base" -v ON_ERROR_STOP=1 -tA "$@"; }

[ "$(id -u)" = 0 ] || falla "Corre como root"
docker inspect "$contenedor" >/dev/null 2>&1 || falla "No existe $servicio: primero montar.sh"

volcado=$(mktemp /var/tmp/siga-volcado.XXXXXX)
trap 'rm -f "$volcado"' EXIT
cat > "$volcado"
head -c 5 "$volcado" | grep -q PGDMP || falla "Lo que llegó no es un volcado de PostgreSQL (falta la firma PGDMP)"

tablas=$(sql -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
if [ "$tablas" != 0 ]; then
  [ "${FORZAR:-}" = 1 ] || falla "$base ya tiene $tablas tablas. Para pisarla de verdad: FORZAR=1"
  # La base se vacía entera y el esquema vuelve a ser del dueño de la base
  # (siga_app): restaurar encima dejaría las tablas viejas mezcladas.
  sql -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public AUTHORIZATION pg_database_owner;" >/dev/null
fi

# Sin dueños ni permisos del servidor de origen: aquí el dueño lo decide el
# paso siguiente, no el volcado.
docker exec -i "$contenedor" pg_restore -U postgres -d "$base" --no-owner --no-acl --exit-on-error < "$volcado"

sql >/dev/null <<'SQL'
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT format('ALTER TABLE public.%I OWNER TO siga_app', tablename) AS q
           FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE r.q;  -- arrastra las secuencias de sus columnas
  END LOOP;
  FOR r IN SELECT format('ALTER VIEW public.%I OWNER TO siga_app', viewname) AS q
           FROM pg_views WHERE schemaname = 'public' LOOP
    EXECUTE r.q;
  END LOOP;
  FOR r IN SELECT format('ALTER MATERIALIZED VIEW public.%I OWNER TO siga_app', matviewname) AS q
           FROM pg_matviews WHERE schemaname = 'public' LOOP
    EXECUTE r.q;
  END LOOP;
  -- Las secuencias sueltas: las de una columna ya cambiaron con su tabla, y
  -- cambiarlas aparte da error.
  FOR r IN SELECT format('ALTER SEQUENCE public.%I OWNER TO siga_app', c.relname) AS q
           FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'public' AND c.relkind = 'S'
             AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.objid = c.oid AND d.deptype IN ('a', 'i')) LOOP
    EXECUTE r.q;
  END LOOP;
  -- Funciones y tipos propios; los de una extensión (btree_gist) son de ella.
  FOR r IN SELECT format('ALTER ROUTINE %s OWNER TO siga_app', p.oid::regprocedure) AS q
           FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e') LOOP
    EXECUTE r.q;
  END LOOP;
  FOR r IN SELECT format('ALTER TYPE public.%I OWNER TO siga_app', t.typname) AS q
           FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
           WHERE n.nspname = 'public' AND t.typtype IN ('e', 'd')
             AND NOT EXISTS (SELECT FROM pg_depend d WHERE d.objid = t.oid AND d.deptype = 'e') LOOP
    EXECUTE r.q;
  END LOOP;
END $$;
SQL

ajenas=$(sql -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tableowner <> 'siga_app'")
[ "$ajenas" = 0 ] || falla "$ajenas tablas no son de siga_app: el RLS no las protegería"

total=$(sql -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
politicas=$(sql -c "SELECT count(*) FROM pg_policies WHERE schemaname = 'public'")
forzadas=$(sql -c "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = 'public' AND c.relforcerowsecurity")
colegios=$(sql -c "SELECT count(*) FROM schools")
personas=$(sql -c "SELECT count(*) FROM users")
echo "✓ $base: $total tablas de siga_app · $politicas políticas RLS · $forzadas con FORCE · $colegios colegios · $personas personas"
