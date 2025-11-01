# dns2rss

A Rails 7 application for monitoring DNS records and syndicating changes through RSS feeds. Track DNS records for any domain, get notified of changes via RSS, and share public feeds or keep them private with personal feed tokens.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Running the Application](#running-the-application)
- [How It Works](#how-it-works)
- [Manual Testing Guide](#manual-testing-guide)
- [Background Job Scheduler](#background-job-scheduler)
- [Common Commands](#common-commands)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [Running Tests](#running-tests)
- [Docker Usage](#docker-usage)
- [Deployment](#deployment)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby 3.2.3** (check with `ruby -v`)
- **Bundler 2.7+** (check with `bundle -v`, install with `gem install bundler`)
- **SQLite 3** (for development/test environments)
- **Git** (for cloning the repository)

### Installing Ruby

If you don't have Ruby 3.2.3 installed, we recommend using a Ruby version manager:

**Using rbenv:**
```bash
rbenv install 3.2.3
rbenv local 3.2.3
```

**Using rvm:**
```bash
rvm install 3.2.3
rvm use 3.2.3
```

**Using asdf:**
```bash
asdf install ruby 3.2.3
asdf local ruby 3.2.3
```

### System Dependencies

**macOS:**
```bash
# SQLite comes pre-installed
# Install development tools if needed
xcode-select --install
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y build-essential sqlite3 libsqlite3-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install -y gcc make sqlite sqlite-devel
```

## Initial Setup

Follow these steps to get dns2rss running on your local machine:

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/dns2rss.git
cd dns2rss
```

### 2. Install dependencies

```bash
bundle install
```

This will install all required Ruby gems, including Rails 7.1.3, Turbo/Stimulus for the UI, bcrypt for authentication, and the RSS and whenever gems.

### 3. Set up the database

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

**What this does:**
- **db:create** - Creates the SQLite database file (development.sqlite3)
- **db:migrate** - Runs all database migrations to create the schema
- **db:seed** - Creates a demo user and sample DNS watch (optional but recommended for testing)

**Seed data created:**
- Demo user: `demo@example.com` / `password123`
- Sample DNS watch for `example.com` (A record)

### 4. Environment configuration (optional)

For local development, the defaults work fine. If you need to customize settings:

```bash
cp .env.sample .env
# Edit .env with your preferred settings
```

Key environment variables:
- `RAILS_ENV` - Set to `development` (default)
- `DNS_CHECK_INTERVAL_MINUTES` - How often to check DNS records via cron (default: 5 minutes)

## Running the Application

### Start the Rails server

```bash
bin/rails server
# or shorthand:
bin/rails s
```

The application will be available at **http://localhost:3000**

You should see:
```
=> Booting Puma
=> Rails 7.1.3 application starting in development
=> Run `bin/rails server --help` for more startup options
Puma starting in single mode...
* Listening on http://127.0.0.1:3000
```

### Access the application

Open your browser and navigate to **http://localhost:3000**

You'll see the DNS watches dashboard with:
- A form to create new DNS watches (left side)
- A list of monitored records (right side)
- Navigation to sign up or sign in (top right)

### Sign in with the demo account

1. Click "Sign In" in the top right
2. Use credentials:
   - Email: `demo@example.com`
   - Password: `password123`

Or create a new account by clicking "Sign Up".

## How It Works

dns2rss monitors DNS records and notifies you of changes via RSS feeds. Here's how the application works:

### User Registration and Authentication

1. **Sign Up**: Create an account with your email and password
2. **Feed Token**: Each user automatically gets a unique `feed_token` for accessing private RSS feeds
3. **Authentication**: Session-based authentication using secure password hashing (bcrypt)

### Creating DNS Watches

A DNS watch monitors a specific DNS record for changes. You can create watches for:

**Supported record types:**
- **A** - IPv4 addresses
- **AAAA** - IPv6 addresses
- **CNAME** - Canonical name records
- **MX** - Mail exchange records
- **NS** - Name server records
- **TXT** - Text records
- **SRV** - Service records
- **SOA** - Start of authority records

**Watch visibility:**

- **Public watches**: Visible to all users, changes appear in the public RSS feed
- **Private watches**: Only visible to you, changes only appear in your personal RSS feed

**Creating a watch:**

1. Fill out the form on the left side of the dashboard:
   - **Domain**: e.g., `example.com`, `google.com`
   - **Record Type**: Select from dropdown (A, AAAA, CNAME, etc.)
   - **Record Name**: 
     - Use `@` for the domain itself (e.g., `example.com`)
     - Use subdomain name (e.g., `www`, `mail`, `api`)
   - **Check Interval**: How often to check for changes (in minutes)
   - **Visibility**: Public or Private

2. Click "Create DNS watch"

**Examples:**
- Monitor `example.com` A record: Domain: `example.com`, Type: `A`, Name: `@`
- Monitor `www.example.com` CNAME: Domain: `example.com`, Type: `CNAME`, Name: `www`
- Monitor `example.com` MX records: Domain: `example.com`, Type: `MX`, Name: `@`

### Background DNS Checking Process

The application uses a background job system to periodically check DNS records:

1. **Cron scheduler** (via `whenever` gem) runs every 5 minutes (configurable)
2. **Rake task** (`dns:enqueue_due`) finds watches that are due for checking
3. **DnsCheckJob** performs the DNS lookup using the `DnsResolver` service
4. **Comparison**: Current DNS value is compared with the last known value
5. **Change detection**: If different, a `DnsChange` record is created
6. **Timestamps**: Watch is updated with `last_checked_at` and `next_check_at`

The process is automatic once watches are created, but you can manually trigger checks during development (see Manual Testing Guide).

### RSS Feed Access

dns2rss provides three types of RSS feeds:

#### 1. Public Feed
Access all changes from public watches (no authentication required):

```
http://localhost:3000/feeds/public.rss
```

#### 2. User Feed
Access all changes from your watches (public and private) using your feed token:

```
http://localhost:3000/feeds/user.rss?feed_token=YOUR_TOKEN
```

#### 3. Watch-Specific Feed
Access changes for a specific watch using your feed token:

```
http://localhost:3000/feeds/watch/WATCH_ID.rss?feed_token=YOUR_TOKEN
```

### Finding Your Feed Token

Your feed token is automatically generated when you create an account. To find it:

**Option 1: Rails Console**
```bash
bin/rails console
user = User.find_by(email: 'your@email.com')
puts user.feed_token
```

**Option 2: Database Query**
```bash
bin/rails console
User.find_by(email: 'demo@example.com').feed_token
# => "a1b2c3d4e5f6..."
```

**Option 3: Check Database Directly**
```bash
sqlite3 storage/development.sqlite3
SELECT feed_token FROM users WHERE email = 'demo@example.com';
```

### Feed Token Usage

Add your feed token to RSS reader apps like Feedly, Inoreader, NetNewsWire, or any RSS client:

```
http://localhost:3000/feeds/user.rss?feed_token=a1b2c3d4e5f6789...
```

**Security Note**: Keep your feed token private. Anyone with your token can access your private feeds.

## Manual Testing Guide

Here's how to test the application locally and see DNS monitoring in action:

### Step 1: Create a Test Watch

1. Sign in to the application
2. Create a DNS watch with the following settings:
   - **Domain**: `cloudflare.com`
   - **Record Type**: `A`
   - **Record Name**: `@`
   - **Check Interval**: `5` minutes
   - **Visibility**: `Public`

3. Click "Create DNS watch"

The watch will appear in the "Monitored records" list on the right.

### Step 2: Manually Trigger DNS Check

Instead of waiting for the cron job, manually trigger DNS checks:

```bash
bin/rails dns:enqueue_due
```

You should see output like:
```
Enqueued 1 DNS check(s)
```

### Step 3: Process Background Jobs

The DNS check job is queued but needs to be processed:

```bash
bin/rails jobs:work
```

This starts a worker that will process queued jobs. You should see:
```
[DnsCheckJob] [xxxxx-xxxxx-xxxxx] Performing DnsCheckJob...
[DnsCheckJob] [xxxxx-xxxxx-xxxxx] Performed DnsCheckJob...
```

**Note**: Press `Ctrl+C` to stop the worker when done. In production, this would run continuously.

### Step 4: Check for DNS Changes

Open the Rails console to see if changes were detected:

```bash
bin/rails console

# Check all DNS changes
DnsChange.all

# Check changes for a specific watch
watch = DnsWatch.find_by(domain: 'cloudflare.com')
watch.dns_changes

# View the current value
watch.last_value
```

If this is the first check, you'll see a DnsChange record with the initial value.

### Step 5: View Changes in RSS Feeds

Open your browser or RSS reader and access the public feed:

```
http://localhost:3000/feeds/public.rss
```

You should see an RSS feed with your DNS change entry including:
- Domain name
- Record type and name
- Previous value (or "no previous value" for first check)
- New value
- Detection timestamp

### Testing Different Record Types

Create watches for different record types to see how they work:

**A Record (IPv4):**
```
Domain: google.com
Type: A
Name: @
```

**AAAA Record (IPv6):**
```
Domain: google.com
Type: AAAA
Name: @
```

**CNAME Record:**
```
Domain: github.com
Type: CNAME
Name: www
```

**MX Record:**
```
Domain: gmail.com
Type: MX
Name: @
```

**TXT Record:**
```
Domain: google.com
Type: TXT
Name: @
```

**NS Record:**
```
Domain: cloudflare.com
Type: NS
Name: @
```

**SRV Record:**
```
Domain: example.com
Type: SRV
Name: _http._tcp
```

### Simulating a DNS Change

To see change detection in action:

1. Create a watch for a domain you control
2. Run the initial check: `bin/rails dns:enqueue_due && bin/rails jobs:work`
3. Change the DNS record at your DNS provider
4. Wait for DNS propagation (1-5 minutes typically)
5. Run another check: `bin/rails dns:enqueue_due && bin/rails jobs:work`
6. View the change in the RSS feed

## Background Job Scheduler

dns2rss uses the `whenever` gem to schedule periodic DNS checks via cron.

### How It's Configured

The schedule is defined in `config/schedule.rb`:

```ruby
every 5.minutes do
  rake "dns:enqueue_due"
end
```

This runs the `dns:enqueue_due` task every 5 minutes, which finds watches that need checking and enqueues background jobs for them.

### Check Interval Configuration

Customize the global check interval via environment variable:

```bash
# In .env or export in shell
export DNS_CHECK_INTERVAL_MINUTES=10
```

Individual watches can have their own check intervals set when creating/editing them.

### Running Scheduler in Development

In development, you have several options for running scheduled checks:

#### Option 1: Manual Execution (Recommended for Development)

Run the rake task manually when you want to check watches:

```bash
bin/rails dns:enqueue_due
```

Then process the jobs:

```bash
bin/rails jobs:work
```

#### Option 2: Install Crontab (Production-like)

Install the whenever schedule to your user's crontab:

```bash
bundle exec whenever --update-crontab
```

This installs the actual cron entries. View them with:

```bash
crontab -l
```

**View the generated cron schedule without installing:**
```bash
bundle exec whenever
```

**Remove the schedule:**
```bash
bundle exec whenever --clear-crontab
```

#### Option 3: Use Foreman/Overmind (Multiple Processes)

Create a `Procfile`:
```
web: bin/rails server
worker: bin/rails jobs:work
```

Then run with foreman:
```bash
gem install foreman
foreman start
```

### Cron Log Output

When using cron, output is logged to:
```
log/cron.log
```

Monitor it with:
```bash
tail -f log/cron.log
```

### Background Job Queue

By default, Rails uses the **async** adapter for Active Job (in-memory queue). This works fine for development but jobs are lost if the server restarts.

For production, configure a persistent queue adapter in `config/application.rb`:
- **Sidekiq** (recommended)
- **Resque**
- **Delayed Job**

See the [Deployment](#deployment) section for production setup.

## Common Commands

### Running the Application

```bash
# Start the server
bin/rails server

# Start on a different port
bin/rails server -p 3001

# Start in production mode
RAILS_ENV=production bin/rails server
```

### Database Operations

```bash
# Create database
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Rollback last migration
bin/rails db:rollback

# Reset database (drop, create, migrate)
bin/rails db:reset

# Seed database with sample data
bin/rails db:seed

# Reset and seed
bin/rails db:reset db:seed

# Drop database
bin/rails db:drop

# View migration status
bin/rails db:migrate:status
```

### Console and Debugging

```bash
# Open Rails console
bin/rails console
# or shorthand:
bin/rails c

# Open console in sandbox mode (rolls back all changes on exit)
bin/rails console --sandbox

# Check routes
bin/rails routes

# Check routes for a specific pattern
bin/rails routes | grep dns_watch

# View database schema
cat db/schema.rb
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test line
bundle exec rspec spec/models/user_spec.rb:23

# Run with documentation format
bundle exec rspec --format documentation

# Run tests matching a pattern
bundle exec rspec --pattern "spec/models/*_spec.rb"
```

See [TESTING.md](TESTING.md) for comprehensive testing documentation.

### Rake Tasks

```bash
# List all available rake tasks
bin/rails -T

# Enqueue due DNS checks
bin/rails dns:enqueue_due

# Process background jobs
bin/rails jobs:work

# View cron schedule
bundle exec whenever

# Update crontab
bundle exec whenever --update-crontab

# Clear crontab
bundle exec whenever --clear-crontab
```

### View Logs

```bash
# Development log
tail -f log/development.log

# Cron log
tail -f log/cron.log

# Test log
tail -f log/test.log

# Clear logs
bin/rails log:clear
```

### Code Quality

```bash
# Run RuboCop (linter)
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a

# Run RuboCop in parallel
bundle exec rubocop --parallel
```

### Credentials Management

```bash
# Edit encrypted credentials
EDITOR="vim" bin/rails credentials:edit

# Edit with different editor
EDITOR="code --wait" bin/rails credentials:edit

# View credentials (don't commit this!)
bin/rails credentials:show
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Rails is not currently installed"

**Solution:** Install Rails via bundler
```bash
gem install bundler
bundle install
```

#### Issue: "database does not exist"

**Solution:** Create and setup the database
```bash
bin/rails db:create db:migrate
```

#### Issue: "ActiveRecord::PendingMigrationError"

**Solution:** Run pending migrations
```bash
bin/rails db:migrate
```

#### Issue: "LoadError: cannot load such file -- bcrypt"

**Solution:** Ensure native extensions are compiled
```bash
bundle pristine bcrypt
# or rebuild all gems with native extensions
bundle pristine
```

#### Issue: SQLite "database is locked" error

**Solution:** SQLite doesn't handle high concurrency well. Either:
1. Close other connections to the database
2. Restart the Rails server
3. Delete the database file and recreate: `bin/rails db:reset`

### DNS Resolution Timeouts

**Symptoms:**
- Jobs taking a long time to complete
- Warning messages in logs: "DNS check failed for watch X: DNS resolution failed"

**Solutions:**

1. **Check your internet connection**
   ```bash
   ping 8.8.8.8
   ```

2. **Test DNS resolution manually**
   ```bash
   nslookup example.com
   dig example.com A
   ```

3. **Check DNS resolver configuration**
   - The app uses Ruby's `Resolv::DNS` which uses system DNS settings
   - On macOS: Check Network preferences > DNS servers
   - On Linux: Check `/etc/resolv.conf`

4. **Increase timeout** (if needed)
   Edit `app/services/dns_resolver.rb` and modify the resolver initialization

### Jobs Not Running

**Symptoms:**
- DNS checks are enqueued but never process
- No changes appear in RSS feeds

**Debugging steps:**

1. **Check if jobs are being enqueued:**
   ```bash
   bin/rails console
   DnsWatch.due_for_check.count
   # Should show watches that need checking
   ```

2. **Manually run the enqueue task:**
   ```bash
   bin/rails dns:enqueue_due
   # Should output: "Enqueued X DNS check(s)"
   ```

3. **Ensure job worker is running:**
   ```bash
   bin/rails jobs:work
   # This must be running to process jobs
   ```

4. **Check for errors in logs:**
   ```bash
   tail -f log/development.log
   ```

5. **Verify cron is running (if using whenever):**
   ```bash
   crontab -l  # Should show your scheduled tasks
   ps aux | grep cron  # Should show cron daemon
   ```

### Feed Access Issues

**Symptoms:**
- 401 Unauthorized when accessing user/watch feeds
- RSS feed returns empty or no items

**Solutions:**

1. **Verify feed token is correct:**
   ```bash
   bin/rails console
   user = User.find_by(email: 'your@email.com')
   puts user.feed_token
   ```

2. **Check URL format:**
   ```
   # Correct:
   http://localhost:3000/feeds/user.rss?feed_token=ABC123
   
   # Wrong:
   http://localhost:3000/feeds/user?feed_token=ABC123  # Missing .rss
   ```

3. **Verify watches have changes:**
   ```bash
   bin/rails console
   DnsChange.count  # Should be > 0
   ```

4. **Test public feed first:**
   ```
   http://localhost:3000/feeds/public.rss
   # Should work without authentication
   ```

### Server Won't Start

**Symptoms:**
- Error: "Address already in use - bind(2) for 127.0.0.1:3000"

**Solutions:**

1. **Kill the existing process:**
   ```bash
   # Find the process
   lsof -i :3000
   
   # Kill it (replace PID with actual process ID)
   kill -9 PID
   
   # Or use this one-liner
   kill -9 $(lsof -t -i:3000)
   ```

2. **Use a different port:**
   ```bash
   bin/rails server -p 3001
   ```

### Bundle Install Fails

**Solutions:**

1. **Update bundler:**
   ```bash
   gem install bundler
   bundle update --bundler
   ```

2. **Install system dependencies (Ubuntu/Debian):**
   ```bash
   sudo apt-get install -y build-essential libsqlite3-dev
   ```

3. **Clear bundle cache:**
   ```bash
   bundle clean --force
   rm -rf vendor/bundle
   bundle install
   ```

## Project Structure

Understanding the project layout will help you navigate and extend the application:

```
dns2rss/
├── app/
│   ├── assets/              # CSS, images, fonts
│   │   └── stylesheets/     # Application styles
│   ├── controllers/         # Request handlers
│   │   ├── application_controller.rb
│   │   ├── dns_watches_controller.rb   # CRUD for DNS watches
│   │   ├── feeds_controller.rb         # RSS feed generation
│   │   ├── sessions_controller.rb      # Sign in/out
│   │   └── users_controller.rb         # User registration
│   ├── helpers/             # View helpers
│   ├── javascript/          # Stimulus controllers
│   ├── jobs/                # Background jobs
│   │   └── dns_check_job.rb            # DNS monitoring job
│   ├── models/              # Data models
│   │   ├── dns_change.rb               # DNS change records
│   │   ├── dns_watch.rb                # DNS watch configuration
│   │   └── user.rb                     # User accounts
│   ├── services/            # Business logic
│   │   └── dns_resolver.rb             # DNS resolution service
│   └── views/               # HTML templates
│       ├── dns_watches/                # Watch management UI
│       ├── feeds/                      # RSS feed templates
│       ├── layouts/                    # Application layout
│       ├── sessions/                   # Sign in forms
│       └── users/                      # Sign up forms
├── bin/                     # Executables
│   ├── rails                           # Rails command runner
│   └── docker-entrypoint               # Docker startup script
├── config/                  # Configuration files
│   ├── database.yml                    # Database configuration
│   ├── routes.rb                       # URL routing
│   ├── schedule.rb                     # Cron schedule (whenever)
│   └── environments/                   # Environment-specific config
├── db/                      # Database files
│   ├── migrate/                        # Database migrations
│   ├── schema.rb                       # Current database schema
│   └── seeds.rb                        # Seed data
├── lib/
│   └── tasks/               # Custom rake tasks
│       └── dns.rake                    # DNS checking tasks
├── log/                     # Application logs
├── spec/                    # RSpec tests
│   ├── controllers/                    # Controller tests
│   ├── jobs/                           # Job tests
│   ├── models/                         # Model tests
│   ├── requests/                       # Integration tests
│   └── services/                       # Service tests
├── storage/                 # SQLite database files
│   └── development.sqlite3             # Development database
├── .env.sample              # Environment variable template
├── Gemfile                  # Ruby dependencies
├── README.md                # This file
├── TESTING.md               # Testing documentation
└── DEPLOYMENT.md            # Deployment guide
```

### Key Files and Their Purpose

**Models (app/models/):**
- **User** - User accounts with email/password authentication and feed tokens
- **DnsWatch** - DNS record monitoring configuration
- **DnsChange** - Records of detected DNS changes

**Controllers (app/controllers/):**
- **DnsWatchesController** - Create, view, update, delete DNS watches
- **FeedsController** - Generate RSS feeds (public, user, watch-specific)
- **SessionsController** - Handle user login/logout
- **UsersController** - Handle user registration

**Jobs (app/jobs/):**
- **DnsCheckJob** - Background job that checks DNS records and detects changes

**Services (app/services/):**
- **DnsResolver** - DNS resolution logic, supports A, AAAA, CNAME, MX, NS, TXT, SRV records

**Configuration:**
- **config/routes.rb** - URL routing definitions
- **config/schedule.rb** - Cron schedule for periodic DNS checks
- **config/database.yml** - Database connection settings
- **db/schema.rb** - Current database structure

**Tasks (lib/tasks/):**
- **dns.rake** - Contains `dns:enqueue_due` task for scheduling DNS checks

## Running Tests

The project uses RSpec for testing with comprehensive coverage of models, controllers, jobs, and services.

### Quick Start

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run specific test
bundle exec rspec spec/models/user_spec.rb:15
```

### Test Categories

```bash
# Run only model tests
bundle exec rspec spec/models

# Run only controller tests
bundle exec rspec spec/controllers

# Run only job tests
bundle exec rspec spec/jobs

# Run only service tests
bundle exec rspec spec/services

# Run only request/integration tests
bundle exec rspec spec/requests
```

### Test Coverage

The test suite covers:
- **Models**: Validations, associations, scopes, callbacks
- **Controllers**: CRUD operations, authentication, authorization
- **Jobs**: DNS checking, change detection, error handling
- **Services**: DNS resolution for all record types
- **Requests**: End-to-end RSS feed generation and access control

For detailed testing documentation, see [TESTING.md](TESTING.md).

## Docker Usage

For those who prefer Docker, the project includes a complete Docker setup.

### Quick Start with Docker

```bash
# Build and start all services
docker compose up --build

# Run in background
docker compose up -d

# Stop services
docker compose down
```

The Docker setup includes:
- **web** - Rails server on http://localhost:3000
- **cron** - Scheduled DNS checks via whenever
- **postgres** - PostgreSQL database (production-like)

### Docker Commands

```bash
# View logs
docker compose logs -f web
docker compose logs -f cron

# Run migrations
docker compose exec web bin/rails db:migrate

# Open Rails console
docker compose exec web bin/rails console

# Run tests
docker compose exec web bundle exec rspec

# Run a one-off command
docker compose run --rm web bin/rails db:seed
```

For more advanced Docker workflows (custom services, scaling, production images), refer to [`docker-compose.yml`](docker-compose.yml) and the [Deployment](#deployment) notes below.

## Deployment

For production deployment instructions, please refer to [DEPLOYMENT.md](DEPLOYMENT.md).

Key production considerations:
- Use PostgreSQL instead of SQLite
- Configure a job queue adapter (Sidekiq recommended)
- Set up the cron scheduler with `whenever`
- Use environment variables for configuration
- Enable HTTPS via reverse proxy
- Set strong credentials and keep `RAILS_MASTER_KEY` secure

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the test suite (`bundle exec rspec`)
5. Run RuboCop (`bundle exec rubocop`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Support

For issues and questions:
- Open an issue on GitHub
- Check [TESTING.md](TESTING.md) for testing guidelines
- Review [DEPLOYMENT.md](DEPLOYMENT.md) for production setup

## Credits

Built with:
- [Ruby on Rails 7.1](https://rubyonrails.org/)
- [Hotwire (Turbo + Stimulus)](https://hotwired.dev/)
- [Whenever](https://github.com/javan/whenever) for cron scheduling
- [bcrypt](https://github.com/bcrypt-ruby/bcrypt-ruby) for secure passwords
