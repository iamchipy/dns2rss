# frozen_string_literal: true

require "spec_helper"

RSpec.describe DnsCheckJob do
  let(:user) { User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123") }
  let(:watch) do
    DnsWatch.create!(
      user: user,
      domain: "example.com",
      record_type: "A",
      record_name: "@",
      interval_seconds: 300,
      next_check_at: Time.current,
      last_value: nil
    )
  end

  let(:resolver) { instance_double(DnsResolver) }

  before do
    allow(DnsResolver).to receive(:new).and_return(resolver)
  end

  describe "#perform" do
    context "when DNS value is new" do
      it "creates a DNS change record and updates the watch" do
        freeze_time do
          new_value = "192.168.1.1"
          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_return(new_value)

          expect {
            described_class.new.perform(watch.id)
          }.to change { DnsChange.count }.by(1)

          watch.reload
          change = watch.dns_changes.last

          expect(change.from_value).to be_nil
          expect(change.to_value).to eq(new_value)
          expect(change.detected_at).to be_within(1.second).of(Time.current)
          expect(watch.last_value).to eq(new_value)
          expect(watch.last_checked_at).to be_within(1.second).of(Time.current)
          expect(watch.next_check_at).to be_within(1.second).of(Time.current + 300.seconds)
        end
      end
    end

    context "when DNS value changes" do
      it "creates a DNS change record with from and to values" do
        freeze_time do
          watch.update!(last_value: "192.168.1.1")
          new_value = "192.168.1.2"

          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_return(new_value)

          expect {
            described_class.new.perform(watch.id)
          }.to change { DnsChange.count }.by(1)

          watch.reload
          change = watch.dns_changes.last

          expect(change.from_value).to eq("192.168.1.1")
          expect(change.to_value).to eq(new_value)
          expect(watch.last_value).to eq(new_value)
        end
      end
    end

    context "when DNS value is unchanged" do
      it "does not create a DNS change record" do
        freeze_time do
          current_value = "192.168.1.1"
          watch.update!(last_value: current_value)

          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_return(current_value)

          expect {
            described_class.new.perform(watch.id)
          }.not_to change { DnsChange.count }

          watch.reload
          expect(watch.last_value).to eq(current_value)
          expect(watch.last_checked_at).to be_within(1.second).of(Time.current)
          expect(watch.next_check_at).to be_within(1.second).of(Time.current + 300.seconds)
        end
      end
    end

    context "when DNS resolution fails" do
      it "updates check timestamps without creating a change record" do
        freeze_time do
          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_raise(DnsResolver::ResolutionError, "NXDOMAIN")

          expect {
            described_class.new.perform(watch.id)
          }.not_to change { DnsChange.count }

          watch.reload
          expect(watch.last_checked_at).to be_within(1.second).of(Time.current)
          expect(watch.next_check_at).to be_within(1.second).of(Time.current + 300.seconds)
        end
      end

      it "does not update last_value when resolution fails" do
        original_value = "192.168.1.1"
        watch.update!(last_value: original_value)

        allow(resolver).to receive(:resolve)
          .with(watch.domain, watch.record_type, watch.record_name)
          .and_raise(DnsResolver::ResolutionError, "Timeout")

        described_class.new.perform(watch.id)

        watch.reload
        expect(watch.last_value).to eq(original_value)
      end
    end

    context "with interval_seconds" do
      it "advances next_check_at by interval_seconds" do
        freeze_time do
          watch.update!(interval_seconds: 600)

          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_return("192.168.1.1")

          described_class.new.perform(watch.id)

          watch.reload
          expect(watch.next_check_at).to be_within(1.second).of(Time.current + 600.seconds)
        end
      end
    end

    context "with multiple record types" do
      it "handles MX records correctly" do
        freeze_time do
          watch.update!(record_type: "MX")
          mx_value = "10 mail.example.com"

          allow(resolver).to receive(:resolve)
            .with(watch.domain, "MX", watch.record_name)
            .and_return(mx_value)

          described_class.new.perform(watch.id)

          watch.reload
          expect(watch.last_value).to eq(mx_value)
        end
      end

      it "handles TXT records correctly" do
        freeze_time do
          watch.update!(record_type: "TXT")
          txt_value = "v=spf1 include:_spf.example.com ~all"

          allow(resolver).to receive(:resolve)
            .with(watch.domain, "TXT", watch.record_name)
            .and_return(txt_value)

          described_class.new.perform(watch.id)

          watch.reload
          expect(watch.last_value).to eq(txt_value)
        end
      end
    end

    context "with canonicalized output" do
      it "detects changes in sorted order" do
        freeze_time do
          watch.update!(last_value: "192.168.1.1\n192.168.1.2")
          new_value = "192.168.1.1\n192.168.1.3"

          allow(resolver).to receive(:resolve)
            .with(watch.domain, watch.record_type, watch.record_name)
            .and_return(new_value)

          expect {
            described_class.new.perform(watch.id)
          }.to change { DnsChange.count }.by(1)

          watch.reload
          expect(watch.last_value).to eq(new_value)
        end
      end
    end
  end
end
