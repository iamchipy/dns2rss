feed_document = RSS::Maker.make("2.0") do |maker|
  maker.channel.title = @feed_title
  maker.channel.link = absolute_url(@feed_link)
  maker.channel.description = @feed_description
  maker.channel.language = "en"
  maker.channel.generator = "DNS Watch Monitor"
  maker.channel.lastBuildDate = (@feed_changes.first&.detected_at || Time.current).rfc2822

  @feed_changes.each do |change|
    watch = change.dns_watch

    maker.items.new_item do |item|
      item.title = "#{watch.domain} (#{watch.record_type} #{watch.record_name})"
      item.link = absolute_url(dns_watch_path(watch))
      item.guid.content = "dns_change_#{change.id}"
      item.guid.isPermaLink = false
      item.pubDate = change.detected_at.rfc2822 if change.detected_at.present?
      item.description = build_change_description(change)
    end
  end
end

xml << feed_document.to_s
