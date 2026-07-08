# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarration::IntentDeclarer do
  subject(:declare) { described_class.call(event) }

  let(:world) do
    User.create!(username: "alice", password: "password123", password_confirmation: "password123")
        .worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
  end
  let(:character) { world.characters.create!(character_attributes) }
  let(:scene) do
    world.scenes.create!(user: world.user, character: character, premise: "A duel begins.",
                         end_trigger: "End when someone yields.", play_mode: "narrator",)
  end
  let(:existing_table) do
    world.roll_tables.create!(denomination: 6, quantity: 1, description: "Existing strike table",
                              possible_results: [{ "min" => nil, "max" => nil, "result" => "hit" }],)
  end
  let(:event) { scene.events.create!(status: "pending") }

  def character_attributes(name: "Kara")
    {
      name: name, sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def message(tool_calls)
    { "choices" => [{ "message" => { "role" => "assistant", "tool_calls" => tool_calls } }] }
  end

  def tool_call(id, name, arguments)
    { "id" => id, "type" => "function", "function" => { "name" => name, "arguments" => arguments.to_json } }
  end

  def stub_grok(*bodies)
    allow(GrokService).to receive(:call).and_return(*bodies)
  end

  def declare_message(intent: "Kara lunges at the bandit.", suggested_ids: [], new_tables: [])
    message([tool_call("c1", "declare_intent",
                       { intent: intent, suggested_roll_table_ids: suggested_ids, new_tables: new_tables })])
  end

  def validation_message(follows:, reason: "")
    message([tool_call("c2", "validate_result", { follows: follows, reason: reason })])
  end

  def new_table_definition
    { description: "Lunge accuracy", denomination: 20, quantity: 1,
      possible_results: [{ min: nil, max: nil, result: "grazes" }], }
  end

  context "when the intent passes validation" do
    before do
      stub_grok(declare_message(suggested_ids: [existing_table.id], new_tables: [new_table_definition]),
                validation_message(follows: true),)
    end

    it "stores the intent and waits for the Game Master" do
      expect(declare).to eq(:awaiting_gm)
      expect(event.reload).to have_attributes(intent: "Kara lunges at the bandit.", status: "awaiting_gm",
                                              validated: true,)
    end

    it "records the suggested existing table ids" do
      declare
      expect(event.reload.suggested_roll_table_ids).to eq([existing_table.id])
    end

    it "creates the proposed new tables as world-scoped suggestions" do
      expect { declare }.to change { world.roll_tables.suggestions.count }.by(1)
      suggestion = event.reload.proposed_roll_tables.first
      expect(suggestion).to have_attributes(description: "Lunge accuracy", suggestion: true, world_id: world.id)
    end
  end

  context "when a proposed table duplicates an existing library table" do
    before do
      stub_grok(declare_message(new_tables: [new_table_definition.merge(description: "  EXISTING   strike table ")]),
                validation_message(follows: true),)
    end

    it "reuses the library table instead of creating a duplicate suggestion" do
      existing_table
      expect { declare }.not_to(change { world.roll_tables.suggestions.count })
      expect(event.reload.suggested_roll_table_ids).to eq([existing_table.id])
    end
  end

  context "when the same new table is proposed twice in one turn" do
    before do
      stub_grok(declare_message(new_tables: [new_table_definition, new_table_definition.merge(quantity: 2)]),
                validation_message(follows: true),)
    end

    it "creates the table only once" do
      expect { declare }.to change { world.roll_tables.suggestions.count }.by(1)
    end
  end

  context "when the validator rejects godmodding once, then passes" do
    before do
      stub_grok(declare_message(intent: "Kara kills the bandit instantly."),
                validation_message(follows: false, reason: "The intent dictates the bandit's death."),
                declare_message(intent: "Kara swings hard at the bandit."),
                validation_message(follows: true),)
    end

    it "redeclares and ends up awaiting the Game Master" do
      expect(declare).to eq(:awaiting_gm)
      expect(event.reload.intent).to eq("Kara swings hard at the bandit.")
    end

    it "does not leave stale suggestions from the rejected attempt" do
      stub_grok(declare_message(new_tables: [new_table_definition]),
                validation_message(follows: false, reason: "godmod"),
                declare_message(new_tables: [new_table_definition]),
                validation_message(follows: true),)
      declare
      expect(event.reload.proposed_roll_tables.count).to eq(1)
    end
  end

  context "when the validator keeps rejecting the intent" do
    before do
      stub_grok(declare_message, validation_message(follows: false, reason: "godmod"),
                declare_message, validation_message(follows: false, reason: "godmod"),
                declare_message, validation_message(follows: false, reason: "godmod"),)
    end

    it "fails without reaching the Game Master" do
      expect(declare).to eq(:failed)
      expect(event.reload).not_to be_awaiting_gm
    end
  end
end
