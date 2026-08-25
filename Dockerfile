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
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


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
