# frozen_string_literal: true

require "rails_helper"

RSpec.describe RollResult, type: :model do
  subject(:roll_result) { roll_table.roll_results.new(valid_attributes) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) do
    world.characters.create!(
      name: "Kara",
      sex: "female",
      non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    )
  end
  let(:roll_table) do
    RollTable.create!(
      denomination: 8,
      quantity: 1,
      description: "Contested seduction roll.",
      possible_results: [{ "min" => nil, "max" => nil, "result" => "outcome" }],
    )
  end
  let(:valid_attributes) { { roll_result: 6, entity: character } }

  it "is valid with the required attributes" do
    expect(roll_result).to be_valid
  end

  it "requires a roll_table" do
    expect(described_class.new(valid_attributes)).not_to be_valid
  end

  it "requires an entity" do
    roll_result.entity = nil
    expect(roll_result).not_to be_valid
  end

  it "accepts any polymorphic entity type" do
    roll_result.entity = world
    expect(roll_result).to be_valid
  end

  it "is destroyed along with its roll table" do
    roll_result.save!
    expect { roll_table.destroy }.to change(described_class, :count).by(-1)
  end

  describe "roll_result" do
    it "is required" do
      roll_result.roll_result = nil
      expect(roll_result).not_to be_valid
    end

    it "rejects non-integers" do
      roll_result.roll_result = 1.5
      expect(roll_result).not_to be_valid
    end
  end

  describe "entity_defender" do
    it "is optional" do
      roll_result.entity_defender = nil
      expect(roll_result).to be_valid
    end

    it "may be a different entity type than the attacker" do
      roll_result.entity_defender = world
      expect(roll_result).to be_valid
    end
  end

  describe "roll_result_defender" do
    it "is optional" do
      roll_result.roll_result_defender = nil
      expect(roll_result).to be_valid
    end

    it "rejects non-integers" do
      roll_result.roll_result_defender = 2.5
      expect(roll_result).not_to be_valid
    end
  end

  describe "#contested?" do
    it "is false without a defender roll" do
      expect(roll_result).not_to be_contested
    end

    it "is true with a defender roll" do
      roll_result.roll_result_defender = 4
      expect(roll_result).to be_contested
    end
  end

  describe "#result" do
    it "looks up the result on the roll table" do
      expect(roll_result.result).to eq("outcome")
    end
  end
end
