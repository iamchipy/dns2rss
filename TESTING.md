# Testing Guide

This document describes the testing strategy, setup, and best practices for the dns2rss application.

## Testing Framework

The application uses **RSpec** as the testing framework with the following key gems:

- `rspec-rails` - Rails integration for RSpec
- `capybara` - Integration testing and browser simulation
- `selenium-webdriver` - WebDriver implementation for browser testing

## Running Tests

### All tests

```bash
bundle exec rspec
```

### Using Rake tasks

```bash
rake test              # Run all tests
rake test:verbose      # Run tests with detailed output
rake test:models       # Run only model tests
rake test:controllers  # Run only controller tests
rake test:requests     # Run only request tests
rake test:jobs         # Run only job tests
rake test:services     # Run only service tests
```

### Specific files or examples

```bash
# Run a specific file
bundle exec rspec spec/models/user_spec.rb

# Run a specific example
bundle exec rspec spec/models/user_spec.rb:10

# Run tests matching a pattern
bundle exec rspec --pattern "spec/models/*_spec.rb"
```

## Test Structure

```
spec/
├── controllers/      # Controller unit tests
│   ├── sessions_controller_spec.rb
│   ├── users_controller_spec.rb
│   ├── dns_watches_controller_spec.rb
│   └── feeds_controller_spec.rb
├── models/          # Model unit tests
│   ├── user_spec.rb
│   ├── dns_watch_spec.rb
│   └── dns_change_spec.rb
├── requests/        # Integration/request tests
│   └── feeds_spec.rb
├── jobs/            # Background job tests
│   └── dns_check_job_spec.rb
├── services/        # Service object tests
│   └── dns_resolver_spec.rb
└── spec_helper.rb   # RSpec configuration
```

## Test Coverage

### Model Tests

**User (`spec/models/user_spec.rb`)**
- Email validation (presence, uniqueness, format)
- Email normalization (downcase, strip)
- Password validation (presence via has_secure_password)
- Feed token generation (automatic, unique)
- Associations (dns_watches, dns_changes)

**DnsWatch (`spec/models/dns_watch_spec.rb`)**
- Validations (domain, record_type, record_name, interval)
- Normalization (domain, record_type)
- Default values (interval_seconds, visibility, next_check_at)
- Uniqueness constraints (per user, per domain/type/name combination)
- Scopes (due_for_check, publicly_visible, visible_to)
- Instance methods (owner?, check_interval_minutes)
- Associations (user, dns_changes)

**DnsChange (`spec/models/dns_change_spec.rb`)**
- Validations (detected_at, to_value required; from_value optional)
- Associations (dns_watch)
- Delegations (user via dns_watch)

### Controller Tests

**SessionsController (`spec/controllers/sessions_controller_spec.rb`)**
- `GET #new`: Renders login form, redirects if already logged in
- `POST #create`: Successful login, failed login (wrong password, non-existent user)
- `DELETE #destroy`: Logout functionality, requires authentication
- Case-insensitive email matching
- Email whitespace handling

**UsersController (`spec/controllers/users_controller_spec.rb`)**
- `GET #new`: Renders signup form, redirects if already logged in
- `POST #create`: Successful registration with auto-login
- Email normalization on creation
- Validation errors (blank email, duplicate email, password mismatch)
- Feed token generation on creation

**DnsWatchesController (`spec/controllers/dns_watches_controller_spec.rb`)**
- `GET #index`: Shows public watches to guests, public + owned to logged-in users
- `GET #show`: Authorization (public watches visible to all, private only to owner)
- `POST #create`: Requires authentication, creates watch, validates attributes
- `PATCH #update`: Requires ownership, updates attributes, validates changes
- `DELETE #destroy`: Requires ownership, cascades to dns_changes
- Domain/record type normalization
- Interval conversion (minutes to seconds)

**FeedsController (`spec/controllers/feeds_controller_spec.rb`)**
- Authentication via feed_token parameter
- RSS content type headers
- Basic endpoint accessibility

### Request Tests

**Feeds (`spec/requests/feeds_spec.rb`)**
- `GET /feeds/public.rss`: Public RSS feed with correct content-type
- Includes only public watches, excludes private watches
- Orders by detected_at descending
- Generates valid RSS 2.0 XML
- `GET /feeds/user.rss`: User-specific feed with authentication
- Requires valid feed_token
- Includes all user's watches (public and private)
- `GET /feeds/watch/:id.rss`: Watch-specific feed
- Requires owner's feed_token
- Returns 403 for other users' tokens
- Returns 404 for non-existent watches

### Job Tests

**DnsCheckJob (`spec/jobs/dns_check_job_spec.rb`)**
- Creates DnsChange when value is new or changed
- Updates watch timestamps (last_checked_at, next_check_at)
- Does not create DnsChange when value is unchanged
- Handles DNS resolution errors gracefully
- Supports multiple record types (A, AAAA, MX, TXT, etc.)
- Uses watch's configured check interval
- Thread-safe with database locking

### Service Tests

**DnsResolver (`spec/services/dns_resolver_spec.rb`)**
- Resolves various record types (A, AAAA, CNAME, MX, NS, TXT, SRV)
- Builds FQDNs correctly (handles @, subdomains, trailing dots)
- Canonicalizes results (sorts, deduplicates, formats)
- Raises ResolutionError for unsupported types
- Handles DNS query failures

## Test Configuration

### spec_helper.rb

Key configurations:

```ruby
ENV["RAILS_ENV"] = "test"

# Transaction-based rollback for database isolation
config.around do |example|
  ActiveRecord::Base.connection.transaction(joinable: false) do
    example.run
    raise ActiveRecord::Rollback
  end
end

# Time helpers for freezing time in tests
config.include ActiveSupport::Testing::TimeHelpers

# Random test order
config.order = :random
```

### Test Database

- SQLite in test environment
- Automatic schema loading via `ActiveRecord::Migration.maintain_test_schema!`
- Transaction rollback after each test (no DatabaseCleaner needed)

## Writing Tests

### General Guidelines

1. **Use `let` for test data**: Lazy-load test objects
2. **Use `let!` for records needed before test runs**
3. **One expectation per test when possible**: Makes failures clearer
4. **Use descriptive contexts**: `context "when authenticated"`, `context "with invalid params"`
5. **Test the happy path and edge cases**: Success, validation failures, authorization failures
6. **Freeze time when testing timestamps**: `freeze_time do ... end`

### Example Test Pattern

```ruby
RSpec.describe MyModel do
  let(:user) { User.create!(email: "test@example.com", password: "password123") }
  
  subject(:my_model) do
    described_class.new(
      user: user,
      attribute: "value"
    )
  end
  
  describe "validations" do
    it "is valid with default attributes" do
      expect(my_model).to be_valid
    end
    
    it "requires an attribute" do
      my_model.attribute = nil
      expect(my_model).not_to be_valid
      expect(my_model.errors[:attribute]).to include("can't be blank")
    end
  end
  
  describe "#method_name" do
    it "does something" do
      result = my_model.method_name
      expect(result).to eq("expected value")
    end
  end
end
```

### Controller Test Pattern

```ruby
RSpec.describe MyController, type: :controller do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }
  
  describe "GET #show" do
    context "when authenticated" do
      before do
        session[:user_id] = user.id
      end
      
      it "returns success" do
        get :show, params: { id: 1 }
        
        expect(response).to be_successful
        expect(assigns(:resource)).to be_present
      end
    end
    
    context "when not authenticated" do
      it "redirects to login" do
        get :show, params: { id: 1 }
        
        expect(response).to redirect_to(login_path)
      end
    end
  end
end
```

### Request Test Pattern

```ruby
RSpec.describe "MyResource", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }
  
  describe "GET /my_resource" do
    it "returns JSON" do
      get my_resource_path, headers: { "Accept" => "application/json" }
      
      expect(response).to be_successful
      expect(response.content_type).to match(/application\/json/)
    end
  end
end
```

## Continuous Integration

Tests run automatically on:
- Every push to `main` branch
- All pull requests

### GitHub Actions Workflow

The CI pipeline (`.github/workflows/ci.yml`) includes:

1. **Test Job**
   - PostgreSQL 13 service
   - Ruby 3.2.3 setup with bundler caching
   - Database creation and schema loading
   - Full RSpec test suite

2. **Lint Job**
   - RuboCop with Rails extensions
   - Parallel execution for speed

### Running CI Locally

To simulate CI environment:

```bash
# Run tests with PostgreSQL (similar to CI)
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/dns2rss_test \
  RAILS_ENV=test \
  bundle exec rspec

# Run linting
bundle exec rubocop --parallel
```

## Debugging Tests

### Interactive debugging

Add `binding.pry` or `debugger` in test code:

```ruby
it "does something" do
  debugger  # or binding.pry
  expect(result).to eq("value")
end
```

### Verbose output

```bash
bundle exec rspec --format documentation
```

### Focused tests

Run only specific tests:

```ruby
# Focus on one example
it "does something", :focus do
  # test code
end

# Skip an example
xit "does something" do
  # test code
end
```

Then run: `bundle exec rspec --tag focus`

### Database inspection

```ruby
it "creates a record" do
  pp User.all  # Pretty print all users
  expect(User.count).to eq(1)
end
```

## Test Performance

### Slow tests

Identify slow tests:

```bash
bundle exec rspec --profile 10
```

### Improving performance

- Use `let` instead of `before` when possible (lazy loading)
- Minimize database queries
- Use factories instead of multiple `create!` calls
- Avoid unnecessary HTTP requests in tests

## Coverage Tools

To add test coverage reporting, consider adding:

```ruby
# Gemfile
group :test do
  gem 'simplecov', require: false
end

# spec/spec_helper.rb (at the very top)
require 'simplecov'
SimpleCov.start 'rails'
```

Then run tests and check `coverage/index.html`.

## Common Issues

### Database not reset between tests

If tests fail due to leftover data:

```bash
RAILS_ENV=test bin/rails db:reset
```

### Factory/fixture conflicts

Ensure unique attributes in test data:

```ruby
let(:user) { User.create!(email: "user-#{SecureRandom.hex(4)}@example.com") }
```

### Flaky tests

- Check for time-dependent logic (use `freeze_time`)
- Check for random data (use seeds)
- Check for asynchronous operations (use `wait_for` or similar)

## Best Practices

1. **Test behavior, not implementation**: Focus on what the code does, not how
2. **Keep tests simple**: One clear expectation per test
3. **Use descriptive test names**: Should read like documentation
4. **Avoid testing Rails**: Don't test validations that Rails provides
5. **Test edge cases**: Empty strings, nil values, boundary conditions
6. **Test authorization**: Who can access what
7. **Test authentication**: Logged in vs logged out behavior
8. **Test validations**: All validation rules
9. **Test associations**: Dependent destroys, presence
10. **Test custom methods**: Any method you write should have tests

## Resources

- [RSpec Documentation](https://rspec.info/)
- [RSpec Rails](https://github.com/rspec/rspec-rails)
- [Capybara](https://github.com/teamcapybara/capybara)
- [Better Specs](https://www.betterspecs.org/)
