# frozen_string_literal: true

require "spec_helper"
require "action_dispatch/testing/integration"
require "rss"

RSpec.describe "Feeds", type: :request do
  before do
    @integration_session = ActionDispatch::Integration::Session.new(Rails.application)
  end

  let(:user) { User.create!(email: "owner@example.com", password: "password123", password_confirmation: "password123") }
  let(:other_user) { User.create!(email: "other@example.com", password: "password123", password_confirmation: "password123") }

  let!(:public_watch) do
    DnsWatch.create!(
      user: user,
      domain: "public.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "public"
    )
  end

  let!(:private_watch) do
    DnsWatch.create!(
      user: user,
      domain: "private.example.com",
      record_type: "A",
      record_name: "@",
      visibility: "private"
    )
  end

  let!(:other_user_public_watch) do
    DnsWatch.create!(
      user: other_user,
      domain: "other-public.example.com",
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

  let!(:private_change) do
    DnsChange.create!(
      dns_watch: private_watch,
      from_value: "10.0.0.1",
      to_value: "10.0.0.2",
      detected_at: 2.hours.ago
    )
  end

  let!(:other_public_change) do
    DnsChange.create!(
      dns_watch: other_user_public_watch,
      from_value: "8.8.8.8",
      to_value: "8.8.4.4",
      detected_at: 30.minutes.ago
    )
  end

  describe "GET /feeds/public" do
    it "returns RSS feed with correct content-type" do
      @integration_session.get public_feed_path(format: :rss)

      expect(@integration_session.response).to have_http_status(:success)
      expect(@integration_session.response.content_type).to match(/application\/rss\+xml/)
    end

    it "includes changes from public watches only" do
      @integration_session.get public_feed_path(format: :rss)

      expect(@integration_session.response.body).to include("public.example.com")
      expect(@integration_session.response.body).to include("other-public.example.com")
      expect(@integration_session.response.body).not_to include("private.example.com")
    end

    it "includes previous and new values" do
      @integration_session.get public_feed_path(format: :rss)

      expect(@integration_session.response.body).to include("1.2.3.4")
      expect(@integration_session.response.body).to include("5.6.7.8")
    end

    it "generates valid RSS 2.0 feed" do
      @integration_session.get public_feed_path(format: :rss)

      rss = RSS::Parser.parse(@integration_session.response.body)
      expect(rss).to be_a(RSS::Rss)
      expect(rss.channel.title).to eq("Public DNS change log")
      expect(rss.items.length).to eq(2)
    end

    it "orders changes by detected_at desc" do
      @integration_session.get public_feed_path(format: :rss)

      rss = RSS::Parser.parse(@integration_session.response.body)
      first_item_title = rss.items.first.title
      expect(first_item_title).to include("other-public.example.com")
    end
  end

  describe "GET /feeds/user" do
    context "without feed_token" do
      it "returns unauthorized" do
        @integration_session.get user_feed_path(format: :rss)

        expect(@integration_session.response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid feed_token" do
      it "returns unauthorized" do
        @integration_session.get user_feed_path(feed_token: "invalid_token", format: :rss)

        expect(@integration_session.response).to have_http_status(:unauthorized)
      end
    end

    context "with valid feed_token" do
      it "returns RSS feed with correct content-type" do
        @integration_session.get user_feed_path(feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response).to have_http_status(:success)
        expect(@integration_session.response.content_type).to match(/application\/rss\+xml/)
      end

      it "includes changes from all user-owned watches" do
        @integration_session.get user_feed_path(feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response.body).to include("public.example.com")
        expect(@integration_session.response.body).to include("private.example.com")
        expect(@integration_session.response.body).not_to include("other-public.example.com")
      end

      it "includes changes from both public and private watches" do
        @integration_session.get user_feed_path(feed_token: user.feed_token, format: :rss)

        rss = RSS::Parser.parse(@integration_session.response.body)
        expect(rss.items.length).to eq(2)
      end

      it "generates valid RSS 2.0 feed" do
        @integration_session.get user_feed_path(feed_token: user.feed_token, format: :rss)

        rss = RSS::Parser.parse(@integration_session.response.body)
        expect(rss).to be_a(RSS::Rss)
        expect(rss.channel.title).to include(user.email)
      end

      it "includes previous and new values in description" do
        @integration_session.get user_feed_path(feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response.body).to include("1.2.3.4")
        expect(@integration_session.response.body).to include("5.6.7.8")
        expect(@integration_session.response.body).to include("10.0.0.1")
        expect(@integration_session.response.body).to include("10.0.0.2")
      end
    end
  end

  describe "GET /feeds/watch/:id" do
    context "without feed_token" do
      it "returns unauthorized" do
        @integration_session.get watch_feed_path(public_watch, format: :rss)

        expect(@integration_session.response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid feed_token" do
      it "returns unauthorized" do
        @integration_session.get watch_feed_path(public_watch, feed_token: "invalid_token", format: :rss)

        expect(@integration_session.response).to have_http_status(:unauthorized)
      end
    end

    context "with another user's feed_token" do
      it "returns forbidden" do
        @integration_session.get watch_feed_path(public_watch, feed_token: other_user.feed_token, format: :rss)

        expect(@integration_session.response).to have_http_status(:forbidden)
      end
    end

    context "with owner's feed_token" do
      it "returns RSS feed with correct content-type" do
        @integration_session.get watch_feed_path(public_watch, feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response).to have_http_status(:success)
        expect(@integration_session.response.content_type).to match(/application\/rss\+xml/)
      end

      it "includes changes from the specific watch only" do
        @integration_session.get watch_feed_path(public_watch, feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response.body).to include("public.example.com")
        expect(@integration_session.response.body).not_to include("private.example.com")
        expect(@integration_session.response.body).not_to include("other-public.example.com")
      end

      it "generates valid RSS 2.0 feed" do
        @integration_session.get watch_feed_path(public_watch, feed_token: user.feed_token, format: :rss)

        rss = RSS::Parser.parse(@integration_session.response.body)
        expect(rss).to be_a(RSS::Rss)
        expect(rss.channel.title).to include("public.example.com")
        expect(rss.items.length).to eq(1)
      end

      it "includes previous and new values in description" do
        @integration_session.get watch_feed_path(public_watch, feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response.body).to include("1.2.3.4")
        expect(@integration_session.response.body).to include("5.6.7.8")
      end

      it "works for private watches" do
        @integration_session.get watch_feed_path(private_watch, feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response).to have_http_status(:success)
        expect(@integration_session.response.body).to include("private.example.com")
      end
    end

    context "with non-existent watch id" do
      it "returns not found" do
        @integration_session.get watch_feed_path(id: 99999, feed_token: user.feed_token, format: :rss)

        expect(@integration_session.response).to have_http_status(:not_found)
      end
    end
  end
end
