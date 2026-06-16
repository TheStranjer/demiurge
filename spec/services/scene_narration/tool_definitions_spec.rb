# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarration::ToolDefinitions do
  subject(:definitions) { described_class.new(scene) }

  let(:scene) do
    user = User.create!(username: "alice", password: "password123", password_confirmation: "password123")
    world = user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
    character = world.characters.create!(character_attributes)
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
      properties.filter_map { |name, schema| name if schema[:enum] == [] }
    end
  end

  def tool_names(tools)
    tools.map { |tool| tool.dig(:function, :name) }
  end

  it "never emits an empty enum, which Grok rejects with a 400" do
    expect(empty_enums(definitions.full_tools)).to be_empty
  end

  it "omits character_arrive when no one can arrive" do
    expect(tool_names(definitions.full_tools)).not_to include("character_arrive")
  end

  it "offers character_arrive with candidates once an absent character exists" do
    scene.world.characters.create!(character_attributes(name: "Bram"))
    expect(tool_names(definitions.full_tools)).to include("character_arrive")
    expect(empty_enums(definitions.full_tools)).to be_empty
  end
end
