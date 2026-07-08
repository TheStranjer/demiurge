# frozen_string_literal: true

require "rails_helper"

RSpec.describe SceneNarration::Prompt do
  subject(:prompt) { described_class.new(event) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) { world.characters.create!(character_attributes) }
  let(:scene) do
    world.scenes.create!(user: user, character: character, premise: "A duel begins.",
                         end_trigger: "End when someone yields.", play_mode: "narrator",)
  end
  let(:event) { scene.events.create!(directive: "A storm rolls in.", intent: "Kara takes cover.", status: "rolled") }

  def character_attributes(name: "Kara")
    {
      name: name, sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def intent_system_content
    prompt.intent_messages.first.fetch(:content)
  end

  def narration_system_content
    prompt.narration_messages.first.fetch(:content)
  end

  describe "#intent_messages" do
    it "casts the model as the player and forbids godmodding" do
      expect(intent_system_content).to include("You are playing Kara")
      expect(intent_system_content).to include("never the outcome")
      expect(intent_system_content).to include("another character's actions, decisions, or fate")
    end

    it "lists the world's library tables with their ids" do
      table = world.roll_tables.create!(denomination: 6, quantity: 1, description: "Storm severity",
                                        possible_results: [{ "min" => nil, "max" => nil, "result" => "harsh" }],)
      expect(intent_system_content).to include("##{table.id}: Storm severity")
    end

    it "uses the Game Master's guidance as the current situation" do
      expect(prompt.intent_messages.last.fetch(:content)).to eq("A storm rolls in.")
    end

    it "shows a worked example table when the world has no library tables yet" do
      expect(intent_system_content).to include("Degree of success on an uncertain attempt")
      expect(intent_system_content).to include("\"denomination\": 6")
      expect(intent_system_content).to include("\"max\": null")
    end
  end

  describe "scene history" do
    before do
      scene.events.create!(directive: "Set the stage.", intent: "Kara lunges.",
                           prose: "Kara lunges across the dueling floor.", status: "complete",)
    end

    it "feeds prior prose to the player without ever speaking in the assistant role" do
      roles = prompt.intent_messages.map { |message| message.fetch(:role) }
      contents = prompt.intent_messages.map { |message| message.fetch(:content) }.join("\n")
      expect(roles).not_to include("assistant")
      expect(contents).to include("Kara lunges across the dueling floor.")
    end

    it "never replays the player's declared intent back to them" do
      contents = prompt.intent_messages.map { |message| message.fetch(:content) }.join("\n")
      expect(contents).not_to include("Intent: Kara lunges.")
    end
  end

  describe "#narration_messages" do
    it "supplies the declared intent and asks for prose or end_scene" do
      content = prompt.narration_messages.last.fetch(:content)
      expect(content).to include("Kara takes cover.")
      expect(content).to include("prose")
    end

    it "notes an automatic success when no tables were rolled" do
      expect(prompt.narration_messages.last.fetch(:content)).to include("the attempt simply succeeds")
    end

    it "summarizes the rolls when tables were used" do
      table = world.roll_tables.create!(denomination: 6, quantity: 1, description: "Storm severity",
                                        possible_results: [{ "min" => nil, "max" => nil, "result" => "harsh" }],)
      event.roll_results.create!(roll_table: table, roll_result: 5)
      expect(prompt.narration_messages.last.fetch(:content)).to include("Storm severity => rolled 5 (harsh)")
    end

    it "spells out the stat modifiers that adjusted a roll" do
      table = world.roll_tables.create!(denomination: 20, quantity: 1, description: "Deceive", contested: true,
                                        entity_modifiers: ["finesse"], defender_modifiers: ["awareness"],
                                        possible_results: [{ "min" => nil, "max" => nil, "result" => "believed" }],)
      foe = world.characters.create!(character_attributes(name: "Bram").merge(awareness: 2))
      event.roll_results.create!(roll_table: table, roll_result: 6, character: character, defender: foe)
      expect(prompt.narration_messages.last.fetch(:content))
        .to include("rolled 6 + finesse (+4) - awareness (+2) = 8 (believed)")
    end
  end

  describe "previous-scene summaries" do
    it "omits the block when there are no finished scenes" do
      expect(intent_system_content).not_to include("Summaries of previous scenes")
    end

    it "funnels finished-scene summaries into the system prompt" do
      world.scenes.create!(user: user, character: character, premise: "An earlier tale.",
                           end_trigger: "It ends.", play_mode: "narrator",)
           .finish!(summary: "Kara escaped the citadel.")
      expect(intent_system_content).to include("Summaries of previous scenes:\n- Kara escaped the citadel.")
    end
  end

  describe "#intent_validation_messages" do
    it "instructs the validator to reject godmodded intent" do
      instructions = prompt.intent_validation_messages("Kara wins").first.fetch(:content)
      expect(instructions).to include("godmods")
      expect(instructions).to include("already succeeded")
    end

    it "includes the intent under review" do
      expect(prompt.intent_validation_messages("Kara wins").last.fetch(:content)).to include("Kara wins")
    end
  end

  describe "#validation_messages" do
    def contents
      prompt.validation_messages("Some prose.").map { |message| message.fetch(:content) }
    end

    it "lists the characters that actually exist for the validator" do
      character
      world.characters.create!(character_attributes(name: "Bram"))
      expect(contents.join("\n\n")).to include("The only characters that exist are:\n- Kara\n- Bram")
    end

    it "instructs the validator to reject invented characters and godmodding" do
      instructions = contents.first
      expect(instructions).to include("character invented out of nowhere fails this check")
      expect(instructions).to include("Nobody godmods")
    end

    it "includes the prose under review" do
      expect(contents.last).to eq("Prose to validate:\nSome prose.")
    end
  end
end
