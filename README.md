# dns2rss

A Rails 7 single-page foundation for monitoring DNS records and syndicating changes through RSS feeds. The application ships with Turbo/Stimulus via import maps, authenticated session support using `bcrypt`, RSS helpers, and a cron-ready schedule powered by `whenever`.

## Requirements

- Ruby 3.2.3
- Bundler 2.7+
- SQLite 3 for development/test
- PostgreSQL 13+ for production

If you plan to use Docker (recommended), the provided image bundles all runtime dependencies.

## Getting started (local machine)

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

The root path (`/`) renders the single-page shell at `HomeController#index`, ready to be extended with DNS monitoring UI components.

### Environment configuration

Copy `.env.sample` to `.env` (or export the variables in another way) and update the values to match your environment:

- `POSTGRES_*` variables configure production-grade PostgreSQL access.
- `DATABASE_URL` may be used instead of individual connection attributes.
- `RAILS_MASTER_KEY` should be set when running inside Docker so the container can decrypt credentials.

Credentials (encrypted in `config/credentials.yml.enc`) can store secrets such as the production PostgreSQL password. To edit them, run:

```bash
EDITOR="vim" bin/rails credentials:edit

# Example structure:
# postgres:
#   password: change-me
```

The database configuration will automatically prefer `POSTGRES_PASSWORD` and fall back to `Rails.application.credentials.dig(:postgres, :password)` when present.

### Cron scheduling

The project is pre-wired with `whenever`. Update `config/schedule.rb` with real DNS polling tasks, then refresh cron entries:

```bash
bundle exec whenever --update-crontab
tail -f log/cron.log
```

This writes a heartbeat job by default so you can confirm cron is functioning.

## Docker usage

A multi-stage `Dockerfile` builds a lean image that works for both development and production. To run everything (Rails app, PostgreSQL, and the cron scheduler) locally:

```bash
docker compose up --build
```

This launches two application containers:

- `web` – runs the Rails server on <http://localhost:3000>
- `cron` – installs the `whenever` schedule and keeps `cron` in the foreground

Environment values are sourced from your shell or a local `.env` file. Update the compose file if you need customised ports or credentials.

For production builds you can override the defaults, e.g.:

```bash
docker build --build-arg RAILS_ENV=production --build-arg BUNDLE_WITHOUT=development:test -t dns2rss:latest .
```

Run database migrations automatically when the container boots via the included `bin/docker-entrypoint` script.

## Running tests

Execute the default Rails test suite with:

```bash
bin/rails test
```

## Next steps

- Flesh out DNS record watchers, persistence, and RSS feed publishing.
- Replace the placeholder Stimulus controller (`hello_controller.js`) with real interactions.
- Implement real cron-driven jobs in `config/schedule.rb` that sync DNS changes and broadcast them to RSS feeds.
