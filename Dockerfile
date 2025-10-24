# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.2.3
FROM registry.docker.com/library/ruby:${RUBY_VERSION}-slim AS base

ARG RAILS_ENV=production
ARG BUNDLE_WITHOUT=development:test

ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT}

WORKDIR /rails

# Core utilities shared across stages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ----------------------------------------------------------------------------
# Build stage - installs build tooling and compiles application assets.
# ----------------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs "$(nproc)" && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# ----------------------------------------------------------------------------
# Final stage - slim runtime image. Suitable for both development and prod.
# ----------------------------------------------------------------------------
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y cron libsqlite3-0 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
