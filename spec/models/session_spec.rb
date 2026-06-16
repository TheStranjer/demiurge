# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) do
    User.create!(username: "alice", password: "password123", password_confirmation: "password123")
  end

  describe "creation" do
    it "generates a 64-character hex token" do
      expect(user.sessions.create!.token).to match(/\A[0-9a-f]{64}\z/)
    end

    it "assigns a future expiration by default" do
      expect(user.sessions.create!.expires_at).to be > Time.current
    end

    it "does not overwrite a provided token" do
      session = user.sessions.create!(token: "a-custom-token")
      expect(session.token).to eq("a-custom-token")
    end

    it "does not overwrite a provided expiration" do
      time = 1.hour.from_now
      session = user.sessions.create!(expires_at: time)
      expect(session.expires_at).to be_within(1.second).of(time)
    end
  end

  describe "validations" do
    it "requires an associated user" do
      expect(described_class.new).not_to be_valid
    end

    it "requires a unique token" do
      existing = user.sessions.create!
      duplicate = user.sessions.build(token: existing.token)
      expect(duplicate).not_to be_valid
    end
  end

  describe "#expired?" do
    it "is false for a future expiration" do
      expect(user.sessions.create!(expires_at: 1.day.from_now)).not_to be_expired
    end

    it "is true for a past expiration" do
      expect(user.sessions.build(expires_at: 1.day.ago)).to be_expired
    end
  end

  describe ".active" do
    it "includes unexpired sessions" do
      session = user.sessions.create!(expires_at: 1.day.from_now)
      expect(described_class.active).to include(session)
    end

    it "excludes expired sessions" do
      session = user.sessions.create!(expires_at: 1.day.ago)
      expect(described_class.active).not_to include(session)
    end
  end
end
