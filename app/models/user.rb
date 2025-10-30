# frozen_string_literal: true

require "bcrypt"
require "securerandom"
require "uri"

class User < ApplicationRecord
  has_many :dns_watches, dependent: :destroy
  has_many :dns_changes, through: :dns_watches

  has_secure_password

  before_validation :normalize_email
  before_validation :ensure_feed_token

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :feed_token, presence: true, uniqueness: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def ensure_feed_token
    self.feed_token ||= generate_unique_feed_token
  end

  def generate_unique_feed_token
    loop do
      token = SecureRandom.hex(16)
      break token unless self.class.exists?(feed_token: token)
    end
  end
end
