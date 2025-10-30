# frozen_string_literal: true

require "spec_helper"

RSpec.describe User do
  subject(:user) do
    described_class.new(email: "user@example.com", password: "password123", password_confirmation: "password123")
  end

  it "is valid with default attributes" do
    expect(user).to be_valid
  end

  it "requires an email" do
    user.email = nil
    expect(user).not_to be_valid
    expect(user.errors[:email]).to include("can't be blank")
  end

  it "validates email uniqueness" do
    user.save!
    duplicate = described_class.new(email: user.email, password: "password123", password_confirmation: "password123")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "enforces case-insensitive uniqueness on email" do
    user.save!
    duplicate = described_class.new(email: "USER@EXAMPLE.COM", password: "password123", password_confirmation: "password123")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "normalizes email before saving" do
    user.email = " Example@Example.COM "
    user.save!

    expect(user.reload.email).to eq("example@example.com")
  end

  it "automatically generates a feed token" do
    expect(user.feed_token).to be_nil

    user.save!

    expect(user.feed_token).to be_present
    expect(user.feed_token.length).to be >= 10
  end

  it "generates unique feed tokens" do
    existing_token = "abc123token"
    described_class.create!(email: "existing@example.com", password: "password123", password_confirmation: "password123", feed_token: existing_token)

    user.save!

    expect(user.feed_token).not_to eq(existing_token)
  end

  it "requires a password" do
    user.password = user.password_confirmation = nil
    expect(user).not_to be_valid
    expect(user.errors[:password]).to be_present
  end

  it "has many dns watches" do
    association = described_class.reflect_on_association(:dns_watches)
    expect(association.macro).to eq(:has_many)
  end

  it "has many dns changes through watches" do
    association = described_class.reflect_on_association(:dns_changes)
    expect(association.macro).to eq(:has_many)
    expect(association.options[:through]).to eq(:dns_watches)
  end
end
