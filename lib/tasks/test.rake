# frozen_string_literal: true

namespace :test do
  desc "Run all RSpec tests"
  task :all do
    system("bundle exec rspec")
  end

  desc "Run RSpec tests with verbose output"
  task :verbose do
    system("bundle exec rspec --format documentation")
  end

  desc "Run only model tests"
  task :models do
    system("bundle exec rspec spec/models")
  end

  desc "Run only controller tests"
  task :controllers do
    system("bundle exec rspec spec/controllers")
  end

  desc "Run only request tests"
  task :requests do
    system("bundle exec rspec spec/requests")
  end

  desc "Run only job tests"
  task :jobs do
    system("bundle exec rspec spec/jobs")
  end

  desc "Run only service tests"
  task :services do
    system("bundle exec rspec spec/services")
  end
end

desc "Run RSpec tests (default)"
task test: "test:all"
