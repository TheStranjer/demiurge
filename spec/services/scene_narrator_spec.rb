# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarrator do
  subject(:narrate) { described_class.call(event) }

  let(:world) do
    User.create!(username: "alice", password: "password123", password_confirmation: "password123")
        .worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
  end
  let(:character) { world.characters.create!(character_attributes) }
  let(:scene) do
    world.scenes.create!(user: world.user, character: character, premise: "A duel begins.",
                         end_trigger: "End when someone yields.", play_mode: "narrator",)
  end
  let(:table) do
    world.roll_tables.create!(denomination: 6, quantity: 1, description: "Strike severity",
                              possible_results: [{ "min" => nil, "max" => nil, "result" => "glancing" }],)
  end
  let(:event) do
    scene.events.create!(intent: "Kara strikes at the bandit.", status: "rolled").tap do |created|
      created.roll_results.create!(roll_table: table, roll_result: 4)
    end
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

  def prose_message
    message([tool_call("c1", "prose", { text: "Kara's blade grazes the bandit's arm." })])
  end

  def validation_message(follows:, reason: "")
    message([tool_call("c2", "validate_result", { follows: follows, reason: reason })])
  end

  context "when the prose passes validation" do
    before { stub_grok(prose_message, validation_message(follows: true)) }

    it "returns complete" do
      expect(narrate).to eq(:complete)
    end

    it "stores the prose and marks the event complete" do
      narrate
      expect(event.reload).to have_attributes(prose: "Kara's blade grazes the bandit's arm.",
                                              status: "complete", validated: true, ended_scene: false,)
    end

    it "keeps the rolls the Game Master already made" do
      expect { narrate }.not_to change(event.roll_results, :count)
    end
  end

  context "when validation keeps failing" do
    before do
      stub_grok(prose_message, validation_message(follows: false),
                prose_message, validation_message(follows: false),
                prose_message, validation_message(follows: false),)
    end

    it "returns unvalidated after exhausting the retries" do
      expect(narrate).to eq(:unvalidated)
    end

    it "does not mark the event complete" do
      narrate
      expect(event.reload.validated).to be(false)
      expect(event.reload).not_to be_complete
    end
  end

  context "when validation reports a reason" do
    it "feeds that reason back into a later narration request" do
      bodies = [prose_message, validation_message(follows: false, reason: "Bram never existed."),
                prose_message, validation_message(follows: true),]
      seen = []
      allow(GrokService).to receive(:call) do |**kwargs|
        seen << kwargs[:messages]
        bodies.shift
      end

      narrate

      expect(seen.flatten).to include(a_hash_including(content: a_string_including("Bram never existed.")))
    end
  end

  context "when the model ends the scene" do
    before do
      end_message = message([tool_call("c1", "end_scene",
                                       { text: "The duel is over.", summary: "Kara wins the duel." })])
      stub_grok(end_message, validation_message(follows: true))
    end

    it "finishes the scene and stores the summary" do
      narrate
      expect(event.scene.reload).to be_finished
      expect(event.reload.ended_scene).to be(true)
      expect(event.scene.summary).to eq("Kara wins the duel.")
    end
  end

  context "when no roll tables were used" do
    let(:event) { scene.events.create!(intent: "Kara breathes.", status: "rolled") }

    before { stub_grok(prose_message, validation_message(follows: true)) }

    it "still narrates the automatic success" do
      expect(narrate).to eq(:complete)
      expect(event.reload.prose).to be_present
    end
  end
end
