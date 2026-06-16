# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarration::ToolDefinitions do
  subject(:definitions) { described_class.new(scene) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) { world.characters.create!(character_attributes) }
  let(:scene) do
    world.scenes.create!(user: user, character: character, premise: "A premise.",
                         end_trigger: "An ending.", play_mode: "narrator",)
  end

  def character_attributes(name: "Kara")
    {
      name: name, sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def empty_enums(tools)
    tools.flat_map do |tool|
      properties = tool.dig(:function, :parameters, :properties) || {}
      properties.filter_map { |name, schema| name if schema.dig(:items, :enum) == [] || schema[:enum] == [] }
    end
  end

  def tool_names(tools)
    tools.map { |tool| tool.dig(:function, :name) }
  end

  it "offers only declare_intent during the intent phase" do
    expect(tool_names(definitions.intent_tools)).to eq(%w[declare_intent])
  end

  it "offers only prose and end_scene during narration" do
    expect(tool_names(definitions.narration_tools)).to contain_exactly("prose", "end_scene")
  end

  it "never emits an empty enum, which Grok rejects with a 400" do
    world.roll_tables.create!(denomination: 6, quantity: 1, description: "A table",
                              possible_results: [{ "min" => nil, "max" => nil, "result" => "x" }],)
    expect(empty_enums(definitions.intent_tools)).to be_empty
  end

  it "lists the world's library tables as suggestable ids" do
    table = world.roll_tables.create!(denomination: 6, quantity: 1, description: "A table",
                                      possible_results: [{ "min" => nil, "max" => nil, "result" => "x" }],)
    schema = definitions.intent_tools.first.dig(:function, :parameters, :properties, :suggested_roll_table_ids)
    expect(schema.dig(:items, :enum)).to eq([table.id])
  end

  it "falls back to a plain integer when the world has no library tables" do
    schema = definitions.intent_tools.first.dig(:function, :parameters, :properties, :suggested_roll_table_ids)
    expect(schema[:items]).to eq({ type: "integer" })
  end
end
