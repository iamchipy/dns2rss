# frozen_string_literal: true

# Use this file to easily define all of your cron jobs using the Whenever DSL.
# Learn more: https://github.com/javan/whenever

set :output, "log/cron.log"
set :environment, ENV.fetch("RAILS_ENV", "development")

# Placeholder job to demonstrate scheduling. Replace or remove once real DNS
# polling logic is implemented.
every 10.minutes do
  runner "Rails.logger.debug('dns2rss cron heartbeat')"
end
