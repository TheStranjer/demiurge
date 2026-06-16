# frozen_string_literal: true

require "rails_helper"

RSpec.describe Character, type: :model do
  subject(:character) { world.characters.new(valid_attributes) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:valid_attributes) do
    {
      name: "Kara",
      sex: "female",
      non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  it "is valid with all attributes present and in range" do
    expect(character).to be_valid
  end

  it "requires a world" do
    expect(described_class.new(valid_attributes)).not_to be_valid
  end

  it "is destroyed along with its world" do
    character.save!
    expect { world.destroy }.to change(described_class, :count).by(-1)
  end

  describe "name" do
    it "is required" do
      character.name = nil
      expect(character).not_to be_valid
    end

    it "rejects values longer than 255 characters" do
      character.name = "a" * 256
      expect(character).not_to be_valid
    end
  end

  describe "sex" do
    it "accepts male" do
      character.sex = "male"
      expect(character).to be_valid
    end

    it "rejects nil" do
      character.sex = nil
      expect(character).not_to be_valid
    end

    it "rejects values outside the allowed set" do
      character.sex = "other"
      expect(character).not_to be_valid
    end
  end

  describe "non_player_character" do
    it "defaults to false" do
      expect(described_class.new.non_player_character).to be(false)
    end

    it "accepts true" do
      character.non_player_character = true
      expect(character).to be_valid
    end

    it "rejects nil" do
      character.non_player_character = nil
      expect(character).not_to be_valid
    end
  end

  describe "stats" do
    Character::STATS.each do |stat|
      it "requires #{stat}" do
        character.public_send("#{stat}=", nil)
        expect(character).not_to be_valid
      end

      it "rejects #{stat} below -5" do
        character.public_send("#{stat}=", -6)
        expect(character).not_to be_valid
      end

      it "rejects #{stat} above 5" do
        character.public_send("#{stat}=", 6)
        expect(character).not_to be_valid
      end

      it "rejects a non-integer #{stat}" do
        character.public_send("#{stat}=", 1.5)
        expect(character).not_to be_valid
      end
    end

    it "accepts the boundary values -5 and 5" do
      character.strength = -5
      character.tact = 5
      expect(character).to be_valid
    end
  end
end
