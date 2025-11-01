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

  it "defaults visibility to public" do
    watch.visibility = nil
    watch.valid?

    expect(watch.visibility).to eq("public")
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

  describe ".visible_to" do
    let(:other_user) { User.create!(email: "viewer@example.com", password: "password123", password_confirmation: "password123") }

    let!(:public_watch) do
      described_class.create!(
        user: other_user,
        domain: "public.example.com",
        record_type: "A",
        record_name: "@",
        interval_seconds: 300,
        next_check_at: Time.now,
        visibility: "public"
      )
    end

    let!(:owned_private_watch) do
      described_class.create!(
        user: user,
        domain: "owned-private.example.com",
        record_type: "A",
        record_name: "@",
        interval_seconds: 300,
        next_check_at: Time.now,
        visibility: "private"
      )
    end

    let!(:foreign_private_watch) do
      described_class.create!(
        user: other_user,
        domain: "foreign-private.example.com",
        record_type: "A",
        record_name: "@",
        interval_seconds: 300,
        next_check_at: Time.now,
        visibility: "private"
      )
    end

    it "returns only public watches for guests" do
      results = described_class.visible_to(nil)

      expect(results).to include(public_watch)
      expect(results).not_to include(owned_private_watch)
      expect(results).not_to include(foreign_private_watch)
    end

    it "includes public and owned watches for the user" do
      results = described_class.visible_to(user)

      expect(results).to include(public_watch)
      expect(results).to include(owned_private_watch)
      expect(results).not_to include(foreign_private_watch)
    end
  end

  describe "#owner?" do
    it "returns true only for the owning user" do
      watch.save!

      expect(watch.owner?(user)).to eq(true)
      expect(watch.owner?(User.create!(email: "other@example.com", password: "password123", password_confirmation: "password123"))).to eq(false)
      expect(watch.owner?(nil)).to eq(false)
    end
  end
end
