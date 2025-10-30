# frozen_string_literal: true

class DnsWatch < ApplicationRecord
  RECORD_TYPES = %w[A AAAA CNAME MX NS TXT SOA SRV].freeze
  VISIBILITIES = %w[public private].freeze

  belongs_to :user
  has_many :dns_changes, dependent: :destroy

  enum visibility: { public: "public", private: "private" }

  before_validation :normalize_domain
  before_validation :normalize_record_type
  before_validation :ensure_interval_seconds
  before_validation :ensure_next_check_at
  before_validation :ensure_visibility

  validates :domain, presence: true,
                     uniqueness: { scope: %i[user_id record_type record_name], case_sensitive: false }
  validates :record_type, presence: true, inclusion: { in: RECORD_TYPES }
  validates :record_name, presence: true
  validates :interval_seconds, numericality: { only_integer: true, greater_than: 0 }
  validates :next_check_at, presence: true
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }

  scope :due_for_check, -> { where("next_check_at <= ?", Time.now) }
  scope :publicly_visible, -> { where(visibility: visibilities[:public]) }
  scope :owned_by, ->(user) { where(user: user) }

  def self.visible_to(user)
    return publicly_visible unless user.present?

    publicly_visible.or(owned_by(user))
  end

  def check_interval_minutes
    interval_seconds.to_f / 60.0
  end

  def check_interval_minutes=(minutes)
    return if minutes.nil?

    numeric_minutes = minutes.to_f
    self.interval_seconds = (numeric_minutes * 60).to_i if numeric_minutes.positive?
  end

  def owner?(user)
    user.present? && user_id == user.id
  end

  private

  def normalize_domain
    self.domain = domain.to_s.strip.downcase if domain.present?
  end

  def normalize_record_type
    self.record_type = record_type.to_s.upcase if record_type.present?
  end

  def ensure_interval_seconds
    self.interval_seconds ||= 300
  end

  def ensure_next_check_at
    self.next_check_at ||= Time.now
  end

  def ensure_visibility
    self.visibility ||= self.class.visibilities[:public]
  end
end
