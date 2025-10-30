# frozen_string_literal: true

# Use this file to easily define all of your cron jobs using the Whenever DSL.
# Learn more: https://github.com/javan/whenever

require "active_support/core_ext/numeric/time"

set :output, "log/cron.log"
set :environment, ENV.fetch("RAILS_ENV", "development")

dns_check_interval = [ENV.fetch("DNS_CHECK_INTERVAL_MINUTES", "5").to_i, 1].max

every dns_check_interval.minutes do
  rake "dns:enqueue_due"
end
