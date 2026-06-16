# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Scenes", type: :request do
  let(:user) { create_user(username: "alice") }
  let(:world) { user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.") }
  let(:character) { world.characters.create!(character_attributes) }
  let(:valid_attributes) do
    {
      character_id: character.id,
      premise: "Two strangers meet in a crowded tavern.",
      end_trigger: "End when they agree to travel together.",
      play_mode: "player",
    }
  end

  def character_attributes
    {
      name: "Kara",
      sex: "female",
      non_player_character: false,
      strength: 1, dexterity: 2, endurance: 3,
      intelligence: 0, awareness: -1, willpower: 5,
      charisma: -5, finesse: 4, tact: -2,
    }
  end

  def create_scene(target_world = world)
    scene_character = target_world.characters.create!(character_attributes)
    target_world.scenes.create!(
      user: target_world.user,
      character: scene_character,
      premise: "A premise.",
      end_trigger: "An ending.",
      play_mode: "narrator",
    )
  end

  describe "when logged out" do
    it "redirects index to the login page" do
      get world_scenes_path(world)
      expect(response).to redirect_to(login_path)
    end

    it "does not create a scene" do
      expect { post world_scenes_path(world), params: { scene: valid_attributes } }.not_to change(Scene, :count)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "when logged in" do
    before { sign_in(user) }

    it "lists the world's scenes" do
      create_scene
      get world_scenes_path(world)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A premise.")
    end

    it "renders the new form" do
      get new_world_scene_path(world)
      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form" do
      scene = create_scene
      get edit_world_scene_path(world, scene)
      expect(response).to have_http_status(:ok)
    end

    it "creates a scene belonging to the world and current user" do
      expect do
        post world_scenes_path(world), params: { scene: valid_attributes }
      end.to change(world.scenes, :count).by(1)
      scene = Scene.last
      expect(scene.user).to eq(user)
      expect(response).to redirect_to(world_scene_path(world, scene))
    end

    it "rejects an invalid scene" do
      expect do
        post world_scenes_path(world), params: { scene: valid_attributes.merge(premise: "") }
      end.not_to change(Scene, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows a scene" do
      scene = create_scene
      get world_scene_path(world, scene)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A premise.")
    end

    it "updates a scene" do
      scene = create_scene
      patch world_scene_path(world, scene), params: { scene: { premise: "A new beginning." } }
      expect(response).to redirect_to(world_scene_path(world, scene))
      expect(scene.reload.premise).to eq("A new beginning.")
    end

    it "rejects an invalid update" do
      scene = create_scene
      patch world_scene_path(world, scene), params: { scene: { play_mode: "spectator" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(scene.reload.play_mode).to eq("narrator")
    end

    it "destroys a scene" do
      scene = create_scene
      expect { delete world_scene_path(world, scene) }.to change(Scene, :count).by(-1)
      expect(response).to redirect_to(world_scenes_path(world))
    end
  end

  describe "another user's world" do
    let(:other_world) do
      create_user(username: "bob").worlds.create!(title: "Secret", core_concept: "Hidden.")
    end

    before { sign_in(user) }

    it "does not list its scenes" do
      get world_scenes_path(other_world)
      expect(response).to have_http_status(:not_found)
    end

    it "does not show its scenes" do
      scene = create_scene(other_world)
      get world_scene_path(other_world, scene)
      expect(response).to have_http_status(:not_found)
    end

    it "does not create a scene in it" do
      expect { post world_scenes_path(other_world), params: { scene: valid_attributes } }.not_to change(Scene, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "does not destroy its scenes" do
      scene = create_scene(other_world)
      expect { delete world_scene_path(other_world, scene) }.not_to change(Scene, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
