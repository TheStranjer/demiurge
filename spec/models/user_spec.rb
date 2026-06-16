# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) do
    described_class.new(username: "alice", password: "password123", password_confirmation: "password123")
  end

  it "is valid with a username and matching password" do
    expect(user).to be_valid
  end

  describe "username" do
    it "is required" do
      user.username = nil
      expect(user).not_to be_valid
    end

    it "is normalized to lowercase and trimmed" do
      user.username = "  AliCE  "
      user.validate
      expect(user.username).to eq("alice")
    end

    it "must be unique, case-insensitively" do
      described_class.create!(username: "alice", password: "password123", password_confirmation: "password123")
      duplicate = described_class.new(username: "ALICE", password: "password123", password_confirmation: "password123")
      expect(duplicate).not_to be_valid
    end

    it "rejects disallowed characters" do
      user.username = "bad name!"
      expect(user).not_to be_valid
    end

    it "enforces a minimum length" do
      user.username = "ab"
      expect(user).not_to be_valid
    end

    it "enforces a maximum length" do
      user.username = "a" * 31
      expect(user).not_to be_valid
    end
  end

  describe "password" do
    it "is required on create" do
      user.password = nil
      user.password_confirmation = nil
      expect(user).not_to be_valid
    end

    it "must match its confirmation" do
      user.password_confirmation = "different123"
      expect(user).not_to be_valid
    end

    it "enforces a minimum length" do
      user.password = "short"
      user.password_confirmation = "short"
      expect(user).not_to be_valid
    end

    it "is stored hashed rather than as plaintext" do
      user.save!
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq("password123")
    end

    it "authenticates with the correct password" do
      user.save!
      expect(user.authenticate("password123")).to eq(user)
    end

    it "does not authenticate with a wrong password" do
      user.save!
      expect(user.authenticate("wrong")).to be(false)
    end
  end

  describe "associations" do
    it "destroys dependent sessions" do
      user.save!
      user.sessions.create!
      expect { user.destroy }.to change(Session, :count).by(-1)
    end
  end
end
