# Deployment Guide

This guide covers deploying dns2rss to production environments.

## Prerequisites

- Ruby 3.2.3
- PostgreSQL 13+
- Redis (optional, for background job processing with Sidekiq)
- Docker (optional, for containerized deployment)

## Environment Variables

Configure these environment variables for production:

```bash
# Database
DATABASE_URL=postgresql://user:password@hostname:5432/dns2rss_production
# OR individual components:
POSTGRES_HOST=hostname
POSTGRES_PORT=5432
POSTGRES_DB=dns2rss_production
POSTGRES_USER=user
POSTGRES_PASSWORD=password

# Rails
RAILS_ENV=production
RAILS_MASTER_KEY=your-master-key-here
RAILS_LOG_TO_STDOUT=true
RAILS_SERVE_STATIC_FILES=true  # If not using a CDN/proxy

# DNS checking
DNS_CHECK_INTERVAL_MINUTES=5  # How often to check for DNS changes

# Optional: Redis for Sidekiq
REDIS_URL=redis://hostname:6379/0
```

## Deployment Steps

### 1. Prepare the server

```bash
# Update system packages
sudo apt-get update
sudo apt-get install -y build-essential libpq-dev postgresql-client

# Install Ruby 3.2.3 (using rbenv or rvm)
rbenv install 3.2.3
rbenv global 3.2.3
```

### 2. Clone and setup application

```bash
# Clone repository
git clone https://github.com/yourusername/dns2rss.git
cd dns2rss

# Install dependencies
bundle install --without development test

# Setup database
RAILS_ENV=production bin/rails db:create db:migrate

# Precompile assets
RAILS_ENV=production bin/rails assets:precompile
```

### 3. Configure credentials

```bash
# Edit encrypted credentials
EDITOR="vim" bin/rails credentials:edit

# Add production secrets:
# production:
#   secret_key_base: <generated-by-rails>
#   postgres:
#     password: your-db-password
```

### 4. Setup background jobs

#### Option A: Using Active Job async adapter (simple, for small deployments)

No additional setup needed. Jobs run inline.

#### Option B: Using Sidekiq (recommended for production)

1. Add to Gemfile:
```ruby
gem 'sidekiq', '~> 7.0'
```

2. Configure in `config/application.rb`:
```ruby
config.active_job.queue_adapter = :sidekiq
```

3. Create `config/sidekiq.yml`:
```yaml
:concurrency: 5
:queues:
  - default
  - mailers
```

4. Start Sidekiq:
```bash
bundle exec sidekiq -C config/sidekiq.yml
```

### 5. Setup cron scheduler

The application uses `whenever` to manage cron jobs for periodic DNS checks.

```bash
# Update crontab
bundle exec whenever --update-crontab --set environment=production

# Verify installation
bundle exec whenever

# Check cron logs
tail -f log/cron.log
```

The default schedule checks for due DNS watches every 5 minutes (configurable via `DNS_CHECK_INTERVAL_MINUTES`).

### 6. Start the application

#### Using Puma directly:

```bash
RAILS_ENV=production bundle exec puma -C config/puma.rb
```

#### Using systemd service:

Create `/etc/systemd/system/dns2rss.service`:

```ini
[Unit]
Description=dns2rss Rails Application
After=network.target postgresql.service

[Service]
Type=simple
User=deploy
WorkingDirectory=/home/deploy/dns2rss
Environment="RAILS_ENV=production"
Environment="RAILS_LOG_TO_STDOUT=true"
EnvironmentFile=/home/deploy/dns2rss/.env
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable dns2rss
sudo systemctl start dns2rss
sudo systemctl status dns2rss
```

#### Using Docker:

```bash
# Build image
docker build --build-arg RAILS_ENV=production -t dns2rss:latest .

# Run with Docker Compose
docker compose -f docker-compose.yml up -d
```

## Docker Deployment

The application includes Docker support with multi-stage builds for production.

### Build production image

```bash
docker build \
  --build-arg RAILS_ENV=production \
  --build-arg BUNDLE_WITHOUT=development:test \
  -t dns2rss:latest .
```

### Run services

The `docker-compose.yml` defines three services:

1. **web** – Rails application server (port 3000)
2. **cron** – Cron scheduler for DNS checks
3. **db** – PostgreSQL database

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f web
docker compose logs -f cron

# Run migrations
docker compose exec web bin/rails db:migrate

# Access Rails console
docker compose exec web bin/rails console
```

### Environment configuration for Docker

Create a `.env` file in the project root:

```bash
POSTGRES_HOST=db
POSTGRES_PORT=5432
POSTGRES_DB=dns2rss_production
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-secure-password
RAILS_MASTER_KEY=your-master-key
DNS_CHECK_INTERVAL_MINUTES=5
```

## Web Server Configuration

### Nginx reverse proxy

Create `/etc/nginx/sites-available/dns2rss`:

```nginx
upstream dns2rss {
  server 127.0.0.1:3000 fail_timeout=0;
}

server {
  listen 80;
  server_name dns2rss.example.com;

  # Redirect to HTTPS
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name dns2rss.example.com;

  ssl_certificate /etc/letsencrypt/live/dns2rss.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/dns2rss.example.com/privkey.pem;

  root /home/deploy/dns2rss/public;

  location / {
    proxy_pass http://dns2rss;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
  }

  location ~ ^/(assets|packs)/ {
    expires 1y;
    add_header Cache-Control public;
    add_header ETag "";
    break;
  }

  location /up {
    proxy_pass http://dns2rss;
    access_log off;
  }
}
```

Enable and reload:

```bash
sudo ln -s /etc/nginx/sites-available/dns2rss /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Monitoring and Maintenance

### Health checks

The application provides a health check endpoint at `/up`:

```bash
curl https://dns2rss.example.com/up
```

Returns `200 OK` when the application is healthy.

### Log monitoring

```bash
# Application logs
tail -f log/production.log

# Cron logs
tail -f log/cron.log

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Database maintenance

```bash
# Vacuum and analyze
RAILS_ENV=production bin/rails db:vacuum

# Backup database
pg_dump -U postgres -h localhost dns2rss_production > backup-$(date +%Y%m%d).sql

# Restore database
psql -U postgres -h localhost dns2rss_production < backup-20240101.sql
```

### Rotate logs

Create `/etc/logrotate.d/dns2rss`:

```
/home/deploy/dns2rss/log/*.log {
  daily
  missingok
  rotate 7
  compress
  delaycompress
  notifempty
  copytruncate
}
```

## Scaling Considerations

### Horizontal scaling

To run multiple web server instances:

1. Use a load balancer (nginx, HAProxy, AWS ELB)
2. Ensure sessions are stored in a shared store (Redis, database)
3. Run the cron scheduler on only ONE instance to avoid duplicate checks

### Database optimization

```sql
-- Add indexes for common queries
CREATE INDEX index_dns_watches_on_next_check_at ON dns_watches(next_check_at);
CREATE INDEX index_dns_changes_on_detected_at ON dns_changes(detected_at DESC);

-- Enable connection pooling in config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

### Caching

Enable caching in production with Redis:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

## Troubleshooting

### DNS checks not running

```bash
# Check cron is running
ps aux | grep cron

# Check whenever schedule
bundle exec whenever

# Check cron logs
tail -f log/cron.log

# Manually trigger DNS check
RAILS_ENV=production bundle exec rake dns:enqueue_due
```

### Database connection errors

```bash
# Test connection
RAILS_ENV=production bin/rails db:version

# Check credentials
RAILS_ENV=production bin/rails credentials:show

# Verify DATABASE_URL
echo $DATABASE_URL
```

### Memory issues

```bash
# Monitor memory usage
free -h
ps aux --sort=-%mem | head -n 10

# Configure Puma workers in config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
```

## Security Checklist

- [ ] Set strong `secret_key_base` in credentials
- [ ] Use HTTPS in production
- [ ] Keep `RAILS_MASTER_KEY` secure
- [ ] Use strong database passwords
- [ ] Enable database SSL connections
- [ ] Configure firewall rules (only allow 80/443)
- [ ] Regular security updates: `bundle update`
- [ ] Monitor application logs for suspicious activity
- [ ] Set up fail2ban for SSH protection
- [ ] Use environment variables for all secrets
- [ ] Enable database backups
- [ ] Configure rate limiting (rack-attack)

## Additional Resources

- [Rails Production Guide](https://guides.rubyonrails.org/production.html)
- [Puma Configuration](https://github.com/puma/puma)
- [Sidekiq Best Practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices)
- [Whenever Gem Documentation](https://github.com/javan/whenever)
