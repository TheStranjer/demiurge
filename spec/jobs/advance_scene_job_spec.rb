# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdvanceSceneJob do
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
  let(:event) { scene.events.create!(status: "pending") }

  it "increments the attempt counter" do
    allow(SceneNarration::IntentDeclarer).to receive(:call).and_return(:awaiting_gm)
    expect { described_class.perform_now(event) }.to change { event.reload.attempts }.by(1)
  end

  describe "phase dispatch" do
    it "runs the intent declarer while the event is pending" do
      allow(SceneNarration::IntentDeclarer).to receive(:call).and_return(:awaiting_gm)
      described_class.perform_now(event)
      expect(SceneNarration::IntentDeclarer).to have_received(:call).with(event)
    end

    it "runs the narrator once the Game Master has rolled" do
      event.update!(status: "rolled")
      allow(SceneNarrator).to receive(:call).and_return(:complete)
      described_class.perform_now(event)
      expect(SceneNarrator).to have_received(:call).with(event)
    end
  end

  context "when a phase reaches a terminal outcome" do
    it "does not reschedule after the intent is awaiting the Game Master" do
      allow(SceneNarration::IntentDeclarer).to receive(:call).and_return(:awaiting_gm)
      expect { described_class.perform_now(event) }.not_to have_enqueued_job(described_class)
    end

    it "does not reschedule after narration completes" do
      event.update!(status: "rolled")
      allow(SceneNarrator).to receive(:call).and_return(:complete)
      expect { described_class.perform_now(event) }.not_to have_enqueued_job(described_class)
    end

    it "skips work once the event is already complete" do
      event.update!(status: "complete")
      allow(SceneNarration::IntentDeclarer).to receive(:call)
      described_class.perform_now(event)
      expect(SceneNarration::IntentDeclarer).not_to have_received(:call)
    end

    it "skips work while the event waits for the Game Master" do
      event.update!(status: "awaiting_gm")
      allow(SceneNarrator).to receive(:call)
      described_class.perform_now(event)
      expect(SceneNarrator).not_to have_received(:call)
    end
  end

  context "when a phase does not finish" do
    before do
      event.update!(status: "rolled")
      allow(SceneNarrator).to receive(:call).and_return(:unvalidated)
    end

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
