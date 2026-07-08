# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarration::GmAdjudication do
  let(:world) do
    User.create!(username: "alice", password: "password123", password_confirmation: "password123")
        .worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
  end
  let(:scene) do
    character = world.characters.create!(character_attributes)
    world.scenes.create!(user: world.user, character: character, premise: "A duel.",
                         end_trigger: "Someone yields.", play_mode: "narrator",)
  end
  let(:event) { scene.events.create!(status: "awaiting_gm", intent: "Kara lunges.", attempts: 3) }
  let(:suggestion) do
    world.roll_tables.create!(suggestion: true, event: event, description: "Lunge", denomination: 20, quantity: 1,
                              possible_results: [{ "min" => nil, "max" => nil, "result" => "hit" }],)
  end
  let(:existing) do
    world.roll_tables.create!(description: "Weather", denomination: 6, quantity: 1,
                              possible_results: [{ "min" => nil, "max" => nil, "result" => "rain" }],)
  end

  def character_attributes
    {
      name: "Kara", sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def draft_rows
    [{ "min" => "1", "max" => "10", "result" => "miss" }, { "min" => "11", "max" => "20", "result" => "strikes" }]
  end

  it "advances the event to rolled and resets the attempt counter" do
    described_class.call(event, [])
    expect(event.reload).to have_attributes(status: "rolled", attempts: 0)
  end

  it "auto-succeeds with no rolls when nothing is selected" do
    expect { described_class.call(event, []) }.not_to change(event.roll_results, :count)
  end

  it "rolls an existing table chosen as-is" do
    payload = [{ "include" => "1", "source" => "existing", "roll_table_id" => existing.id.to_s }]
    described_class.call(event, payload)
    expect(event.roll_results.map(&:roll_table)).to eq([existing])
  end

  it "promotes an edited suggestion into the world library and rolls it" do
    payload = [{ "include" => "1", "source" => "draft", "origin_suggestion_id" => suggestion.id.to_s,
                 "description" => "Lunge accuracy", "denomination" => "20", "quantity" => "1",
                 "results" => draft_rows, }]
    described_class.call(event, payload)
    expect(suggestion.reload).to have_attributes(suggestion: false, description: "Lunge accuracy")
    expect(event.roll_results.map(&:roll_table)).to eq([suggestion])
  end

  it "creates a brand new world table from a draft with no origin" do
    payload = [{ "include" => "1", "source" => "draft", "description" => "Improvised gambit",
                 "denomination" => "6", "quantity" => "2", "results" => draft_rows, }]
    expect { described_class.call(event, payload) }.to change { world.roll_tables.library.count }.by(1)
    expect(event.roll_results.first.roll_table.description).to eq("Improvised gambit")
  end

  it "reuses an existing library table instead of creating a duplicate from a draft" do
    existing
    payload = [{ "include" => "1", "source" => "draft", "description" => "  WEATHER ",
                 "denomination" => "6", "quantity" => "1", "results" => draft_rows, }]
    expect { described_class.call(event, payload) }.not_to(change { world.roll_tables.library.count })
    expect(event.roll_results.map(&:roll_table)).to eq([existing])
  end

  it "reuses an existing library table instead of promoting a duplicate suggestion" do
    library = world.roll_tables.create!(description: "Lunge", denomination: 20, quantity: 1,
                                        possible_results: [{ "min" => nil, "max" => nil, "result" => "hit" }],)
    payload = [{ "include" => "1", "source" => "draft", "origin_suggestion_id" => suggestion.id.to_s,
                 "description" => "Lunge", "denomination" => "20", "quantity" => "1", "results" => draft_rows, }]
    expect { described_class.call(event, payload) }.not_to(change { world.roll_tables.library.count })
    expect(event.roll_results.map(&:roll_table)).to eq([library])
    expect(RollTable.exists?(suggestion.id)).to be(false)
  end

  it "discards suggestions the Game Master did not accept" do
    suggestion
    expect { described_class.call(event, []) }.to change(RollTable, :count).by(-1)
    expect(event.reload.proposed_roll_tables).to be_empty
  end

  it "ignores tables that are present but unchecked" do
    payload = [{ "include" => "0", "source" => "existing", "roll_table_id" => existing.id.to_s }]
    expect { described_class.call(event, payload) }.not_to change(event.roll_results, :count)
  end

  it "records the acting character on every roll" do
    payload = [{ "include" => "1", "source" => "existing", "roll_table_id" => existing.id.to_s }]
    described_class.call(event, payload)
    expect(event.roll_results.first).to have_attributes(character: scene.character, scene: scene, defender: nil)
  end

  it "records the chosen defender for a contested table" do
    foe = world.characters.create!(character_attributes.merge(name: "Bram"))
    contested = world.roll_tables.create!(description: "Deceive", denomination: 20, quantity: 1, contested: true,
                                          possible_results: [{ "min" => nil, "max" => nil, "result" => "hit" }],)
    payload = [{ "include" => "1", "source" => "existing", "roll_table_id" => contested.id.to_s,
                 "defender_id" => foe.id.to_s, }]
    described_class.call(event, payload)
    expect(event.roll_results.first.defender).to eq(foe)
  end

  it "brings an absent defender into the scene before rolling" do
    foe = world.characters.create!(character_attributes.merge(name: "Bram"))
    contested = world.roll_tables.create!(description: "Deceive", denomination: 20, quantity: 1, contested: true,
                                          possible_results: [{ "min" => nil, "max" => nil, "result" => "hit" }],)
    payload = [{ "include" => "1", "source" => "existing", "roll_table_id" => contested.id.to_s,
                 "defender_id" => foe.id.to_s, }]
    expect { described_class.call(event, payload) }.to change { scene.reload.present_characters.include?(foe) }
      .from(false).to(true)
  end

  it "persists contested and modifier stats on a promoted draft" do
    payload = [{ "include" => "1", "source" => "draft", "description" => "Feint", "denomination" => "20",
                 "quantity" => "1", "contested" => "1", "entity_modifiers" => ["finesse"],
                 "defender_modifiers" => ["awareness"], "results" => draft_rows, }]
    described_class.call(event, payload)
    table = event.roll_results.first.roll_table
    expect(table).to have_attributes(contested: true, entity_modifiers: ["finesse"], defender_modifiers: ["awareness"])
  end
end
