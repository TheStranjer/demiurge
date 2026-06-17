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

  describe "POST create when logged out" do
    it "redirects to the login page without creating an event" do
      scene = create_scene
      expect { post world_scene_events_path(world, scene), params: { event: { directive: "Go." } } }
        .not_to change(Event, :count)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "POST create when logged in" do
    before { sign_in(user) }

    it "starts a player turn and enqueues the advance job" do
      scene = create_scene
      expect do
        post world_scene_events_path(world, scene), params: { event: { directive: "A storm rolls in." } }
      end.to change(Event, :count).by(1).and have_enqueued_job(AdvanceSceneJob)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses to start a turn in a player-mode scene" do
      scene = create_scene(play_mode: "player")
      expect { post world_scene_events_path(world, scene), params: { event: { directive: "Go." } } }
        .not_to change(Event, :count)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses to start a turn in a finished scene" do
      scene = create_scene(finished_at: Time.current)
      expect { post world_scene_events_path(world, scene), params: { event: { directive: "Go." } } }
        .not_to change(Event, :count)
    end

    it "refuses to start a turn while another is already in progress" do
      scene = create_scene
      scene.events.create!(status: "declaring")
      expect { post world_scene_events_path(world, scene), params: { event: { directive: "Go." } } }
        .not_to change(Event, :count)
    end

    it "renders a completed turn's intent and prose in chronological order" do
      scene = create_scene
      scene.events.create!(intent: "Kara takes cover.", prose: "Rain falls.", status: "complete")
      get world_scene_path(world, scene)
      expect(response.body).to include("Rain falls.").and include("Kara takes cover.")
    end

    it "renders the raw Grok input and output for an event" do
      scene = create_scene
      event = scene.events.create!(intent: "Kara waits.")
      event.grok_calls.create!(payload: { "model" => "grok-4.3" }, response: { "id" => "abc" }, status: 200)
      get world_scene_path(world, scene)
      expect(response.body).to include("Grok calls").and include("grok-4.3").and include("abc")
    end
  end

  describe "POST narrate" do
    before { sign_in(user) }

    it "records the narrator's declaration and immediately starts the player's intent" do
      scene = create_scene
      expect do
        post narrate_world_scene_events_path(world, scene), params: { event: { prose: "The bridge collapses." } }
      end.to change(Event, :count).by(2).and have_enqueued_job(AdvanceSceneJob)

      declared = scene.events.chronological.first
      expect(declared).to have_attributes(prose: "The bridge collapses.", intent: nil, status: "complete")
      expect(scene.events.chronological.last.status).to eq("pending")
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses an empty declaration" do
      scene = create_scene
      expect do
        post narrate_world_scene_events_path(world, scene), params: { event: { prose: "   " } }
      end.not_to change(Event, :count)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "refuses to narrate in a player-mode scene" do
      scene = create_scene(play_mode: "player")
      expect do
        post narrate_world_scene_events_path(world, scene), params: { event: { prose: "Something." } }
      end.not_to change(Event, :count)
    end

    it "refuses to narrate while a turn is already in progress" do
      scene = create_scene
      scene.events.create!(status: "awaiting_gm", intent: "Kara lunges.")
      expect do
        post narrate_world_scene_events_path(world, scene), params: { event: { prose: "Something." } }
      end.not_to change(Event, :count)
    end
  end

  describe "POST adjudicate" do
    before { sign_in(user) }

    let(:scene) { create_scene }
    let(:event) { scene.events.create!(status: "awaiting_gm", intent: "Kara lunges.") }

    it "rolls the chosen tables, advances the event, and enqueues the job" do
      existing = world.roll_tables.create!(description: "Weather", denomination: 6, quantity: 1,
                                           possible_results: [{ "min" => nil, "max" => nil, "result" => "rain" }],)
      payload = { "0" => { "include" => "1", "source" => "existing", "roll_table_id" => existing.id.to_s } }
      expect do
        post adjudicate_world_scene_event_path(world, scene, event), params: { tables: payload }
      end.to have_enqueued_job(AdvanceSceneJob)
      expect(event.reload.status).to eq("rolled")
      expect(event.roll_results.count).to eq(1)
    end

    it "auto-succeeds with no tables selected" do
      post adjudicate_world_scene_event_path(world, scene, event), params: {}
      expect(event.reload.status).to eq("rolled")
      expect(event.roll_results).to be_empty
    end

    it "refuses to adjudicate an event that is not awaiting the Game Master" do
      event.update!(status: "complete")
      post adjudicate_world_scene_event_path(world, scene, event), params: {}
      expect(response).to redirect_to(world_scene_path(world, scene))
      expect(event.reload.status).to eq("complete")
    end
  end
end
