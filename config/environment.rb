# frozen_string_literal: true

require "yaml"
require "active_record"
require "active_support"
require "active_support/core_ext/numeric/time"

config_path = File.expand_path("database.yml", __dir__)
config = YAML.load_file(config_path)

environment = ENV.fetch("APP_ENV", "development")
ActiveRecord::Base.establish_connection(config.fetch(environment))

if ActiveRecord::Base.connection.adapter_name.to_s.downcase.include?("sqlite")
  ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
end

ActiveSupport.to_time_preserves_timezone = true if ActiveSupport.respond_to?(:to_time_preserves_timezone=)
