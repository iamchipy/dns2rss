# frozen_string_literal: true

namespace :dns do
  desc "Enqueue DNS checks for watches that are due"
  task enqueue_due: :environment do
    count = 0

    DnsWatch.due_for_check.find_each do |watch|
      DnsCheckJob.perform_later(watch.id)
      count += 1
    end

    puts "Enqueued #{count} DNS check(s)"
  end
end
