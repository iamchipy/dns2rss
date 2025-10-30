# frozen_string_literal: true

require "resolv"

class DnsResolver
  class ResolutionError < StandardError; end

  def initialize(resolver: Resolv::DNS.new)
    @resolver = resolver
  end

  def resolve(domain, record_type, record_name)
    fqdn = build_fqdn(domain, record_name)

    records = case record_type.to_s.upcase
              when "A"
                resolve_a(fqdn)
              when "AAAA"
                resolve_aaaa(fqdn)
              when "CNAME"
                resolve_cname(fqdn)
              when "TXT"
                resolve_txt(fqdn)
              when "MX"
                resolve_mx(fqdn)
              when "NS"
                resolve_ns(fqdn)
              when "SRV"
                resolve_srv(fqdn)
              else
                raise ResolutionError, "Unsupported record type: #{record_type}"
              end

    canonicalize(records)
  rescue Resolv::ResolvError => e
    raise ResolutionError, "DNS resolution failed: #{e.message}"
  end

  private

  def build_fqdn(domain, record_name)
    normalized_domain = domain.to_s.strip.downcase
    normalized_name = record_name.to_s.strip.downcase

    return normalized_domain if normalized_name.empty? || normalized_name == "@"
    return normalized_name.chomp(".") if normalized_name.end_with?(".")

    "#{normalized_name}.#{normalized_domain}"
  end

  def resolve_a(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::A).map do |record|
      record.address.to_s
    end
  end

  def resolve_aaaa(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::AAAA).map do |record|
      record.address.to_s.downcase
    end
  end

  def resolve_cname(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::CNAME).map do |record|
      record.name.to_s.downcase.chomp(".")
    end
  end

  def resolve_txt(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::TXT).map do |record|
      record.strings.join.strip
    end
  end

  def resolve_mx(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::MX).map do |record|
      "#{record.preference} #{record.exchange.to_s.downcase.chomp('.')}"
    end
  end

  def resolve_ns(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::NS).map do |record|
      record.name.to_s.downcase.chomp(".")
    end
  end

  def resolve_srv(fqdn)
    @resolver.getresources(fqdn, Resolv::DNS::Resource::IN::SRV).map do |record|
      "#{record.priority} #{record.weight} #{record.port} #{record.target.to_s.downcase.chomp('.')}"
    end
  end

  def canonicalize(records)
    normalized = records.compact.map { |value| value.to_s.strip }.reject(&:empty?)
    return "(no records)" if normalized.empty?

    normalized.uniq.sort.join("\n")
  end
end
