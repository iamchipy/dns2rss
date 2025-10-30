# frozen_string_literal: true

require "rspec"
require "active_record"
require "sqlite3"
require "bcrypt"
require "securerandom"
require "active_job"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/object/blank"
require "active_support/testing/time_helpers"
require "logger"

ActiveJob::Base.queue_adapter = :test

module Rails
  def self.logger
    @logger ||= Logger.new($stdout)
  end
end unless defined?(Rails)

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")

load File.expand_path("../db/schema.rb", __dir__)

Dir[File.expand_path("../app/models/**/*.rb", __dir__)].sort.each { |file| require file }
Dir[File.expand_path("../app/services/**/*.rb", __dir__)].sort.each { |file| require file }
Dir[File.expand_path("../app/jobs/**/*.rb", __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include ActiveSupport::Testing::TimeHelpers

  config.order = :random

  config.around do |example|
    ActiveRecord::Base.connection.transaction(joinable: false) do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
