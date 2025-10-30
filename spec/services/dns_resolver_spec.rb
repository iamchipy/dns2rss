# frozen_string_literal: true

require "spec_helper"

RSpec.describe DnsResolver do
  let(:mock_resolver) { instance_double(Resolv::DNS) }
  let(:resolver) { described_class.new(resolver: mock_resolver) }

  describe "#resolve" do
    context "with A records" do
      it "returns sorted IP addresses" do
        records = [
          double(address: "192.168.1.2"),
          double(address: "192.168.1.1")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        result = resolver.resolve("example.com", "A", "@")

        expect(result).to eq("192.168.1.1\n192.168.1.2")
      end

      it "handles subdomain with record_name" do
        records = [double(address: "10.0.0.1")]

        allow(mock_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        result = resolver.resolve("example.com", "A", "www")

        expect(result).to eq("10.0.0.1")
      end

      it "returns canonical empty result when no records exist" do
        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return([])

        result = resolver.resolve("example.com", "A", "@")

        expect(result).to eq("(no records)")
      end
    end

    context "with AAAA records" do
      it "returns canonicalized IPv6 addresses" do
        records = [
          double(address: "2001:0db8::1"),
          double(address: "2001:0db8::2")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::AAAA)
          .and_return(records)

        result = resolver.resolve("example.com", "AAAA", "@")

        expect(result).to eq("2001:0db8::1\n2001:0db8::2")
      end
    end

    context "with CNAME records" do
      it "returns canonicalized domain names" do
        records = [
          double(name: "target.example.com.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return(records)

        result = resolver.resolve("example.com", "CNAME", "www")

        expect(result).to eq("target.example.com")
      end

      it "lowercases and removes trailing dots" do
        records = [
          double(name: "TARGET.EXAMPLE.COM.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::CNAME)
          .and_return(records)

        result = resolver.resolve("example.com", "CNAME", "www")

        expect(result).to eq("target.example.com")
      end
    end

    context "with TXT records" do
      it "returns sorted text records" do
        records = [
          double(strings: ["v=spf1 include:_spf.example.com ~all"]),
          double(strings: ["google-site-verification=abc123"])
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::TXT)
          .and_return(records)

        result = resolver.resolve("example.com", "TXT", "@")

        expect(result).to eq("google-site-verification=abc123\nv=spf1 include:_spf.example.com ~all")
      end

      it "joins multi-part TXT records" do
        records = [
          double(strings: ["part1", "part2"])
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::TXT)
          .and_return(records)

        result = resolver.resolve("example.com", "TXT", "@")

        expect(result).to eq("part1part2")
      end
    end

    context "with MX records" do
      it "returns sorted MX records with priority" do
        records = [
          double(preference: 20, exchange: "mail2.example.com."),
          double(preference: 10, exchange: "mail1.example.com.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::MX)
          .and_return(records)

        result = resolver.resolve("example.com", "MX", "@")

        expect(result).to eq("10 mail1.example.com\n20 mail2.example.com")
      end

      it "lowercases and removes trailing dots from exchange" do
        records = [
          double(preference: 10, exchange: "MAIL.EXAMPLE.COM.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::MX)
          .and_return(records)

        result = resolver.resolve("example.com", "MX", "@")

        expect(result).to eq("10 mail.example.com")
      end
    end

    context "with NS records" do
      it "returns sorted nameservers" do
        records = [
          double(name: "ns2.example.com."),
          double(name: "ns1.example.com.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::NS)
          .and_return(records)

        result = resolver.resolve("example.com", "NS", "@")

        expect(result).to eq("ns1.example.com\nns2.example.com")
      end

      it "canonicalizes nameserver records" do
        records = [
          double(name: "NS1.EXAMPLE.COM.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::NS)
          .and_return(records)

        result = resolver.resolve("example.com", "NS", "@")

        expect(result).to eq("ns1.example.com")
      end
    end

    context "with SRV records" do
      it "returns sorted SRV records" do
        records = [
          double(priority: 10, weight: 60, port: 5060, target: "sip2.example.com."),
          double(priority: 10, weight: 40, port: 5060, target: "sip1.example.com.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("_sip._tcp.example.com", Resolv::DNS::Resource::IN::SRV)
          .and_return(records)

        result = resolver.resolve("example.com", "SRV", "_sip._tcp")

        expect(result).to eq("10 40 5060 sip1.example.com\n10 60 5060 sip2.example.com")
      end

      it "canonicalizes SRV target names" do
        records = [
          double(priority: 10, weight: 50, port: 443, target: "SERVER.EXAMPLE.COM.")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("_https._tcp.example.com", Resolv::DNS::Resource::IN::SRV)
          .and_return(records)

        result = resolver.resolve("example.com", "SRV", "_https._tcp")

        expect(result).to eq("10 50 443 server.example.com")
      end
    end

    context "with canonicalization" do
      it "removes duplicates" do
        records = [
          double(address: "192.168.1.1"),
          double(address: "192.168.1.1")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        result = resolver.resolve("example.com", "A", "@")

        expect(result).to eq("192.168.1.1")
      end

      it "sorts records alphabetically" do
        records = [
          double(address: "192.168.1.5"),
          double(address: "192.168.1.1"),
          double(address: "192.168.1.3")
        ]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        result = resolver.resolve("example.com", "A", "@")

        expect(result).to eq("192.168.1.1\n192.168.1.3\n192.168.1.5")
      end
    end

    context "with FQDN building" do
      it "handles @ as apex domain" do
        records = [double(address: "192.168.1.1")]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        resolver.resolve("example.com", "A", "@")

        expect(mock_resolver).to have_received(:getresources).with("example.com", anything)
      end

      it "handles empty record_name as apex domain" do
        records = [double(address: "192.168.1.1")]

        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        resolver.resolve("example.com", "A", "")

        expect(mock_resolver).to have_received(:getresources).with("example.com", anything)
      end

      it "handles subdomain prefixes" do
        records = [double(address: "192.168.1.1")]

        allow(mock_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        resolver.resolve("example.com", "A", "www")

        expect(mock_resolver).to have_received(:getresources).with("www.example.com", anything)
      end

      it "normalizes input domains and record names" do
        records = [double(address: "192.168.1.1")]

        allow(mock_resolver).to receive(:getresources)
          .with("www.example.com", Resolv::DNS::Resource::IN::A)
          .and_return(records)

        resolver.resolve(" EXAMPLE.COM ", "A", " WWW ")

        expect(mock_resolver).to have_received(:getresources).with("www.example.com", anything)
      end
    end

    context "with error handling" do
      it "raises ResolutionError on DNS resolution failure" do
        allow(mock_resolver).to receive(:getresources)
          .with("example.com", Resolv::DNS::Resource::IN::A)
          .and_raise(Resolv::ResolvError.new("NXDOMAIN"))

        expect {
          resolver.resolve("example.com", "A", "@")
        }.to raise_error(DnsResolver::ResolutionError, /DNS resolution failed/)
      end

      it "raises ResolutionError for unsupported record types" do
        expect {
          resolver.resolve("example.com", "SOA", "@")
        }.to raise_error(DnsResolver::ResolutionError, /Unsupported record type/)
      end
    end
  end
end
