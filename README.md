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

The project uses RSpec for testing. Execute the test suite with:

```bash
bundle exec rspec
```

Or use the provided rake tasks:

```bash
rake test              # Run all tests
rake test:verbose      # Run tests with detailed output
rake test:models       # Run only model tests
rake test:controllers  # Run only controller tests
rake test:requests     # Run only request tests
rake test:jobs         # Run only job tests
rake test:services     # Run only service tests
```

Run a specific test file:

```bash
bundle exec rspec spec/models/user_spec.rb
```

### Test coverage

The test suite includes:

- **Model tests**: User, DnsWatch, DnsChange validations and associations
- **Controller tests**: Authentication (SessionsController, UsersController), DNS watch CRUD operations (DnsWatchesController), and RSS feed generation (FeedsController)
- **Request tests**: End-to-end integration tests for RSS feeds with authentication
- **Job tests**: DnsCheckJob for DNS record monitoring and change detection
- **Service tests**: DnsResolver for DNS query operations

### Continuous Integration

GitHub Actions CI is configured to run:

- **Tests**: Full RSpec test suite with PostgreSQL
- **Linting**: RuboCop for code style checks

The CI workflow runs automatically on pushes to `main` and all pull requests.

## Background jobs

DNS monitoring runs via Active Job with the DnsCheckJob. When a watch is due for checking (based on `next_check_at`), the job:

1. Queries DNS records using the DnsResolver service
2. Compares the result with the last known value
3. Creates a DnsChange record if the value changed
4. Updates the watch's `last_checked_at` and `next_check_at` timestamps

To process background jobs in development:

```bash
bin/rails jobs:work
```

In production, configure a job queue adapter like Sidekiq, Resque, or Delayed Job in `config/application.rb`.

## Cron scheduling (production)

The project uses `whenever` to schedule periodic DNS checks. The schedule is defined in `config/schedule.rb` and defaults to checking every 5 minutes (configurable via `DNS_CHECK_INTERVAL_MINUTES` environment variable).

### Setting up cron (non-Docker)

On a production server, update the crontab:

```bash
bundle exec whenever --update-crontab
```

View the scheduled jobs:

```bash
bundle exec whenever
```

Remove the schedule:

```bash
bundle exec whenever --clear-crontab
```

### Cron with Docker

The Docker Compose setup includes a dedicated `cron` service that:

1. Installs the whenever schedule on container startup
2. Runs cron in the foreground
3. Logs output to `log/cron.log`

This service shares the Rails application code and database with the web service.

## Environment configuration

Copy `.env.sample` to `.env` and configure:

```bash
cp .env.sample .env
```

Key environment variables:

- **DATABASE_URL** or **POSTGRES_*** – Database connection details (PostgreSQL in production)
- **RAILS_MASTER_KEY** – For decrypting Rails credentials (required for production)
- **DNS_CHECK_INTERVAL_MINUTES** – Cron interval for DNS checks (default: 5)
- **RAILS_ENV** – Set to `production` for production deployments

### Rails credentials

Sensitive configuration (like production database passwords) can be stored in encrypted credentials:

```bash
EDITOR="vim" bin/rails credentials:edit
```

Example structure:

```yaml
postgres:
  password: your-secure-password
secret_key_base: your-secret-key
```

The database configuration automatically checks environment variables first, falling back to credentials.

## Deployment considerations

### Database migrations

Always run migrations before starting the application:

```bash
bin/rails db:migrate
```

The Docker entrypoint script (`bin/docker-entrypoint`) runs migrations automatically.

### Asset precompilation

For production deployments, precompile assets:

```bash
RAILS_ENV=production bin/rails assets:precompile
```

The Dockerfile handles this during the build process.

### Security

- Set a strong `secret_key_base` in production credentials
- Use HTTPS in production (configure via load balancer or reverse proxy)
- Keep `RAILS_MASTER_KEY` secure and never commit it to version control
- Regularly rotate user passwords and feed tokens
- Use strong PostgreSQL passwords

### Scaling

- **Web servers**: Run multiple Puma processes or containers behind a load balancer
- **Background jobs**: Increase job worker concurrency or add more worker processes
- **Cron**: Run the cron scheduler on a single instance to avoid duplicate DNS checks
- **Database**: Use PostgreSQL with connection pooling (configured in `config/database.yml`)

### Monitoring

- Monitor cron job execution: `tail -f log/cron.log`
- Monitor job queue: Check your job backend's admin UI (e.g., Sidekiq Web UI)
- Monitor DNS resolution errors: Check `log/production.log` for DnsResolver warnings
- Set up application monitoring (e.g., New Relic, Datadog, Honeybadger)

### Health checks

The application includes a `/up` health check endpoint that returns 200 when the app is running:

```bash
curl http://localhost:3000/up
```

Use this endpoint for load balancer health checks and uptime monitoring.

## API endpoints

### RSS feeds

The application provides three RSS feed endpoints:

1. **Public feed** – All changes from public watches: `/feeds/public.rss`
2. **User feed** – All changes from a user's watches (requires feed_token): `/feeds/user.rss?feed_token=YOUR_TOKEN`
3. **Watch feed** – Changes from a specific watch (requires feed_token): `/feeds/watch/:id.rss?feed_token=YOUR_TOKEN`

Each user has a unique `feed_token` generated automatically. Access it from the user profile or database.

## Next steps

- Set up a production job queue backend (Sidekiq recommended)
- Configure email notifications for DNS changes
- Add Slack/Discord webhook integrations
- Implement DNS record history visualization
- Add support for custom DNS resolvers
- Create admin dashboard for system monitoring
