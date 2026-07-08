# frozen_string_literal: true

require "rails_helper"

RSpec.describe RollTable, type: :model do
  subject(:roll_table) { described_class.new(valid_attributes) }

  let(:world) do
    User.create!(username: "alice", password: "password123", password_confirmation: "password123")
        .worlds.create!(title: "Aerth", core_concept: "Floating islands.")
  end
  let(:valid_attributes) do
    {
      world: world,
      denomination: 6,
      quantity: 1,
      description: "Roll for hair color when generating a character.",
      possible_results: [
        { "min" => 1, "max" => 1, "result" => "blonde" },
        { "min" => 2, "max" => 2, "result" => "brunette" },
        { "min" => 3, "max" => 3, "result" => "black" },
        { "min" => 4, "max" => 4, "result" => "red" },
        { "min" => 5, "max" => 5, "result" => "gray" },
        { "min" => 6, "max" => 6, "result" => "white" },
      ],
    }
  end

  it "is valid with all attributes present" do
    expect(roll_table).to be_valid
  end

  describe "denomination" do
    it "is required" do
      roll_table.denomination = nil
      expect(roll_table).not_to be_valid
    end

    it "rejects values below 1" do
      roll_table.denomination = 0
      expect(roll_table).not_to be_valid
    end

    it "rejects non-integers" do
      roll_table.denomination = 1.5
      expect(roll_table).not_to be_valid
    end
  end

  describe "quantity" do
    it "is required" do
      roll_table.quantity = nil
      expect(roll_table).not_to be_valid
    end

    it "rejects values below 1" do
      roll_table.quantity = 0
      expect(roll_table).not_to be_valid
    end

    it "accepts multiple dice" do
      roll_table.quantity = 3
      expect(roll_table).to be_valid
    end
  end

  describe "description" do
    it "is required" do
      roll_table.description = nil
      expect(roll_table).not_to be_valid
    end
  end

  describe "possible_results" do
    it "rejects an empty array" do
      roll_table.possible_results = []
      expect(roll_table).not_to be_valid
    end

    it "rejects a non-array value" do
      roll_table.possible_results = "blonde"
      expect(roll_table).not_to be_valid
    end

    it "rejects rows that are not hashes" do
      roll_table.possible_results = ["blonde"]
      expect(roll_table).not_to be_valid
    end

    it "rejects rows missing a result key" do
      roll_table.possible_results = [{ "min" => 1, "max" => 1 }]
      expect(roll_table).not_to be_valid
    end

    it "rejects rows with unexpected keys" do
      roll_table.possible_results = [{ "min" => 1, "max" => 1, "result" => "blonde", "extra" => true }]
      expect(roll_table).not_to be_valid
    end

    it "rejects rows with a non-integer bound" do
      roll_table.possible_results = [{ "min" => "low", "max" => 1, "result" => "blonde" }]
      expect(roll_table).not_to be_valid
    end

    it "accepts unbounded rows" do
      roll_table.possible_results = [{ "min" => nil, "max" => nil, "result" => "anything" }]
      expect(roll_table).to be_valid
    end

    it "accepts a nil result" do
      roll_table.possible_results = [{ "min" => 1, "max" => 1, "result" => nil }]
      expect(roll_table).to be_valid
    end
  end

  describe "#result_for" do
    it "returns the matching result" do
      expect(roll_table.result_for(4)).to eq("red")
    end

    it "returns nil when nothing matches" do
      expect(roll_table.result_for(99)).to be_nil
    end

    it "matches an open-ended lower bound" do
      roll_table.possible_results = [{ "min" => nil, "max" => 1, "result" => "1ft" }]
      expect(roll_table.result_for(-3)).to eq("1ft")
    end

    it "matches an open-ended upper bound" do
      roll_table.possible_results = [{ "min" => 8, "max" => nil, "result" => "huge" }]
      expect(roll_table.result_for(40)).to eq("huge")
    end
  end

  describe "roll range helpers" do
    it "computes the minimum roll" do
      roll_table.quantity = 3
      expect(roll_table.minimum_roll).to eq(3)
    end

    it "computes the maximum roll" do
      roll_table.quantity = 3
      roll_table.denomination = 8
      expect(roll_table.maximum_roll).to eq(24)
    end
  end

  it "destroys its roll results when destroyed" do
    roll_table.save!
    roll_table.roll_results.create!(roll_result: 4, entity: world)
    expect { roll_table.destroy }.to change(RollResult, :count).by(-1)
  end

  it "requires a world" do
    roll_table.world = nil
    expect(roll_table).not_to be_valid
  end

  it "defaults to not being a suggestion" do
    expect(described_class.new.suggestion).to be(false)
  end

  describe "contested" do
    it "defaults to false" do
      expect(described_class.new.contested).to be(false)
    end
  end

  describe "stat modifiers" do
    it "defaults both modifier lists to empty" do
      table = described_class.new
      expect(table.entity_modifiers).to eq([])
      expect(table.defender_modifiers).to eq([])
    end

    it "accepts real stats" do
      roll_table.entity_modifiers = ["finesse"]
      roll_table.defender_modifiers = ["awareness"]
      expect(roll_table).to be_valid
    end

    it "rejects a modifier that is not a real stat" do
      roll_table.entity_modifiers = ["luck"]
      expect(roll_table).not_to be_valid
    end

    it "strips blanks and duplicates before validating" do
      roll_table.entity_modifiers = ["finesse", "finesse", "", " "]
      roll_table.save!
      expect(roll_table.entity_modifiers).to eq(["finesse"])
    end
  end

  describe "scopes" do
    it "separates library tables from suggestions" do
      library = world.roll_tables.create!(valid_attributes.merge(suggestion: false))
      suggestion = world.roll_tables.create!(valid_attributes.merge(suggestion: true))
      expect(described_class.library).to include(library)
      expect(described_class.library).not_to include(suggestion)
      expect(described_class.suggestions).to include(suggestion)
      expect(described_class.suggestions).not_to include(library)
    end
  end
end
