# frozen_string_literal: true

require "rails_helper"

RSpec.describe NarrateSceneJob do
  include ActiveJob::TestHelper

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
  let(:event) { scene.events.create!(action_type: "narrate") }

  it "increments the attempt counter" do
    allow(SceneNarrator).to receive(:call).and_return(:complete)
    expect { described_class.perform_now(event) }.to change { event.reload.attempts }.by(1)
  end

  context "when narration completes" do
    before { allow(SceneNarrator).to receive(:call).and_return(:complete) }

    it "does not reschedule" do
      expect { described_class.perform_now(event) }.not_to have_enqueued_job(described_class)
    end

    it "skips work once the event is already complete" do
      event.update!(status: "complete")
      described_class.perform_now(event)
      expect(SceneNarrator).not_to have_received(:call)
    end
  end

  context "when narration does not complete" do
    before { allow(SceneNarrator).to receive(:call).and_return(:unvalidated) }

    it "reschedules itself with exponential backoff" do
      expect { described_class.perform_now(event) }
        .to have_enqueued_job(described_class).with(event).at(a_value > Time.current)
    end

    it "marks the event failed once attempts are exhausted" do
      event.update!(attempts: described_class::MAX_ATTEMPTS - 1)
      expect { described_class.perform_now(event) }.not_to have_enqueued_job(described_class)
      expect(event.reload.status).to eq("failed")
    end
  end
end
