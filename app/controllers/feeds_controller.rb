# frozen_string_literal: true

require "rss"
require "uri"

class FeedsController < ApplicationController
  FEED_LIMIT = 100

  helper_method :absolute_url

  before_action :authenticate_by_feed_token!, only: %i[user watch]
  before_action :set_watch, only: :watch
  before_action :authorize_watch_access!, only: :watch

  def public
    changes = DnsChange
      .joins(:dns_watch)
      .merge(DnsWatch.publicly_visible)
      .includes(dns_watch: :user)
      .order(detected_at: :desc)
      .limit(FEED_LIMIT)

    render_feed(
      title: "Public DNS change log",
      description: "Latest DNS changes across all public watches",
      link: root_path,
      changes: changes
    )
  end

  def user
    changes = @authenticated_user
      .dns_changes
      .includes(dns_watch: :user)
      .order(detected_at: :desc)
      .limit(FEED_LIMIT)

    render_feed(
      title: "DNS change log for #{@authenticated_user.email}",
      description: "Recent DNS changes detected for watches owned by #{@authenticated_user.email}",
      link: user_feed_path(feed_token: @authenticated_user.feed_token, format: :rss),
      changes: changes
    )
  end

  def watch
    changes = @watch
      .dns_changes
      .includes(:dns_watch)
      .order(detected_at: :desc)
      .limit(FEED_LIMIT)

    render_feed(
      title: "DNS change log for #{@watch.domain} (#{@watch.record_type} #{@watch.record_name})",
      description: "Recent DNS changes detected for #{@watch.domain} (#{@watch.record_type} #{@watch.record_name})",
      link: watch_feed_path(@watch, feed_token: @authenticated_user.feed_token, format: :rss),
      changes: changes
    )
  end

  private

  def authenticate_by_feed_token!
    feed_token = params[:feed_token].presence
    return if feed_token.present? && (@authenticated_user = User.find_by(feed_token: feed_token))

    head :unauthorized
    throw :abort
  end

  def set_watch
    @watch = DnsWatch.find_by(id: params[:id])
    return if @watch.present?

    head :not_found
    throw :abort
  end

  def authorize_watch_access!
    return if @watch.user_id == @authenticated_user.id

    head :forbidden
    throw :abort
  end

  def render_feed(title:, description:, link:, changes:)
    @feed_title = title
    @feed_description = description
    @feed_link = link
    @feed_changes = Array(changes)

    response.set_header("Content-Type", "application/rss+xml; charset=utf-8")

    respond_to do |format|
      format.rss { render template: "feeds/feed", layout: false }
      format.xml { render template: "feeds/feed", layout: false }
      format.any { head :not_acceptable }
    end
  end

  helper_method :build_change_description

  def build_change_description(change)
    watch = change.dns_watch
    previous_value = change.from_value.presence || "(no previous value)"

    <<~DESC.squish
      Domain: #{watch.domain}; Record: #{watch.record_type} #{watch.record_name}; Previous: #{previous_value}; New: #{change.to_value}; Detected at: #{change.detected_at}
    DESC
  end

  def absolute_url(path_or_url)
    return request.base_url + path_or_url if path_or_url.start_with?("/")

    uri = URI.parse(path_or_url)
    uri.absolute? ? path_or_url : request.base_url + "/"
  rescue URI::InvalidURIError
    request.base_url + "/"
  end
end
