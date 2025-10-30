# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# frozen_string_literal: true

require_relative "../config/environment"
require_relative "../app/models/application_record"
require_relative "../app/models/user"
require_relative "../app/models/dns_watch"
require_relative "../app/models/dns_change"

ActiveRecord::Base.transaction do
  demo_user = User.find_or_create_by!(email: "demo@example.com") do |user|
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  demo_user.dns_watches.find_or_create_by!(domain: "example.com", record_type: "A", record_name: "@") do |watch|
    watch.interval_seconds = 300
    watch.next_check_at = Time.now
    watch.last_checked_at = Time.now
    watch.last_value = "93.184.216.34"
  end
end
