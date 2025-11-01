# frozen_string_literal: true

require "spec_helper"
require "action_dispatch/testing/test_request"
require "action_dispatch/testing/assertions/response"

RSpec.describe FeedsController, type: :controller do
  include ActionDispatch::TestProcess

  let(:user) { User.create!(email: "owner@example.com", password: "password123", password_confirmation: "password123") }
  let!(:public_watch) do
    DnsWatch.create!(
      user: user,
      domain: "public.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "public"
    )
  end
  let!(:public_change) do
    DnsChange.create!(
      dns_watch: public_watch,
      from_value: "1.2.3.4",
      to_value: "5.6.7.8",
      detected_at: 1.hour.ago
    )
  end

  it "returns success for public feed" do
    get :public, format: :rss

    expect(response).to be_successful
    expect(response.media_type).to eq("application/rss+xml")
  end

  it "requires feed_token for user feed" do
    get :user, format: :rss

    expect(response).to have_http_status(:unauthorized)
  end

  it "requires feed_token for watch feed" do
    get :watch, params: { id: public_watch.id }, format: :rss

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns success for user feed with valid token" do
    get :user, params: { feed_token: user.feed_token }, format: :rss

    expect(response).to be_successful
    expect(response.body).to include("public.example.com")
  end

  it "returns forbidden for watch feed with invalid token" do
    get :watch, params: { id: public_watch.id, feed_token: "invalid" }, format: :rss

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns success for watch feed with valid token" do
    get :watch, params: { id: public_watch.id, feed_token: user.feed_token }, format: :rss

    expect(response).to be_successful
    expect(response.body).to include("public.example.com")
  end
end
