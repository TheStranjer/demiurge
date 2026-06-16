# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarrator do
  subject(:narrate) { described_class.call(event) }

  let(:table) do
    RollTable.create!(denomination: 6, quantity: 1, description: "Weather severity",
                      possible_results: [{ "min" => nil, "max" => nil, "result" => "harsh" }],)
  end
  let(:event) do
    user = User.create!(username: "alice", password: "password123", password_confirmation: "password123")
    world = user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
    character = world.characters.create!(character_attributes)
    scene = world.scenes.create!(user: user, character: character, premise: "A duel begins.",
                                 end_trigger: "End when someone yields.", play_mode: "narrator",)
    scene.events.create!(action_type: "narrate", directive: "A storm rolls in.")
  end

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

  def roll_message
    message([tool_call("c1", "roll_tables", { roll_table_ids: [table.id] })])
  end

  def prose_message
    message([tool_call("c2", "prose", { text: "Rain lashes the courtyard." })])
  end

  def validation_message(follows:)
    message([tool_call("c3", "validate_result", { follows: follows })])
  end

  context "when the prose follows from a roll" do
    before { stub_grok(roll_message, prose_message, validation_message(follows: true)) }

    it "returns complete" do
      expect(narrate).to eq(:complete)
    end

    it "records the rolled result against the event" do
      narrate
      expect(event.roll_results.count).to eq(1)
      expect(event.roll_results.first.roll_table).to eq(table)
    end

    it "stores the prose and marks the event complete" do
      narrate
      expect(event.reload).to have_attributes(prose: "Rain lashes the courtyard.", status: "complete",
                                              validated: true, ended_scene: false,)
    end
  end

  context "when validation fails" do
    before { stub_grok(roll_message, prose_message, validation_message(follows: false)) }

    it "returns unvalidated" do
      expect(narrate).to eq(:unvalidated)
    end

    it "does not mark the event complete" do
      narrate
      expect(event.reload.validated).to be(false)
      expect(event.reload).not_to be_complete
    end
  end

  context "when the model ends the scene" do
    before do
      end_message = message([tool_call("c2", "end_scene", { text: "The duel is over." })])
      stub_grok(roll_message, end_message, validation_message(follows: true))
    end

    it "finishes the scene" do
      narrate
      expect(event.scene.reload).to be_finished
      expect(event.reload.ended_scene).to be(true)
    end
  end

  context "when no roll is produced first" do
    before { stub_grok(message([tool_call("c1", "roll_tables", { roll_table_ids: [] })])) }

    it "fails without proceeding to prose" do
      expect(narrate).to eq(:failed)
      expect(event.roll_results).to be_empty
    end
  end

  context "when a character arrives" do
    it "adds the character to the scene" do
      newcomer = event.scene.world.characters.create!(character_attributes(name: "Bram"))
      arrive_message = message([tool_call("c2", "character_arrive", { character_id: newcomer.id })])
      stub_grok(roll_message, arrive_message, prose_message, validation_message(follows: true))
      narrate
      expect(event.scene.present_characters).to include(newcomer)
    end
  end
end
