# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scene, type: :model do
  subject(:scene) { world.scenes.new(valid_attributes) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character_attributes) do
    {
      name: "Kara",
      sex: "female",
      non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end
  let(:character) { world.characters.create!(character_attributes) }
  let(:valid_attributes) do
    {
      user: user,
      character: character,
      premise: "Two strangers meet in a crowded tavern.",
      end_trigger: "End when they agree to travel together.",
      play_mode: "player",
    }
  end

  it "is valid with all attributes present" do
    expect(scene).to be_valid
  end

  it "requires a world" do
    expect(described_class.new(valid_attributes)).not_to be_valid
  end

  it "requires a user" do
    scene.user = nil
    expect(scene).not_to be_valid
  end

  it "requires a character" do
    scene.character = nil
    expect(scene).not_to be_valid
  end

  it "is destroyed along with its world" do
    scene.save!
    expect { world.destroy }.to change(described_class, :count).by(-1)
  end

  it "is destroyed along with its character" do
    scene.save!
    expect { character.destroy }.to change(described_class, :count).by(-1)
  end

  describe "premise" do
    it "is required" do
      scene.premise = nil
      expect(scene).not_to be_valid
    end
  end

  describe "end_trigger" do
    it "is required" do
      scene.end_trigger = nil
      expect(scene).not_to be_valid
    end
  end

  describe "play_mode" do
    it "accepts narrator" do
      scene.play_mode = "narrator"
      expect(scene).to be_valid
    end

    it "rejects nil" do
      scene.play_mode = nil
      expect(scene).not_to be_valid
    end

    it "rejects values outside the allowed set" do
      scene.play_mode = "spectator"
      expect(scene).not_to be_valid
    end
  end

  describe "character" do
    it "must belong to the same world" do
      other_world = user.worlds.create!(title: "Other", core_concept: "Elsewhere.")
      scene.character = other_world.characters.create!(character_attributes)
      expect(scene).not_to be_valid
    end
  end

  describe "#narrator_mode?" do
    it "is true for narrator scenes" do
      scene.play_mode = "narrator"
      expect(scene).to be_narrator_mode
    end

    it "is false for player scenes" do
      expect(scene).not_to be_narrator_mode
    end
  end

  describe "#finish!" do
    it "stamps finished_at" do
      scene.save!
      expect { scene.finish! }.to change(scene, :finished?).from(false).to(true)
    end
  end

  describe "#present_characters" do
    it "always includes the main character" do
      scene.save!
      expect(scene.present_characters).to eq([character])
    end

    it "includes arrived characters and excludes departed ones" do
      scene.save!
      arrival = world.characters.create!(character_attributes.merge(name: "Bram"))
      gone = world.characters.create!(character_attributes.merge(name: "Zed"))
      scene.scene_presences.create!(character: arrival)
      scene.scene_presences.create!(character: gone, departed_at: Time.current)
      expect(scene.present_characters).to contain_exactly(character, arrival)
    end
  end
end
