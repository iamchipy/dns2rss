# frozen_string_literal: true

require "spec_helper"

RSpec.describe DnsChange do
  let(:user) { User.create!(email: "watcher@example.com", password: "password123", password_confirmation: "password123") }
  let(:watch) do
    DnsWatch.create!(
      user: user,
      domain: "example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 300,
      next_check_at: Time.now
    )
  end

  subject(:change) do
    described_class.new(
      dns_watch: watch,
      detected_at: Time.now,
      from_value: "1.1.1.1",
      to_value: "2.2.2.2"
    )
  end

  it "is valid with default attributes" do
    expect(change).to be_valid
  end

  it "requires a dns watch" do
    change.dns_watch = nil
    expect(change).not_to be_valid
    expect(change.errors[:dns_watch]).to include("must exist")
  end

  it "requires detected at" do
    change.detected_at = nil
    expect(change).not_to be_valid
    expect(change.errors[:detected_at]).to include("can't be blank")
  end

  it "requires to value" do
    change.to_value = nil
    expect(change).not_to be_valid
    expect(change.errors[:to_value]).to include("can't be blank")
  end

  it "allows a missing from value" do
    change.from_value = nil
    expect(change).to be_valid
  end

  it "delegates user to the watch" do
    expect(change.user).to eq(user)
  end

  it "persists to the database" do
    expect { change.save! }.to change(described_class, :count).by(1)
  end
end
