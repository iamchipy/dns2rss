# frozen_string_literal: true

require "spec_helper"

RSpec.describe DnsWatch do
  let(:user) { User.create!(email: "owner@example.com", password: "password123", password_confirmation: "password123") }

  subject(:watch) do
    described_class.new(
      user: user,
      domain: "example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 600,
      next_check_at: Time.now - 60
    )
  end

  it "is valid with default attributes" do
    expect(watch).to be_valid
  end

  it "requires a user" do
    watch.user = nil
    expect(watch).not_to be_valid
    expect(watch.errors[:user]).to include("must exist")
  end

  it "requires a domain" do
    watch.domain = nil
    expect(watch).not_to be_valid
  end

  it "requires a record type from the allowed list" do
    watch.record_type = "INVALID"
    expect(watch).not_to be_valid
    expect(watch.errors[:record_type]).to include("is not included in the list")
  end

  it "requires a record name" do
    watch.record_name = nil
    expect(watch).not_to be_valid
    expect(watch.errors[:record_name]).to include("can't be blank")
  end

  it "requires a positive interval" do
    watch.interval_seconds = 0
    expect(watch).not_to be_valid
    expect(watch.errors[:interval_seconds]).to include("must be greater than 0")
  end

  it "defaults interval seconds when not provided" do
    watch.interval_seconds = nil
    watch.valid?

    expect(watch.interval_seconds).to eq(300)
  end

  it "normalizes domain and record type" do
    watch.domain = "Example.COM "
    watch.record_type = "mx"
    watch.save!

    expect(watch.domain).to eq("example.com")
    expect(watch.record_type).to eq("MX")
  end

  it "prevents duplicate watches per user" do
    watch.save!

    duplicate = described_class.new(
      user: user,
      domain: watch.domain,
      record_type: watch.record_type,
      record_name: watch.record_name,
      interval_seconds: watch.interval_seconds,
      next_check_at: Time.now - 30
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:domain]).to include("has already been taken")
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "has many dns changes" do
    association = described_class.reflect_on_association(:dns_changes)
    expect(association.macro).to eq(:has_many)
  end

  describe ".due_for_check" do
    it "returns watches scheduled before now" do
      watch.save!

      future_watch = described_class.create!(
        user: user,
        domain: "future.example.com",
        record_type: "A",
        record_name: "@",
        interval_seconds: 600,
        next_check_at: Time.now + 3600
      )

      due_ids = described_class.due_for_check.pluck(:id)

      expect(due_ids).to include(watch.id)
      expect(due_ids).not_to include(future_watch.id)
    end
  end
end
