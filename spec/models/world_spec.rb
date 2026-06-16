# frozen_string_literal: true

require "rails_helper"

RSpec.describe World, type: :model do
  subject(:world) { user.worlds.new(title: "Aerth", core_concept: "A world of floating islands.") }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }

  it "is valid with a title, core concept, and user" do
    expect(world).to be_valid
  end

  it "requires a title" do
    world.title = nil
    expect(world).not_to be_valid
  end

  it "requires a core concept" do
    world.core_concept = nil
    expect(world).not_to be_valid
  end

  it "requires a user" do
    expect(described_class.new(title: "Aerth", core_concept: "Concept")).not_to be_valid
  end

  it "is destroyed along with its user" do
    world.save!
    expect { user.destroy }.to change(described_class, :count).by(-1)
  end
end
