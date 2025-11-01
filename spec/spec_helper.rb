# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require "rspec"
require_relative "../config/environment"
require "rspec/rails"
require "capybara/rails"
require "capybara/rspec"
require "active_support/testing/time_helpers"

Capybara.default_driver = :rack_test

ActiveRecord::Migration.verbose = false
ActiveJob::Base.queue_adapter = :test
Rails.application.routes.default_url_options[:host] ||= "www.example.com"

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.order = :random

  config.around do |example|
    ActiveRecord::Base.connection.transaction(joinable: false) do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
