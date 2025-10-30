# frozen_string_literal: true

class DnsCheckJob < ApplicationJob
  queue_as :default

  def perform(dns_watch_id)
    dns_watch = DnsWatch.find(dns_watch_id)
    resolver = DnsResolver.new
    now = Time.current

    current_value = begin
      resolver.resolve(dns_watch.domain, dns_watch.record_type, dns_watch.record_name)
    rescue DnsResolver::ResolutionError => e
      Rails.logger.warn("DNS check failed for watch #{dns_watch.id}: #{e.message}")
      nil
    end

    dns_watch.with_lock do
      if current_value && dns_watch.last_value != current_value
        DnsChange.create!(
          dns_watch: dns_watch,
          detected_at: now,
          from_value: dns_watch.last_value,
          to_value: current_value
        )
        dns_watch.last_value = current_value
      end

      dns_watch.last_checked_at = now
      dns_watch.next_check_at = now + scheduled_interval_for(dns_watch)
      dns_watch.save!
    end
  end

  private

  def scheduled_interval_for(dns_watch)
    if dns_watch.respond_to?(:check_interval_minutes) && dns_watch.check_interval_minutes
      dns_watch.check_interval_minutes.minutes
    else
      dns_watch.interval_seconds.seconds
    end
  end
end
