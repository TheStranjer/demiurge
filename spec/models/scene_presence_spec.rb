# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScenePresence, type: :model do
  subject(:presence) { scene.scene_presences.new(character: arrival) }

  let(:user) { User.create!(username: "alice", password: "password123", password_confirmation: "password123") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:main_character) { build_character("Kara") }
  let(:arrival) { build_character("Bram") }
  let(:scene) do
    world.scenes.create!(user: user, character: main_character, premise: "A premise.",
                         end_trigger: "An ending.", play_mode: "narrator",)
  end

  def build_character(name)
    world.characters.create!(
      name: name, sex: "female", non_player_character: true,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    )
  end

  it "is valid for a character in the same world" do
    expect(presence).to be_valid
  end

  it "rejects a character from another world" do
    other = user.worlds.create!(title: "Other", core_concept: "Elsewhere.")
    presence.character = other.characters.create!(
      name: "Zed", sex: "male", non_player_character: true,
      strength: 0, dexterity: 0, endurance: 0,
      intelligence: 0, awareness: 0, willpower: 0,
      charisma: 0, finesse: 0, tact: 0,
    )
    expect(presence).not_to be_valid
  end

  it "rejects a duplicate character in the same scene" do
    presence.save!
    expect(scene.scene_presences.new(character: arrival)).not_to be_valid
  end

  describe "#depart!" do
    it "stamps departed_at" do
      presence.save!
      expect { presence.depart! }.to change { presence.reload.departed_at }.from(nil)
    end
  end

  describe ".present" do
    it "excludes departed presences" do
      presence.save!
      presence.depart!
      expect(scene.scene_presences.present).to be_empty
    end
  end
end
