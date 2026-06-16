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
  let(:event) { scene.events.create!(action_type: "narrate", directive: "A storm rolls in.") }

  def character_attributes(name: "Kara")
    {
      name: name, sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def system_content
    prompt.base_messages.first.fetch(:content)
  end

  it "omits the previous-scenes block when there are no finished scenes" do
    expect(system_content).not_to include("Summaries of previous scenes")
  end

  it "funnels summaries of previously finished scenes into the system prompt" do
    world.scenes.create!(user: user, character: character, premise: "An earlier tale.",
                         end_trigger: "It ends.", play_mode: "narrator",)
         .finish!(summary: "Kara escaped the citadel.")

    expect(system_content).to include("Summaries of previous scenes:\n- Kara escaped the citadel.")
  end

  it "ignores finished scenes that lack a summary" do
    world.scenes.create!(user: user, character: character, premise: "A quiet day.",
                         end_trigger: "It ends.", play_mode: "narrator",)
         .finish!

    expect(system_content).not_to include("Summaries of previous scenes")
  end
end
