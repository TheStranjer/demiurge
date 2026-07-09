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
    world.roll_tables.create!(
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

  describe "stat modifiers" do
    def defender
      world.characters.create!(
        name: "Bram", sex: "male", non_player_character: true,
        strength: 1, dexterity: 2, endurance: 3,
        intelligence: 0, awareness: 2, willpower: 5,
        charisma: -5, finesse: 1, tact: -2,
      )
    end

    def contested_table
      world.roll_tables.create!(
        denomination: 20, quantity: 1, description: "Deceive.", contested: true,
        entity_modifiers: ["finesse"], defender_modifiers: ["awareness"],
        possible_results: [{ "min" => nil, "max" => 7, "result" => "seen through" },
                           { "min" => 8, "max" => nil, "result" => "believed" },],
      )
    end

    def contested_roll(defender: self.defender)
      contested_table.roll_results.new(roll_result: 6, entity: character, character: character, defender: defender)
    end

    it "adds the acting character's stat and subtracts the defender's" do
      expect(contested_roll.modified_roll_result).to eq(8)
    end

    it "resolves the result against the modified total" do
      expect(contested_roll.result).to eq("believed")
    end

    it "omits the defender debuff when no defender is present" do
      expect(contested_roll(defender: nil).modified_roll_result).to eq(10)
    end

    it "applies no modifiers when the acting character is absent" do
      roll = contested_roll(defender: nil)
      roll.character = nil
      expect(roll.modified_roll_result).to eq(6)
    end

    it "breaks each modifier down by stat and value" do
      expect(contested_roll.modifier_descriptions).to eq(["+ finesse (+4)", "- awareness (+2)"])
    end

    it "snapshots the modifiers so later stat changes do not move the total" do
      roll = contested_roll
      roll.save!
      character.update!(finesse: 0)
      expect(roll.reload.modified_roll_result).to eq(8)
    end

    it "snapshots the breakdown so later stat changes do not rewrite it" do
      roll = contested_roll
      roll.save!
      character.update!(finesse: 0)
      expect(roll.reload.modifier_descriptions).to eq(["+ finesse (+4)", "- awareness (+2)"])
    end
  end

  describe "manual modifier" do
    it "adds a positive manual modifier on top of the stat modifiers" do
      roll_result.manual_modifier = 3
      expect(roll_result.modified_roll_result).to eq(9)
    end

    it "subtracts a negative manual modifier" do
      roll_result.manual_modifier = -2
      expect(roll_result.modified_roll_result).to eq(4)
    end

    it "lists the manual modifier in the breakdown" do
      roll_result.manual_modifier = 3
      expect(roll_result.modifier_descriptions).to eq(["+ manual (+3)"])
    end

    it "omits a zero manual modifier from the breakdown" do
      roll_result.manual_modifier = 0
      expect(roll_result.modifier_descriptions).to eq([])
    end

    it "snapshots the manual modifier alongside the stat modifiers" do
      roll_result.manual_modifier = 3
      roll_result.save!
      roll_result.update!(manual_modifier: 0)
      expect(roll_result.reload.modified_roll_result).to eq(9)
    end
  end
end
