# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Events", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create_user(username: "alice") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) { world.characters.create!(character_attributes) }

  def character_attributes
    {
      name: "Kara", sex: "female", non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def create_scene(play_mode: "narrator", finished_at: nil)
    world.scenes.create!(user: user, character: character, premise: "A premise.",
                         end_trigger: "An ending.", play_mode: play_mode, finished_at: finished_at,)
  end

  describe "when logged out" do
    it "redirects to the login page without creating an event" do
      scene = create_scene
      expect { post world_scene_events_path(world, scene), params: { event: { action_type: "narrate" } } }
        .not_to change(Event, :count)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "when logged in" do
    before { sign_in(user) }

    it "creates an event and enqueues the narration job" do
      scene = create_scene
      expect do
        post world_scene_events_path(world, scene), params: { event: { action_type: "narrate", directive: "Storm." } }
      end.to change(Event, :count).by(1).and have_enqueued_job(NarrateSceneJob)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses to create events in a player-mode scene" do
      scene = create_scene(play_mode: "player")
      expect { post world_scene_events_path(world, scene), params: { event: { action_type: "narrate" } } }
        .not_to change(Event, :count)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses to create events in a finished scene" do
      scene = create_scene(finished_at: Time.current)
      expect { post world_scene_events_path(world, scene), params: { event: { action_type: "force_act" } } }
        .not_to change(Event, :count)
    end

    it "renders completed events on the scene page in chronological order" do
      scene = create_scene
      scene.events.create!(action_type: "narrate", directive: "A storm.", prose: "Rain falls.", status: "complete")
      get world_scene_path(world, scene)
      expect(response.body).to include("Rain falls.").and include("A storm.")
    end

    it "renders the raw Grok input and output for an event" do
      scene = create_scene
      event = scene.events.create!(action_type: "narrate", directive: "A storm.")
      event.grok_calls.create!(payload: { "model" => "grok-4.3" }, response: { "id" => "abc" }, status: 200)
      get world_scene_path(world, scene)
      expect(response.body).to include("Grok calls").and include("grok-4.3").and include("abc")
    end
  end
end
