# Imagen de producción para Dokku.
#
# Dokku detecta este archivo y construye con él en vez de usar un buildpack. Se
# eligió Dockerfile y no buildpack porque acá **la versión de PostgreSQL del
# cliente importa**: el aislamiento entre colegios se apoya en Row-Level Security
# (MOR-87), y conviene que lo que corre en el servidor sea exactamente lo que se
# probó.
#
#   docker build -t siga .
#   docker run --rm -p 3000:3000 -e SECRET_KEY_BASE=<...> siga
#
# Ver MOR-106.

ARG RUBY_VERSION=3.4.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# `curl` queda en la imagen final a propósito: Dokku consulta el health check.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client libvips42t64 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ⚠️ `libvips42t64` no es opcional aunque nada falle al arrancar.
#
# `image_processing` está en el Gemfile y `ActiveStorage.variant_processor` es
# `:vips`, pero la librería del sistema faltaba: cada arranque del contenedor
# escribía «Using vips to process variants requires the libvips library» y
# **cualquier miniatura reventaba en el momento de generarse**, no antes.
#
# Se notaba poco porque hasta ahora solo el escudo del colegio se redimensiona,
# y se dibuja en el PDF con Prawn —que no usa variantes—. Con las fotos de las
# personas pasa a ser la ruta normal: un avatar de 32 px servido en tamaño
# original es la foto entera de 3 MB, en cada fila de una lista de 360 alumnos.
#
# Va en la imagen BASE y no en la de construcción: la necesita el proceso que
# corre, no el que compila.
#
# El sufijo `t64` no es un capricho: la imagen es `ruby:3.4.9-slim`, o sea Debian
# 13 (trixie), donde los paquetes que exponen `time_t` en su ABI se renombraron
# por la transición a 64 bits. En bookworm el mismo paquete se llama `libvips42`
# a secas, así que si algún día se baja la imagen base hay que cambiarlo.


# ── Construcción ────────────────────────────────────────────────────────────
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# `SECRET_KEY_BASE_DUMMY` le dice a Rails que esto es solo para compilar assets:
# sin eso habría que pasarle la clave de verdad al build, y una clave de
# producción no tiene por qué estar en el contexto de una imagen.
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile


# ── Imagen final ────────────────────────────────────────────────────────────
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Sin root. Y `storage` y `db` son escribibles porque ahí van los adjuntos de
# Active Storage y el socket de Puma.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
