# frozen_string_literal: true

require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { scene.events.new(action_type: "narrate") }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) do
    world.characters.create!(
      name: "Kara", sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    )
  end
  let(:scene) do
    world.scenes.create!(user: user, character: character, premise: "A premise.",
                         end_trigger: "An ending.", play_mode: "narrator",)
  end

  it "is valid with an allowed action type and default status" do
    expect(event).to be_valid
  end

  it "requires a scene" do
    event.scene = nil
    expect(event).not_to be_valid
  end

  describe "action_type" do
    it "accepts force_act" do
      event.action_type = "force_act"
      expect(event).to be_valid
    end

    it "rejects unknown values" do
      event.action_type = "improvise"
      expect(event).not_to be_valid
    end
  end

  describe "status" do
    it "rejects unknown values" do
      event.status = "thinking"
      expect(event).not_to be_valid
    end
  end

  describe "associations" do
    it "destroys its roll results" do
      event.save!
      table = RollTable.create!(denomination: 6, quantity: 1, description: "d6",
                                possible_results: [{ "min" => nil, "max" => nil, "result" => "x" }],)
      event.roll_results.create!(roll_table: table, roll_result: 3)
      expect { event.destroy }.to change(RollResult, :count).by(-1)
    end

    it "destroys its grok calls" do
      event.save!
      event.grok_calls.create!(payload: { model: "grok" })
      expect { event.destroy }.to change(GrokCall, :count).by(-1)
    end
  end

  describe "state helpers" do
    it "reports complete" do
      event.status = "complete"
      expect(event).to be_complete
    end

    it "treats a working status as pending" do
      event.status = "narrating"
      expect(event).to be_pending
    end
  end

  it "orders chronologically" do
    event.save!
    later = scene.events.create!(action_type: "narrate")
    expect(scene.events.chronological.to_a).to eq([event, later])
  end
end
