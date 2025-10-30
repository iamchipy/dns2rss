# frozen_string_literal: true

class DnsChange < ApplicationRecord
  belongs_to :dns_watch

  delegate :user, to: :dns_watch

  validates :detected_at, presence: true
  validates :to_value, presence: true
end
